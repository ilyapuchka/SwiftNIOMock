//import Foundation
//import NIO
//import NIOHTTP1
//
///// Middleware that can redirect requests to other middlewares
//public func router(
//    notFound: @escaping Middleware = notFound,
//    route: @escaping (Server.HTTPHandler.Request) -> Middleware? = { _ in nil }
//) -> Middleware {
//    return { request, response, next in
//        (route(request.http) ?? notFound)(request, response, next)
//    }
//}
//
public struct URLComponentsMatches {
    let path: [Any]
    let query: [String: Any]
    public subscript(_ index: Int) -> String {
        return path[index] as! String
    }
    public subscript(_ index: Int) -> Int {
        return path[index] as! Int
    }
    public subscript(_ key: String) -> String {
        return query[key] as! String
    }
    public subscript(_ key: String) -> Int {
        return query[key] as! Int
    }
}
//
//func match(path: String, matcher: URLComponentsMatcher) -> URLComponentsMatches? {
//    var pattern = matcher.pathPattern
//
//    pattern = pattern.starts(with: "/")
//        ? pattern
//        : "/\(pattern)"
//
//    pattern = pattern.starts(with: "^")
//        ? pattern
//        : "^\(pattern)"
//    
//    let nspath = NSString(string: path)
//    let regex = try! NSRegularExpression(pattern: pattern, options: [])
//    let matches = regex.matches(
//        in: path,
//        options: [],
//        range: NSRange(location: 0, length: path.count)
//    )
//    guard let match = matches.first else {
//        return nil
//    }
//    var pathCaptures = [Any]()
//    for rangeIndex in 0 ..< matcher.pathParams.count {
//        let string = nspath.substring(with: match.range(at: rangeIndex + 1))
//        guard let value = matcher.pathParams[rangeIndex](string) else {
//            return nil
//        }
//        pathCaptures.append(value)
//    }
//    var queryCaptures = [String: Any]()
//    for rangeIndex in matcher.pathParams.count ..< matcher.pathParams.count + matcher.queryParams.count {
//        let pair = nspath.substring(with: match.range(at: rangeIndex + 1))
//        let keyAndValue = pair.components(separatedBy: "=")
//        guard keyAndValue.count == 2 else {
//            return nil
//        }
//        if let transform = matcher.queryParams[keyAndValue[0]] {
//            guard let value = transform(keyAndValue[1]) else {
//                return nil
//            }
//            queryCaptures[keyAndValue[0]] = value
//        }
//    }
//    return URLComponentsMatches(path: pathCaptures, query: queryCaptures)
//}
//
//public func route(_ method: HTTPMethod, at matcher: URLComponentsMatcher, response: @escaping Middleware) -> Middleware {
//    return { request, httpResponse, next in
//        guard method == request.http.head.method else {
//            return next()
//        }
//
//        guard
//            let match = SwiftNIOMock.match(path: request.http.head.uri, matcher: matcher)
//            else {
//                return next()
//        }
//        response((request.http, match), httpResponse, next)
//    }
//}
//
//public func GET(_ match: URLComponentsMatcher, response: @escaping Middleware) -> Middleware {
//    return route(.GET, at: match, response: response)
//}
//
//public func PUT(_ match: URLComponentsMatcher, response: @escaping Middleware) -> Middleware {
//    return route(.PUT, at: match, response: response)
//}
//
//public func POST(_ match: URLComponentsMatcher, response: @escaping Middleware) -> Middleware {
//    return route(.POST, at: match, response: response)
//}
//
//public func PATCH(_ match: URLComponentsMatcher, response: @escaping Middleware) -> Middleware {
//    return route(.PATCH, at: match, response: response)
//}
//
//public func DELETE(_ match: URLComponentsMatcher, response: @escaping Middleware) -> Middleware {
//    return route(.DELETE, at: match, response: response)
//}
//
//public protocol ServiceProtocol: class {
//    var routers: [Middleware] { get }
//    func routes(@RouterBuilder _ router: () -> Middleware) -> Self
//}
//
//open class Service: ServiceProtocol {
//    public private(set) var routers: [Middleware] = []
//    
//    public init() {}
//    
//    @discardableResult
//    public func routes(@RouterBuilder _ router: () -> Middleware) -> Self {
//        self.routers.append(router())
//        return self
//    }
//}
//
//@_functionBuilder
//public struct RouterBuilder {
//    public static func buildBlock(_ items: Middleware...) -> Middleware {
//        return buildBlock(items)
//    }
//    
//    public static func buildBlock(_ items: [Middleware]) -> Middleware {
//        let allRoutes = items.reversed()
//        return { request, response, finish in
//            guard !allRoutes.isEmpty else {
//                return finish()
//            }
//            var next: (() -> Void)? = {}
//            var i = allRoutes.startIndex
//            next = {
//                let route = allRoutes[i]
//                i = allRoutes.index(after: i)
//                let isLast = i == allRoutes.endIndex
//                route(request, response) {
//                    if response._statusCode == nil {
//                        isLast ? finish() : next!()
//                    } else {
//                        finish()
//                    }
//                }
//            }
//            next!()
//        }
//    }
//}
//
//private func router(
//    notFound: @escaping Middleware = notFound,
//    route: @escaping Middleware
//) -> Middleware {
//    return { request, response, finish in
//        let next = {
//            if response._statusCode == nil {
//                notFound(request, response, finish)
//            } else {
//                finish()
//            }
//        }
//        route(request, response, next)
//    }
//}
//
//public func router(
//    notFound: @escaping Middleware = notFound,
//    @RouterBuilder _ routes: () -> Middleware
//) -> Middleware {
//    return SwiftNIOMock.router(notFound: notFound, route: routes())
//}
//
//public func router(
//    notFound: @escaping Middleware = notFound,
//    services: [Service]
//) -> Middleware {
//    return SwiftNIOMock.router(notFound: notFound, route: RouterBuilder.buildBlock(services.flatMap { $0.routers }))
//}
//
public protocol URLComponentsMatcher {
    var pathPattern: String { get }
    var pathParams: [(String) -> Any?] { get }
    var queryParams: [String: (String) -> Any?] { get }
}
//
//extension String: URLComponentsMatcher {
//    public var pathPattern: String { self }
//    public var pathParams: [(String) -> Any?] { [] }
//    public var queryParams: [String : (String) -> Any?] { [:] }
//    public var end: EndMatcher {
//        EndMatcher(
//            pathPattern: pathPattern,
//            pathParams: pathParams,
//            queryParams: queryParams
//        )
//    }
//}
//
//public class EndMatcher: URLComponentsMatcher {
//    public fileprivate(set) var pathPattern: String
//    public let pathParams: [(String) -> Any?]
//    public let queryParams: [String: (String) -> Any?]
//
//    init(pathPattern: String, pathParams: [(String) -> Any?], queryParams: [String: (String) -> Any?]) {
//        self.pathPattern = pathPattern + "$"
//        self.pathParams = pathParams
//        self.queryParams = queryParams
//    }
//}
//
//public struct PathComponentsMatcher: URLComponentsMatcher, ExpressibleByStringLiteral {
//    public fileprivate(set) var pathPattern: String
//    public fileprivate(set) var pathParams: [(String) -> Any?]
//    public fileprivate(set) var queryParams: [String: (String) -> Any?]
//
//    public init(stringLiteral value: String) {
//        self.pathPattern = value
//        self.pathParams = []
//        self.queryParams = [:]
//    }
//
//    public init(pathPattern: String, pathParams: [(String) -> Any?] = [], queryParams: [String: (String) -> Any?] = [:]) {
//        self.pathPattern = pathPattern
//        self.pathParams = pathParams
//        self.queryParams = queryParams
//    }
//
//    public func string(capture: Bool = true) -> PathComponentsMatcher {
//        append(transform: capture ? { $0 } : nil)
//    }
//    public func number(capture: Bool = true) -> PathComponentsMatcher {
//        append(transform: capture ? Int.init : nil)
//    }
//
//    public var string: PathComponentsMatcher { append(transform: { $0 }) }
//    public var number: PathComponentsMatcher { append(transform: Int.init) }
//    public var path: PathComponentsMatcher { append(transform: nil) }
//    public var end: EndMatcher {
//        EndMatcher(
//            pathPattern: pathPattern,
//            pathParams: pathParams,
//            queryParams: queryParams
//        )
//    }
//
//    static let empty = PathComponentsMatcher(stringLiteral: "")
//
//    public static func string(capture: Bool = true) -> PathComponentsMatcher { Self.empty.string(capture: capture) }
//    public static func number(capture: Bool = true) -> PathComponentsMatcher { Self.empty.number(capture: capture) }
//
//    public static var string: PathComponentsMatcher { Self.empty.string }
//    public static var number: PathComponentsMatcher { Self.empty.number }
//    public static var path: PathComponentsMatcher { Self.empty.path }
//
//    func append(transform: ((String) -> Any?)?) -> PathComponentsMatcher {
//        var copy = self
//        if let transform = transform {
//            copy.pathPattern += "([^/]+)"
//            copy.pathParams.append(transform)
//        } else {
//            copy.pathPattern += "[^/]+"
//        }
//        return copy
//    }
//}
//
//postfix operator /
//public postfix func /(_ lhs: PathComponentsMatcher) -> PathComponentsMatcher {
//    var lhs = lhs
//    lhs.pathPattern += "/"
//    return lhs
//}
//
//prefix operator /
//public prefix func /(_ rhs: PathComponentsMatcher) -> PathComponentsMatcher {
//    var rhs = rhs
//    rhs.pathPattern = "/" + rhs.pathPattern
//    return rhs
//}
//
//public func /(_ lhs: PathComponentsMatcher, _ rhs: PathComponentsMatcher) -> PathComponentsMatcher {
//    var lhs = lhs
//    lhs.pathPattern += "/" + rhs.pathPattern
//    return lhs
//}
//
//public func /(_ lhs: PathComponentsMatcher, _ rhs: EndMatcher) -> EndMatcher {
//    rhs.pathPattern = lhs.pathPattern + "/" + rhs.pathPattern
//    return rhs
//}
//
//@dynamicMemberLookup
//public struct QueryComponentsMatcher: URLComponentsMatcher {
//    static let pattern = "([^=&]+=[^=&]+)"
//    public private(set) var pathPattern: String
//    public private(set) var pathParams: [(String) -> Any?]
//    public private(set) var queryParams: [String: (String) -> Any?]
//
//    public init(pathPattern: String = "", pathParams: [(String) -> Any?], queryParams: [String: (String) -> Any?]) {
//        self.pathPattern = pathPattern
//        self.pathParams = pathParams
//        self.queryParams = queryParams
//    }
//    
//    public struct Transform {
//        public let transform: (String) -> Any?
//        public init(_ transform: @escaping (String) -> Any?) {
//            self.transform = transform
//        }
//        
//        public static let string = Transform({ $0 })
//        public static let int = Transform(Int.init)
//    }
//
//    subscript(dynamicMember member: String) -> (String) -> QueryComponentsMatcher {
//        return { value in
//            var copy = self
//            copy.pathPattern += QueryComponentsMatcher.pattern
//            copy.queryParams[member] = { value == $0 ? value : nil }
//            return copy
//        }
//    }
//
//    subscript(dynamicMember member: String) -> (Transform) -> QueryComponentsMatcher {
//        return { transform in
//            var copy = self
//            copy.pathPattern += QueryComponentsMatcher.pattern
//            copy.queryParams[member] = transform.transform
//            return copy
//        }
//    }
//
//    subscript(dynamicMember member: String) -> (Int) -> QueryComponentsMatcher {
//        return { value in
//            var copy = self
//            copy.pathPattern += QueryComponentsMatcher.pattern
//            copy.queryParams[member] = { value == Int.init($0) ? value : nil }
//            return copy
//        }
//    }
//
//    public var end: EndMatcher {
//        EndMatcher(
//            pathPattern: pathPattern,
//            pathParams: pathParams,
//            queryParams: queryParams
//        )
//    }
//
//    func append(param: String, transform: ((String) -> Any?)?) -> QueryComponentsMatcher {
//        var copy = self
//        copy.pathPattern += QueryComponentsMatcher.pattern
//        copy.queryParams[param] = transform
//        return copy
//    }
//}
//
//public prefix func /(_ rhs: QueryComponentsMatcher) -> PathComponentsMatcher {
//    PathComponentsMatcher(pathPattern: "/" + rhs.pathPattern, pathParams: rhs.pathParams, queryParams: rhs.queryParams)
//}
//
//public func /(_ lhs: PathComponentsMatcher, _ rhs: QueryComponentsMatcher) -> PathComponentsMatcher {
//    var lhs = lhs
//    lhs.pathPattern = lhs.pathPattern + "/" + rhs.pathPattern
//    lhs.queryParams = rhs.queryParams
//    return lhs
//}
//
//postfix operator /?
//public postfix func /? (_ lhs: PathComponentsMatcher) -> QueryComponentsMatcher {
//    return QueryComponentsMatcher(pathPattern: lhs.pathPattern + #"/?\?"#, pathParams: lhs.pathParams, queryParams: [:])
//}
//
//postfix operator &
//public postfix func &(_ lhs: QueryComponentsMatcher) -> QueryComponentsMatcher {
//    QueryComponentsMatcher(pathPattern: lhs.pathPattern + "&", pathParams: lhs.pathParams, queryParams: lhs.queryParams)
//}
//
//// -----
//
////public extension ServiceProtocol where Self: Service {
////    typealias ServiceRoute = (Self) -> Middleware
////
////    @discardableResult
////    func routes(@ServiceRouterBuilder _ router: () -> ServiceRoute) -> Self {
////        let routes = router()(self)
////        return self.routes { routes }
////    }
////}
////
////@_functionBuilder
////public struct ServiceRouterBuilder {
////    public typealias RouteClosure<S: Service> = (S) -> Middleware
////
////    public static func buildBlock<S: Service>(_ items: @escaping RouteClosure<S>) -> (S) -> Middleware {
////        return buildBlock([items])
////    }
////
////    public static func buildBlock<S: Service>(_ items: RouteClosure<S>...) -> (S) -> Middleware {
////        return buildBlock(items)
////    }
////
////    public static func buildBlock<S: Service>(_ items: [RouteClosure<S>]) -> (S) -> Middleware {
////        return { service in
////            RouterBuilder.buildBlock(items.map { $0(service) })
////        }
////    }
////}
////
////extension Service {
////    public struct GET {
////        let match: [PathComponentsMatcher]
////        var middleware: (Service) -> Middleware = { _ in { _, _, next in next() } }
////
////        private init(match: PathComponentsMatcher...) {
////            self.match = match
////        }
////
////        public static subscript(_ path: String) -> GET {
////            return GET(match: .path(path))
////        }
////    }
////}
////
////public func ==<S: Service, T: Encodable>(lhs: S.GET, rhs: KeyPath<S, T>) -> (S) -> Middleware {
////    return { service in
////        return route(.GET, at: lhs.match, response: { _, response, next in
////            let value = service[keyPath: rhs]
////            try! response.sendJSON(.ok, value: value)
////            next()
////        })
////    }
////}
////
////public func GET<S: Service, T, U: Encodable>(
////    at match: PathComponentsMatcher...,
////    keyPath: KeyPath<S, T>,
////    sendJSON: @escaping (T) -> U
////) -> (S) -> Middleware {
////    return { service in
////        return route(.GET, at: match, response: { _, response, next in
////            let value = service[keyPath: keyPath]
////            try! response.sendJSON(.ok, value: sendJSON(value))
////            next()
////        })
////    }
////}
