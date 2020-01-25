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
    public let port: Int

    let handler: Middleware
    private(set) var group: EventLoopGroup!
    private(set) var bootstrap: ServerBootstrap!
    private(set) var serverChannel: Channel!

    public init(port: Int, handler: @escaping Middleware = { _, _, next in next() }) {
        self.port = port
        self.handler = handler
    }

    func bootstrapServer(handler: @escaping Middleware) -> ServerBootstrap {
        return ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true)
                    .then {
                        channel.pipeline.add(handler: HTTPHandler(handler: handler))
                    }.then {
                        channel.pipeline.add(handler: HTTPResponseCompressor())
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    }

    public func start() throws {
        group = group ?? MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        bootstrap = bootstrap ?? bootstrapServer(handler: handler)

        serverChannel = try bootstrap.bind(host: "localhost", port: port).wait()
        print("Server listening on:", serverChannel.localAddress!)

        serverChannel.closeFuture.whenComplete {
            print("Server stopped")
        }
    }

    public func stop() throws {
        try serverChannel?.close().wait()
        try group.syncShutdownGracefully()
        serverChannel = nil
        bootstrap = nil
        group = nil
    }

    deinit {
        print("Server released")
    }

}

extension Server {
    public class HTTPHandler: ChannelInboundHandler {
        public typealias InboundIn = HTTPServerRequestPart

        private var state: State = .idle
        let handler: Middleware

        init(handler: @escaping Middleware) {
            self.handler = handler
        }

        public func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
            defer {
                ctx.fireChannelRead(data)
            }

            switch unwrapInboundIn(data) {
            case let .head(head):
                state.requestReceived(head: head)
            case let .body(buffer):
                state.bodyReceived(buffer: buffer)
            case .end:
                let (head, buffer) = state.requestComplete()

                var httpBody: Data?
                if var body = buffer {
                    httpBody = body.readString(length: body.readableBytes)?.data(using: .utf8)
                }

                let request = Request(head: head, body: httpBody, ctx: ctx)

                var responseBuffer = ctx.channel.allocator.buffer(capacity: 0)

                let eventLoop = ctx.channel.eventLoop
                let response = Response()

                handler(request, response) {
                    eventLoop.execute {
                        _ = ctx.channel.write(HTTPServerResponsePart.head(
                            HTTPResponseHead(version: head.version, status: response.statusCode, headers: response.headers))
                        )
                        _ = response.body
                            .flatMap { String(data: $0, encoding: .utf8) }
                            .flatMap { responseBuffer.write(string: $0) }

                        _ = ctx.channel.write(HTTPServerResponsePart.body(.byteBuffer(responseBuffer)))

                        _ = ctx.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).then {
                            ctx.channel.close()
                        }
                        self.state.responseComplete()
                    }
                }
            }
        }
    }
}

extension Server.HTTPHandler {
    enum State {
        case idle
        case ignoringRequest
        case receivingRequest(HTTPRequestHead, ByteBuffer?)
        case sendingResponse

        mutating func requestReceived(head: HTTPRequestHead) {
            guard case .idle = self else {
                preconditionFailure("Invalid state for \(#function): \(self)")
            }
            print("Received request: ", head)
            self = .receivingRequest(head, nil)
        }

        mutating func bodyReceived(buffer: ByteBuffer) {
            var body = buffer
            guard case .receivingRequest(let header, var buffer) = self else {
                preconditionFailure("Invalid state for \(#function): \(self)")
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
                preconditionFailure("Invalid state for \(#function): \(self)")
            }
            if var buffer = buffer {
                print("Received body: \(buffer.readString(length: buffer.readableBytes) ?? "nil")")
            }
            self = .sendingResponse
            return (header, buffer)
        }

        mutating func responseComplete() {
            guard case .sendingResponse = self else {
                preconditionFailure("Invalid state for response complete: \(self)")
            }
            self = .idle
        }
    }
}

extension Server.HTTPHandler {
    public struct Request {
        public let head: HTTPRequestHead
        public let body: Data?
        public let ctx: ChannelHandlerContext

        public init(head: HTTPRequestHead, body: Data?, ctx: ChannelHandlerContext) {
            self.head = head
            self.body = body
            self.ctx = ctx
        }
    }
}

extension Server.HTTPHandler {
    public class Response {
        var state: State = .idle
        public var statusCode: HTTPResponseStatus = .ok
        public var headers: HTTPHeaders = HTTPHeaders()
        public var body: Data?

        public func sendJSON<T: Encodable>(_ statusCode: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders(), value: T) throws -> Void {
            self.statusCode = statusCode
            var headers = headers
            headers.replaceOrAdd(name: "Content-Type", value: "application/json; charset=utf-8")
            self.headers = headers
            self.body = try JSONEncoder().encode(value)
        }

        public func sendString(_ statusCode: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders(), value: String) -> Void {
            self.statusCode = statusCode
            var headers = headers
            headers.replaceOrAdd(name: "Content-Type", value: "text/html; charset=utf-8")
            self.headers = headers
            self.body = value.data(using: .utf8)
        }
    }
}

extension URLRequest {
    public init(_ request: Server.HTTPHandler.Request) {
        let url = URL(string: request.head.uri)!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "\(request.head.method)"
        urlRequest.allHTTPHeaderFields = request.head.headers.reduce(into: [:]) { (headers, pair) in
            headers[pair.name] = pair.value
        }
        urlRequest.httpBody = request.body
        self = urlRequest
    }
}

public typealias Middleware = (
    _ request: Server.HTTPHandler.Request,
    _ response: Server.HTTPHandler.Response,
    _ next: @escaping () -> Void
) -> Void

/// Middleware that can redirect requests to other middlewares
public func router(
    route: @escaping (Server.HTTPHandler.Request) -> Middleware?,
    notFound: @escaping Middleware
) -> Middleware {
    return { request, response, next in
        (route(request) ?? notFound)(request, response, next)
    }
}

/// Middleware that allows to redirect incomming request and intercept responses
public func redirect(
    session: URLSession = URLSession.shared,
    request redirect: @escaping (Server.HTTPHandler.Request) -> Server.HTTPHandler.Request,
    response intercept: @escaping (Server.HTTPHandler.Response) -> Void = { _ in }
) -> Middleware {
    return { request, response, next in
        var redirect = URLRequest(redirect(request))
        redirect.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let task = session.dataTask(with: redirect) { data, urlResponse, error in
            guard let urlResponse = urlResponse as? HTTPURLResponse else {
                next()
                return
            }

            response.statusCode = HTTPResponseStatus(statusCode: urlResponse.statusCode)
            response.headers = HTTPHeaders(urlResponse.allHeaderFields.map { ("\($0.key)", "\($0.value)") })
            response.body = data

            intercept(response)

            // compressor will add this header itself,
            // so they may be duplicated and decoding on the client side will fail
            // see: https://github.com/apple/swift-nio/issues/717
            response.headers.remove(name: "Content-Encoding")

            next()
        }
        task.resume()
    }
}

/// Middleware that delay another middleware
public func delay(_ delay: TimeAmount, middleware: @escaping Middleware) -> Middleware {
    return { request, response, next in
        _ = request.ctx.eventLoop.scheduleTask(in: delay) {
            middleware(request, response, next)
        }
    }
}
