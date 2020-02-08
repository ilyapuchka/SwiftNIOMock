import NIOHTTP1
import URLFormat

public protocol ServiceProtocol: class {}

open class Service: ServiceProtocol {
    public private(set) var routers: [Middleware] = []
    
    public init() {}
    public convenience init(@RouterBuilder _ router: () -> Middleware) {
        self.init()
        self.routers.append(router())
    }
    
    @discardableResult
    public func routes(@RouterBuilder _ router: () -> Middleware) -> Self {
        self.routers.append(router())
        return self
    }
}

public let GET = ClosedPathFormat(httpMethod(String(describing: HTTPMethod.GET)))
public let PUT = ClosedPathFormat(httpMethod(String(describing: HTTPMethod.PUT)))
public let POST = ClosedPathFormat(httpMethod(String(describing: HTTPMethod.POST)))
public let PATCH = ClosedPathFormat(httpMethod(String(describing: HTTPMethod.PATCH)))
public let DELETE = ClosedPathFormat(httpMethod(String(describing: HTTPMethod.DELETE)))

public extension ServiceProtocol where Self: Service {
    typealias ServiceRoute = (Self) -> Middleware
    
    @discardableResult
    func routes(@ServiceRouterBuilder _ router: () -> ServiceRoute) -> Self {
        return self.routes {
            router()(self)
        }
    }
}

@_functionBuilder
public struct ServiceRouterBuilder {
    public typealias RouteClosure<S: Service> = (S) -> Middleware

    public static func buildBlock<S: Service>(_ items: @escaping RouteClosure<S>) -> (S) -> Middleware {
        return buildBlock([items])
    }

    public static func buildBlock<S: Service>(_ items: RouteClosure<S>...) -> (S) -> Middleware {
        return buildBlock(items)
    }

    public static func buildBlock<S: Service>(_ items: [RouteClosure<S>]) -> (S) -> Middleware {
        return { service in
            RouterBuilder.buildBlock(items.map { $0(service) })
        }
    }
}

@_functionBuilder
public struct RouterBuilder {
    public static func buildBlock(_ items: Middleware...) -> Middleware {
        return buildBlock(items)
    }
    
    public static func buildBlock(_ items: [Middleware]) -> Middleware {
        let allRoutes = items
        return { request, response, finish in
            guard !allRoutes.isEmpty else {
                return finish()
            }
            var next: (() -> Void)? = {}
            var i = allRoutes.startIndex
            next = {
                let route = allRoutes[i]
                i = allRoutes.index(after: i)
                let isLast = i == allRoutes.endIndex
                route(request, response, isLast ? finish : next!)
            }
            next!()
        }
    }
}
