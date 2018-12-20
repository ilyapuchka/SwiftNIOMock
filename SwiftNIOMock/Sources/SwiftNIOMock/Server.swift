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

    public init(port: Int, router: @escaping Middleware) {
        self.port = port

        self.bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true)
                    .then {
                        channel.pipeline.add(handler: HTTPHandler(router: router))
                    }.then {
                        channel.pipeline.add(handler: HTTPResponseCompressor())
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

}

extension Server {
    public class HTTPHandler: ChannelInboundHandler {
        public typealias InboundIn = HTTPServerRequestPart

        private var state: State = .idle
        let router: Middleware

        init(router: @escaping Middleware) {
            self.router = router
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
                let response = Response(eventLoop: eventLoop)

                router(request, response) {
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
        var eventLoop: EventLoop
        var state: State = .idle
        public private(set) var statusCode: HTTPResponseStatus = .ok
        public private(set) var headers: HTTPHeaders = HTTPHeaders()
        public private(set) var body: Data?

        init(eventLoop: EventLoop) {
            self.eventLoop = eventLoop
        }

        public func start(_ statusCode: HTTPResponseStatus) -> Void {
            eventLoop.execute {
                self.statusCode = statusCode
            }
        }

        public func setHeaders(_ headers: HTTPHeaders) -> Void {
            eventLoop.execute {
                headers.forEach { self.headers.replaceOrAdd(name: $0, value: $1) }
            }
        }

        public func sendBody(_ data: Data) -> Void {
            eventLoop.execute {
                var body = self.body ?? Data()
                body.append(data)
                self.body = body
            }
        }

        public func sendJSON<T: Encodable>(_ statusCode: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders(), value: T) throws -> Void {
            start(statusCode)
            var headers = headers
            headers.replaceOrAdd(name: "Content-Type", value: "application/json; charset=utf-8")
            setHeaders(headers)
            try sendBody(JSONEncoder().encode(value))
        }

        public func sendString(_ statusCode: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders(), value: String) -> Void {
            start(statusCode)
            var headers = headers
            headers.replaceOrAdd(name: "Content-Type", value: "text/html; charset=utf-8")
            setHeaders(headers)
            sendBody(value.data(using: .utf8)!)
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
public func router(route: @escaping (Server.HTTPHandler.Request) -> Middleware?, notFound: @escaping Middleware) -> Middleware {
    return { request, response, next in
        (route(request) ?? notFound)(request, response, next)
    }
}

/// Middleware that allows to redirect incomming request and intercept responses
public func redirect(
    session: URLSession = URLSession.shared,
    request override: @escaping (Server.HTTPHandler.Request) -> Server.HTTPHandler.Request,
    body: @escaping (Data) -> Data = { $0 }) -> Middleware {
    return { request, response, next in
        let task = session.dataTask(with: URLRequest(override(request))) { data, urlResponse, error in
            guard let urlResponse = urlResponse as? HTTPURLResponse else {
                next()
                return
            }
            response.start(HTTPResponseStatus(statusCode: urlResponse.statusCode))
            var headers = HTTPHeaders(urlResponse.allHeaderFields.map { ("\($0.key)", "\($0.value)") })
            // compressor will add this header itself,
            // so they may be duplicated and decoding on the client side will fail
            headers.remove(name: "Content-Encoding")

            response.setHeaders(headers)
            data.map(body).map(response.sendBody)
            next()
        }
        task.resume()
    }
}

/// Middleware that delay another middleware
public func delay(_ delay: TimeAmount, middleware: @escaping Middleware) -> Middleware {
    return { request, response, next in
        request.ctx.eventLoop.scheduleTask(in: delay) {
            middleware(request, response, next)
        }
    }
}
