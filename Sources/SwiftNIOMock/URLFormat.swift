import Foundation
import Prelude
import CommonParsers

extension URLComponents: Monoid {
    public static var empty: URLComponents = URLComponents()

    public var isEmpty: Bool {
        return pathComponents.isEmpty && scheme == nil && host == nil
    }

    public static func <> (lhs: URLComponents, rhs: URLComponents) -> URLComponents {
        var result = URLComponents()
        result.scheme = lhs.scheme ?? rhs.scheme
        result.host = lhs.host ?? rhs.host
        result.path = [lhs.path, rhs.path]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        if lhs.host != nil && rhs.host == nil {
            result.path = "/" + result.path
        }

        result.queryItems =
            lhs.queryItems.flatMap { lhs in
                rhs.queryItems.flatMap { rhs in lhs + rhs }
                    ?? lhs
            }
            ?? rhs.queryItems
        return result
    }

    public var pathComponents: [String] {
        get {
            if path.isEmpty {
                return []
            } else if path.hasPrefix("/") {
                return path.dropFirst().components(separatedBy: "/")//.filter { !$0.isEmpty }
            } else {
                return path.components(separatedBy: "/")//.filter { !$0.isEmpty }
            }
        }
        set {
            path = newValue.joined(separator: "/")
        }
    }

    func with(_ f: (inout URLComponents) -> Void) -> URLComponents {
        var v = self
        f(&v)
        return v
    }
}

public struct URLFormat<A>: ExpressibleByStringLiteral {
    public let parser: Parser<URLComponents, A>

    public init(_ parser: Parser<URLComponents, A>) {
        self.parser = parser
    }

    public init(stringLiteral value: String) {
        self.init(path(String(value)).map(.any))
    }

//    public func render(_ a: A) throws -> String? {
//        return try self.parser.print(a).flatMap { $0.render() }
//    }
//
//    public func match(_ template: URLComponents) throws -> A? {
//        return try (self </> URLFormat.end).parser.parse(template)?.match
//    }

}

//precedencegroup _infixr4 {
//  associativity: right
//  higherThan: MultiplicationPrecedence
//}

//infix operator </>: _infixr4
infix operator /?: AdditionPrecedence//_infixr4
//infix operator &: _infixr4

extension URLFormat {
    /// Processes with the left and right side Formats, and if they succeed returns the pair of their results.
    public static func / <B> (lhs: URLFormat, rhs: URLFormat<B>) -> URLFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    /// Processes with the left and right side Formats, discarding the result of the left side.
//    public static func / (x: URLFormat<Prelude.Unit>, y: URLFormat) -> URLFormat {
//        return .init(x.parser %> y.parser)
//    }

    public static func / (x: URLFormat<Prelude.Unit>, y: PartialIso<String, A>) -> URLFormat {
        return .init(x.parser %> path(y).parser)
    }

    public static func /? <B> (lhs: URLFormat, rhs: URLFormat<B>) -> URLFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

//    public static func /? <B> (lhs: URLFormat, rhs: Parser<URLComponents, B>) -> URLFormat<(A, B)> {
//        return .init(lhs.parser <%> rhs)
//    }

    public static func /? (x: URLFormat<Prelude.Unit>, y: URLFormat) -> URLFormat {
        return .init(x.parser %> y.parser)
    }

    public static func & <B> (lhs: URLFormat, rhs: URLFormat<B>) -> URLFormat<(A, B)> {
        return .init(lhs.parser <%> rhs.parser)
    }

    public static func & (x: URLFormat<Prelude.Unit>, y: URLFormat) -> URLFormat {
        return .init(x.parser %> y.parser)
    }
}

extension URLFormat where A == Prelude.Unit {
    /// Processes with the left and right Formats, discarding the result of the right side.
    public static func / <B>(x: URLFormat<B>, y: URLFormat) -> URLFormat<B> {
        return .init(x.parser <% y.parser)
    }

    public static func /? <B>(x: URLFormat<B>, y: URLFormat) -> URLFormat<B> {
        return .init(x.parser <% y.parser)
    }

    public static func & <B>(x: URLFormat<B>, y: URLFormat) -> URLFormat<B> {
        return .init(x.parser <% y.parser)
    }
}

postfix operator /
public postfix func / <A>(_ lhs: URLFormat<A>) -> URLFormat<A> {
    return lhs
}
prefix operator /
public prefix func / <A>(_ rhs: URLFormat<A>) -> URLFormat<A> {
    return rhs
}

postfix operator /?
public postfix func /? <A>(_ lhs: URLFormat<A>) -> URLFormat<A> {
    return lhs
}

postfix operator &
public postfix func & <A>(_ lhs: URLFormat<A>) -> URLFormat<A> {
    return lhs
}

extension URLFormat {
    public var string: URLFormat<(A, String)> {
        return .init(self.parser <%> path(.string).parser)
    }
    public var int: URLFormat<(A, Int)> {
        return .init(self.parser <%> path(.int).parser)
    }
}

