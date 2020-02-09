//
//  RouteWrapper.swift
//  SwiftNIOMockExampleUITests
//
//  Created by Ilya Puchka on 09/02/2020.
//  Copyright © 2020 Ilya Puchka. All rights reserved.
//

import SwiftNIOMock
import URLFormat
import Prelude

@dynamicCallable
struct Route<S: Service, T: Encodable> {
    private let route: (KeyValuePairs<String, Any>) -> T
    let registerRoute: (S) -> Void
    
    func dynamicallyCall(withKeywordArguments args: KeyValuePairs<String, Any>) -> T {
        route(args)
    }

    private init<A>(format: URLFormat<A>, handler: @escaping (A) -> T, route: @escaping (KeyValuePairs<String, Any>) -> T) {
        self.route = route
        self.registerRoute = { service in
            service.routes {
                SwiftNIOMock.route(format) { (request, params, response, next) in
                    do {
                        let result = handler(params)
                        try response.sendJSON(.ok, value: result)
                        next()
                    } catch {
                        next()
                    }
                }
            }
        }
    }
    
    init<A>(_ format: URLFormat<A>, route: @escaping (A) -> T) {
        self.init(
            format: format,
            handler: route,
            route: {
                route($0[0].value as! A)
            }
        )
    }

    init<A, B>(_ format: URLFormat<(A, B)>, route: @escaping ((A, B)) -> T) {
        self.init(
            format: format,
            handler: route,
            route: {
                route(($0[0].value, $0[1].value) as! (A, B))
            }
        )
    }

    init<A, B, C>(_ format: URLFormat<((A, B), C)>, route: @escaping ((A, B, C)) -> T) {
        self.init(
            format: format,
            handler: { route(flatten($0)) },
            route: {
                route(($0[0].value, $0[1].value, $0[2].value) as! (A, B, C))
            }
        )
    }

    init<A, B, C, D>(_ format: URLFormat<(((A, B), C), D)>, route: @escaping ((A, B, C, D)) -> T) {
        self.init(
            format: format,
            handler: { route(flatten($0)) },
            route: {
                route(($0[0].value, $0[1].value, $0[2].value, $0[3].value) as! (A, B, C, D))
            }
        )
    }
}
