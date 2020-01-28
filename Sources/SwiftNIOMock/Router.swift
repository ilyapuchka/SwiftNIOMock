import Foundation
import NIO
import NIOHTTP1

/// Middleware that can redirect requests to other middlewares
public func router(
    notFound: @escaping Middleware = notFound,
    route: @escaping (Server.HTTPHandler.Request) -> Middleware? = { _ in nil }
) -> Middleware {
    return { request, response, next in
        (route(request.http) ?? notFound)(request, response, next)
    }
}

public struct URLComponentsMatches {
    let path: [String]
    let query: [String: String]
    public subscript(_ index: Int) -> String {
        return path[index]
    }
    public subscript(_ index: Int) -> Int {
        return Int(path[index])!
    }
    public subscript(_ key: String) -> String {
        return query[key]!
    }
    public subscript(_ key: String) -> Int {
        return Int(query[key]!)!
    }
}

func match(path: String, matcher: URLComponentsMatcher) -> URLComponentsMatches? {
    var pattern = matcher.pathPattern

    pattern = pattern.starts(with: "/")
        ? pattern
        : "/\(pattern)"

    pattern = pattern.starts(with: "^")
        ? pattern
        : "^\(pattern)"
    
    let hasQueryPattern = matcher.pathPattern.hasSuffix(QueryComponentsMatcher.pattern)
    let nspath = NSString(string: path)
    let regex = try! NSRegularExpression(pattern: pattern, options: [])
    let matches = regex.matches(
        in: path,
        options: [],
        range: NSRange(location: 0, length: path.count)
    )
    guard
        let match = matches.first,
        let pathCaptures = SwiftNIOMock.pathCaptures(path: nspath, match: match, hasQueryPattern: hasQueryPattern),
        let queryCaptures = (hasQueryPattern
            ? SwiftNIOMock.queryCaptures(path: nspath, matcher: matcher, match: match)
            : [:])
            else {
        return nil
    }
    return URLComponentsMatches(path: pathCaptures, query: queryCaptures)
}

func pathCaptures(path: NSString, match: NSTextCheckingResult, hasQueryPattern: Bool) -> [String]? {
    var pathCaptures = [String]()
    for rangeIdx in 1 ..< match.numberOfRanges {
        if hasQueryPattern && rangeIdx == match.numberOfRanges - 1 {
            break
        } else {
            pathCaptures.append(path.substring(with: match.range(at: rangeIdx)))
        }
    }
    return pathCaptures
}

func queryCaptures(path: NSString, matcher: URLComponentsMatcher, match: NSTextCheckingResult) -> [String: String]? {
    var queryCaptures = [String: String]()
    let query = path.substring(with: match.range(at: match.numberOfRanges.advanced(by: -1)))
    for pair in query.components(separatedBy: "&") {
        let nameAndValue = pair.components(separatedBy: "=")
        guard nameAndValue.count == 2 else {
            return nil
        }
        let name = nameAndValue[0]
        let value = nameAndValue[1]
        guard let paramPattern = matcher.queryParams[name] else {
            return nil
        }
        let regex = try! NSRegularExpression(pattern: paramPattern, options: [])
        let matches = regex.numberOfMatches(in: value, options: [], range: NSRange(location: 0, length: value.count))
        guard matches == 1 else {
            return nil
        }
        queryCaptures[name] = value
    }
    return queryCaptures
}

public func route(_ method: HTTPMethod, at matcher: URLComponentsMatcher, response: @escaping Middleware) -> Middleware {
    return { request, httpResponse, next in
        guard method == request.http.head.method else {
            return next()
        }

        guard
            let match = SwiftNIOMock.match(path: request.http.head.uri, matcher: matcher)
            else {
                return next()
        }
        response((request.http, match), httpResponse, next)
    }
}

public func GET(_ match: URLComponentsMatcher, response: @escaping Middleware) -> Middleware {
    return route(.GET, at: match, response: response)
}

public func PUT(_ match: PathComponentsMatcher, response: @escaping Middleware) -> Middleware {
    return route(.PUT, at: match, response: response)
}

public func POST(_ match: PathComponentsMatcher, response: @escaping Middleware) -> Middleware {
    return route(.POST, at: match, response: response)
}

public func PATCH(_ match: PathComponentsMatcher, response: @escaping Middleware) -> Middleware {
    return route(.PATCH, at: match, response: response)
}

public func DELETE(_ match: PathComponentsMatcher, response: @escaping Middleware) -> Middleware {
    return route(.DELETE, at: match, response: response)
}

public protocol ServiceProtocol: class {
    var routers: [Middleware] { get }
    func routes(@RouterBuilder _ router: () -> Middleware) -> Self
}

open class Service: ServiceProtocol {
    public private(set) var routers: [Middleware] = []
    
    public init() {}
    
    @discardableResult
    public func routes(@RouterBuilder _ router: () -> Middleware) -> Self {
        self.routers.append(router())
        return self
    }
}

@_functionBuilder
public struct RouterBuilder {
    public static func buildBlock(_ items: Middleware...) -> Middleware {
        return buildBlock(items)
    }
    
    public static func buildBlock(_ items: [Middleware]) -> Middleware {
        let allRoutes = items.reversed()
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
                route(request, response) {
                    if response._statusCode == nil {
                        isLast ? finish() : next!()
                    } else {
                        finish()
                    }
                }
            }
            next!()
        }
    }
}

private func router(
    notFound: @escaping Middleware = notFound,
    route: @escaping Middleware
) -> Middleware {
    return { request, response, finish in
        let next = {
            if response._statusCode == nil {
                notFound(request, response, finish)
            } else {
                finish()
            }
        }
        route(request, response, next)
    }
}

