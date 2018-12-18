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
    let bootstrap = ServerBootstrap(group: MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount))
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

    var serverChannel: Channel!
    public let port: Int

    public init(port: Int) {
        self.port = port
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
    }

    deinit {
        print("Server released")
    }

    final class HTTPHandler: ChannelInboundHandler {
        typealias InboundIn = HTTPServerRequestPart
        typealias OutboundOut = HTTPServerResponsePart

        func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
            let reqPart = unwrapInboundIn(data)

            switch reqPart {
            case let .head(header):
                print("Headers:", header)

                let head = HTTPResponseHead(version: header.version,
                                            status: .ok)
                let part = HTTPServerResponsePart.head(head)
                _ = ctx.channel.write(part)

                var buffer = ctx.channel.allocator.buffer(capacity: 0)
                buffer.write(string: "")
                let bodypart = HTTPServerResponsePart.body(.byteBuffer(buffer))
                _ = ctx.channel.write(bodypart)

                let endpart = HTTPServerResponsePart.end(nil)
                _ = ctx.channel.writeAndFlush(endpart).then {
                    ctx.channel.close()
                }

            case .body, .end: break
            }
        }
    }
}
