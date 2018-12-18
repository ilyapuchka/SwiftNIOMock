//
//  Server.swift
//  SwiftNIOMock
//
//  Created by Ilya Puchka on 18/12/2018.
//

import Foundation
import NIO
import NIOHTTP1

open class Server {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let bootstrap: ServerBootstrap

    var serverChannel: Channel!
    public let port: Int

    public init(port: Int) {
        self.port = port

        self.bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).then {
                    channel.pipeline.add(handler: HTTPHandler())
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    }

    public func start() throws {
        serverChannel = try self.bootstrap.bind(host: "localhost", port: port).wait()
        print("Server listening on:", serverChannel.localAddress!)

        serverChannel.closeFuture.whenComplete {
            print("Server stopped")
        }
    }

    public func stop() throws {
        try self.serverChannel?.close().wait()
        self.serverChannel = nil
        try group.syncShutdownGracefully()
    }

    deinit {
        print("Server released")
    }

    class HTTPHandler: ChannelInboundHandler {
        typealias InboundIn = HTTPServerRequestPart

        var state: State = .idle

        enum State {
            case idle
            case receivingRequest(HTTPRequestHead, ByteBuffer?)
            case sendingResponse

            mutating func requestReceived(head: HTTPRequestHead) {
                guard case .idle = self else {
                    precondition(false, "Invalid state for \(#function): \(self)")
                }
                print("Received request: ", head)
                self = .receivingRequest(head, nil)
            }

            mutating func bodyReceived(buffer: ByteBuffer) {
                var body = buffer
                guard case .receivingRequest(let header, var buffer) = self else {
                    precondition(false, "Invalid state for \(#function): \(self)")
                }
                if buffer == nil {
                    buffer = body
                } else {
                    buffer?.write(buffer: &body)
                }
                self = .receivingRequest(header, buffer)
            }

            mutating func requestComplete() -> (HTTPRequestHead, ByteBuffer?)  {
                guard case let .receivingRequest(header, buffer) = self else {
                    precondition(false, "Invalid state for \(#function): \(self)")
                }
                if var buffer = buffer {
                    print("Received body: \(buffer.readString(length: buffer.readableBytes) ?? "nil")")
                }
                self = .sendingResponse
                return (header, buffer)
            }

            mutating func responseComplete() {
                guard case .sendingResponse = self else {
                    precondition(false, "Invalid state for response complete: \(self)")
                }
                self = .idle
            }
        }

        func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
            switch unwrapInboundIn(data) {
            case let .head(head):
                state.requestReceived(head: head)
            case let .body(buffer):
                state.bodyReceived(buffer: buffer)
            case .end:
                let (head, buffer) = state.requestComplete()

                var headers = HTTPHeaders()
                if let buffer = buffer {
                    headers.add(name: "Content-Length", value: "\(buffer.readableBytes)")
                    _ = ctx.channel.write(HTTPServerResponsePart.head(
                        HTTPResponseHead(version: head.version, status: .ok, headers: headers))
                    )
                    _ = ctx.channel.write(HTTPServerResponsePart.body(.byteBuffer(buffer)))
                } else {
                    _ = ctx.channel.write(HTTPServerResponsePart.head(
                        HTTPResponseHead(version: head.version, status: .ok))
                    )
                }
                _ = ctx.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).then {
                    ctx.channel.close()
                }
                state.responseComplete()
            }
        }
    }
}