extension URLFormat where A == Prelude.Unit {
    public var string: URLFormat<String> {
        return .init(self.parser %> path(.string).parser)
    }
    public var int: URLFormat<Int> {
        return .init(self.parser %> path(.int).parser)
    }
}

extension URLFormat where A == String {
    public static var string: URLFormat<String> {
        return .init(Parser<URLComponents, Prelude.Unit>.any %> path(.string).parser)
    }
}
extension URLFormat where A == Int {
    public static var int: URLFormat<Int> {
        return .init(Parser<URLComponents, Prelude.Unit>.any %> path(.int).parser)
    }
}

extension Parser where T == URLComponents, A == Prelude.Unit {
    public static var any: Parser {
        return Parser.init(
            parse: { (urlComponents) -> (rest: URLComponents, match: Prelude.Unit)? in
                (urlComponents, unit)
        },
            print: { (unit) -> URLComponents? in
                URLComponents.init()
        }) { (unit) -> URLComponents? in
            URLComponents.init()
        }
    }
}
//
//postfix operator /
//public postfix func / <A>(_ lhs: URLFormat<A>) -> URLFormat<A> {
//    return lhs
//}
//
//prefix operator /
//public prefix func / <A>(_ rhs: URLFormat<A>) -> URLFormat<A> {
//    return rhs
//}

//public func /(_ lhs: PathComponentsMatcher, _ rhs: EndMatcher) -> EndMatcher {
//    rhs.pathPattern = lhs.pathPattern + "/" + rhs.pathPattern
//    return rhs
//}

extension URLFormat {
    public static var end: URLFormat<Prelude.Unit> {
        return URLFormat<Prelude.Unit>(
            Parser(
                parse: { $0.isEmpty ? (.empty, unit) : nil },
                print: const(.empty),
                template: const(.empty)
            )
        )
    }
}

public func path(_ str: String) -> Parser<URLComponents, Prelude.Unit> {
    return Parser<URLComponents, Prelude.Unit>(
        parse: { format in
            return head(format.pathComponents).flatMap { (p, ps) in
                return p == str
                    ? (format.with { $0.pathComponents = ps }, unit)
                    : nil
            }
    },
        print: { _ in URLComponents().with { $0.path = str } },
        template: { _ in URLComponents().with { $0.path = str } }
    )
}

public func path(_ str: String) -> URLFormat<Prelude.Unit> {
    return URLFormat<Prelude.Unit>(path(str))
}

public func path<A>(_ f: PartialIso<String, A>) -> Parser<URLComponents, A> {
    return Parser<URLComponents, A>(
        parse: { format in
            guard let (p, ps) = head(format.pathComponents), let v = try f.apply(p) else { return nil }
            return (format.with { $0.pathComponents = ps }, v)
    },
        print: { a in
            try f.unapply(a).flatMap { s in
                URLComponents().with { $0.path = s }
            }
    },
        template: { a in
            try f.unapply(a).flatMap { s in
                return URLComponents().with { $0.path = ":" + "\(type(of: a))" }
            }
    })
}

public func path<A>(_ f: PartialIso<String, A>) -> URLFormat<A> {
    return URLFormat<A>(path(f))
}

public func query<A>(_ key: String, _ f: PartialIso<String, A>) -> Parser<URLComponents, A> {
    return Parser<URLComponents, A>(
        parse: { format in
            guard
                let queryItems = format.queryItems,
                let p = queryItems.first(where: { $0.name == key })?.value,
                let v = try f.apply(p)
                else { return nil }
            return (format, v)
    },
        print: { a in
            try f.unapply(a).flatMap { s in
                URLComponents().with { $0.queryItems = [URLQueryItem(name: key, value: s)] }
            }
    },
        template: { a in
            try f.unapply(a).flatMap { s in
                URLComponents().with { $0.queryItems = [URLQueryItem(name: key, value: ":" + "\(type(of: a))")] }
            }
    })
}

public func query<A>(_ key: String, _ f: PartialIso<String, A>) -> URLFormat<A> {
    return URLFormat<A>(query(key, f))
}

func head<A>(_ xs: [A]) -> (A, [A])? {
    guard let x = xs.first else { return nil }
    return (x, Array(xs.dropFirst()))
}

extension URLFormat where A == Int {
    /// An isomorphism between strings and integers.
    public static func int(_ name: String) -> Self {
        return URLFormat<A>(query(name, .int))
    }
}

extension URLFormat {
    /// An isomorphism between strings and integers.
    public func string(_ name: String) -> URLFormat<(A, String)> {
        return .init(self.parser <%> query(name, .string).parser)
    }
    public func int(_ name: String) -> URLFormat<(A, Int)> {
        return .init(self.parser <%> query(name, .int).parser)
    }
}