public func router(
    notFound: @escaping Middleware = notFound,
    @RouterBuilder _ routes: () -> Middleware
) -> Middleware {
    return SwiftNIOMock.router(notFound: notFound, route: routes())
}

public func router(
    notFound: @escaping Middleware = notFound,
    services: [Service]
) -> Middleware {
    return SwiftNIOMock.router(notFound: notFound, route: RouterBuilder.buildBlock(services.flatMap { $0.routers }))
}

public protocol URLComponentsMatcher {
    var pathPattern: String { get }
    var queryParams: [String: String] { get }
}

extension String: URLComponentsMatcher {
    public var pathPattern: String { self }
    public var queryParams: [String : String] { [:] }
    public var end: EndMatcher { EndMatcher(pathPattern: pathPattern, queryParams: queryParams) }
}

public class EndMatcher: URLComponentsMatcher {
    public fileprivate(set) var pathPattern: String
    public let queryParams: [String: String]
    
    init(pathPattern: String, queryParams: [String: String]) {
        self.pathPattern = pathPattern + "$"
        self.queryParams = queryParams
    }
}

public class PathComponentsMatcher: URLComponentsMatcher, ExpressibleByStringLiteral {
    public fileprivate(set) var pathPattern: String
    public fileprivate(set) var queryParams: [String: String] = [:]

    required public init(stringLiteral value: String) {
        self.pathPattern = value
    }
    
    public func string(capture: Bool = true) -> PathComponentsMatcher { append(pattern: "[a-zA-Z]+", capture: capture) }
    public func number(capture: Bool = true) -> PathComponentsMatcher { append(pattern: "[0-9]+", capture: capture) }

    public var string: PathComponentsMatcher { append(pattern: "[a-zA-Z]+", capture: true) }
    public var number: PathComponentsMatcher { append(pattern: "[0-9]+", capture: true) }
    public var any: PathComponentsMatcher { append(pattern: "[^/]+", capture: true) }
    public var path: PathComponentsMatcher { append(pattern: "[^/]+", capture: false) }
    public var end: EndMatcher { EndMatcher(pathPattern: pathPattern, queryParams: queryParams) }

    static let empty = PathComponentsMatcher(stringLiteral: "")
    
    public static func string(capture: Bool = true) -> PathComponentsMatcher { Self.empty.string(capture: capture) }
    public static func number(capture: Bool = true) -> PathComponentsMatcher { Self.empty.number(capture: capture) }

    public static var string: PathComponentsMatcher { Self.empty.string }
    public static var number: PathComponentsMatcher { Self.empty.number }
    public static var any: PathComponentsMatcher { Self.empty.any }
    public static var path: PathComponentsMatcher { Self.empty.path }

    func append(pattern: String, capture: Bool) -> PathComponentsMatcher {
        self.pathPattern += (capture ? "(\(pattern))" : pattern)
        return self
    }
}

postfix operator /
public postfix func /(_ lhs: PathComponentsMatcher) -> PathComponentsMatcher {
    lhs.pathPattern += "/"
    return lhs
}

prefix operator /
public prefix func /(_ rhs: PathComponentsMatcher) -> PathComponentsMatcher {
    rhs.pathPattern = "/" + rhs.pathPattern
    return rhs
}

public func /(_ lhs: PathComponentsMatcher, _ rhs: PathComponentsMatcher) -> PathComponentsMatcher {
    lhs.pathPattern += "/" + rhs.pathPattern
    return lhs
}

public func /(_ lhs: PathComponentsMatcher, _ rhs: EndMatcher) -> EndMatcher {
    rhs.pathPattern = lhs.pathPattern + "/" + rhs.pathPattern
    return rhs
}

public class QueryComponentsMatcher: URLComponentsMatcher {
    static let pattern = #"((?:&?[^=&?]+=[^=&?]+)*)"#
    public private(set) var pathPattern: String
    public private(set) var queryParams: [String: String]

    init(pathPattern: String = "", params: [String: String]) {
        self.pathPattern = pathPattern
        self.queryParams = params
    }

    public func string(_ name: String) -> QueryComponentsMatcher { append(param: name, pattern: "([a-zA-Z]+)") }
    public func number(_ name: String) -> QueryComponentsMatcher { append(param: name, pattern: "([0-9]+)") }
    public func any(_ name: String) -> QueryComponentsMatcher { append(param: name, pattern: "([^/]+)") }
    public var end: EndMatcher { EndMatcher(pathPattern: pathPattern, queryParams: queryParams) }

    func append(param: String, pattern: String) -> QueryComponentsMatcher {
        if !pathPattern.hasSuffix(QueryComponentsMatcher.pattern) {
            pathPattern += QueryComponentsMatcher.pattern
        }
        queryParams[param] = pattern
        return self
    }
}

public func /(_ lhs: PathComponentsMatcher, _ rhs: QueryComponentsMatcher) -> PathComponentsMatcher {
    lhs.pathPattern = lhs.pathPattern + "/" + rhs.pathPattern
    lhs.queryParams = rhs.queryParams
    return lhs
}

postfix operator /?
public postfix func /? (_ lhs: PathComponentsMatcher) -> QueryComponentsMatcher {
    return QueryComponentsMatcher(pathPattern: lhs.pathPattern + #"/?\?"#, params: [:])
}

postfix operator &
public postfix func &(_ lhs: QueryComponentsMatcher) -> QueryComponentsMatcher {
    return lhs
}

