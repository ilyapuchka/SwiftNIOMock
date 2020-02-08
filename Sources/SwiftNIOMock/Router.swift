import Foundation
import NIO
import NIOHTTP1
import URLFormat
import CommonParsers
import Prelude

public typealias RouteMiddleware<A> = (
    _ request: Server.HTTPHandler.Request,
    _ parameters: A,
    _ response: Server.HTTPHandler.Response,
    _ next: @escaping () -> Void
) -> Void

public func route(_ format: URLFormat<Prelude.Unit>, response: @escaping Middleware) -> Middleware {
    route(format, response: { response($0, $2, $3) })
}

public func route<A>(_ format: URLFormat<A>, response: @escaping RouteMiddleware<A>) -> Middleware {
    return { request, httpResponse, next in
        do {
            let components = URLRequestComponents(
                method: String(describing: request.head.method),
                urlComponents: URLComponents(string: request.head.uri)!
            )
            guard let params = try format.parse(components) else {
                return next()
            }
            response(request, params, httpResponse, next)
        } catch {
            next()
        }
    }
}

extension ServiceProtocol where Self: Service {
    public func bind<T: Encodable, A>(format: URLFormat<A>, to keyPath: KeyPath<Self, T>) -> Middleware {
        return route(format, response: { [weak self] _, params, response, next in
            guard let self = self else { return next() }
            try! response.sendJSON(.ok, value: self[keyPath: keyPath])
            next()
        })
    }
    public func bind<T: Encodable, A>(format: URLFormat<A>, to value: @escaping (A) throws -> T) -> Middleware {
        return route(format, response: { [weak self] _, params, response, next in
            guard let _ = self else { return next() }
            try! response.sendJSON(.ok, value: value(params))
            next()
        })
    }
    public func bind<T: Encodable, A>(format: URLFormat<A>, to value: @escaping (A, Server.HTTPHandler.Request) throws -> T) -> Middleware {
        return route(format, response: { [weak self] request, params, response, next in
            guard let _ = self else { return next() }
            try! response.sendJSON(.ok, value: value(params, request))
            next()
        })
    }
}

public func ==<S: Service, T: Encodable>(lhs: URLFormat<Prelude.Unit>, rhs: KeyPath<S, T>) -> (S) -> Middleware {
    return { service in
        service.bind(format: lhs, to: rhs)
    }
}

public func ==<S: Service, T: Encodable, A>(lhs: URLFormat<A>, rhs: @escaping (S) -> (A) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B>(lhs: URLFormat<(A, B)>, rhs: @escaping (S) -> (A, B) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0, $0.1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C>(lhs: URLFormat<((A, B), C)>, rhs: @escaping (S) -> (A, B, C) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0, $0.0.1, $0.1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D>(lhs: URLFormat<(((A, B), C), D)>, rhs: @escaping (S) -> (A, B, C, D) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0, $0.0.0.1, $0.0.1, $0.1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E>(lhs: URLFormat<((((A, B), C), D), E)>, rhs: @escaping (S) -> (A, B, C, D, E) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E, F>(lhs: URLFormat<(((((A, B), C), D), E), F)>, rhs: @escaping (S) -> (A, B, C, D, E, F) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0.0, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E, F, G>(lhs: URLFormat<((((((A, B), C), D), E), F), G)>, rhs: @escaping (S) -> (A, B, C, D, E, F, G) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0.0.0, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E, F, G, H>(lhs: URLFormat<(((((((A, B), C), D), E), F), G), H)>, rhs: @escaping (S) -> (A, B, C, D, E, F, G, H) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E, F, G, H, I>(lhs: URLFormat<((((((((A, B), C), D), E), F), G), H), I)>, rhs: @escaping (S) -> (A, B, C, D, E, F, G, H, I) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E, F, G, H, I, J>(lhs: URLFormat<(((((((((A, B), C), D), E), F), G), H), I), J)>, rhs: @escaping (S) -> (A, B, C, D, E, F, G, H, I, J) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1)
        })
    }
}

public func ==<S: Service, T: Encodable, A>(lhs: URLFormat<A>, rhs: @escaping (S) -> (A, Server.HTTPHandler.Request) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0, $1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B>(lhs: URLFormat<(A, B)>, rhs: @escaping (S) -> (A, B, Server.HTTPHandler.Request) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0, $0.1, $1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C>(lhs: URLFormat<((A, B), C)>, rhs: @escaping (S) -> (A, B, C, Server.HTTPHandler.Request) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0, $0.0.1, $0.1, $1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D>(lhs: URLFormat<(((A, B), C), D)>, rhs: @escaping (S) -> (A, B, C, D, Server.HTTPHandler.Request) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0, $0.0.0.1, $0.0.1, $0.1, $1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E>(lhs: URLFormat<((((A, B), C), D), E)>, rhs: @escaping (S) -> (A, B, C, D, E, Server.HTTPHandler.Request) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E, F>(lhs: URLFormat<(((((A, B), C), D), E), F)>, rhs: @escaping (S) -> (A, B, C, D, E, F, Server.HTTPHandler.Request) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0.0, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E, F, G>(lhs: URLFormat<((((((A, B), C), D), E), F), G)>, rhs: @escaping (S) -> (A, B, C, D, E, F, G, Server.HTTPHandler.Request) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0.0.0, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E, F, G, H>(lhs: URLFormat<(((((((A, B), C), D), E), F), G), H)>, rhs: @escaping (S) -> (A, B, C, D, E, F, G, H, Server.HTTPHandler.Request) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E, F, G, H, I>(lhs: URLFormat<((((((((A, B), C), D), E), F), G), H), I)>, rhs: @escaping (S) -> (A, B, C, D, E, F, G, H, I, Server.HTTPHandler.Request) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1)
        })
    }
}

public func ==<S: Service, T: Encodable, A, B, C, D, E, F, G, H, I, J>(lhs: URLFormat<(((((((((A, B), C), D), E), F), G), H), I), J)>, rhs: @escaping (S) -> (A, B, C, D, E, F, G, H, I, J, Server.HTTPHandler.Request) throws -> T) -> (S) -> Middleware {
    return { (service: S) in
        service.bind(format: lhs, to: { [unowned service] in
            try rhs(service)($0.0.0.0.0.0.0.0.0.0, $0.0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.0.1, $0.0.0.0.0.0.0.1, $0.0.0.0.0.0.1, $0.0.0.0.0.1, $0.0.0.0.1, $0.0.0.1, $0.0.1, $0.1, $1)
        })
    }
}
