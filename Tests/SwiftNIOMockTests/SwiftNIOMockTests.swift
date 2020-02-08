import XCTest
@testable import SwiftNIOMock
import NIOHTTP1
import URLFormat
import CommonParsers
import Prelude

class SwiftNIOMockTests: XCTestCase {
    func withServer(
        handler: @escaping Middleware = { _, _, next in next() },
        expect: String = "",
        assert: (Server, XCTestExpectation) -> Void
    ) {
        let server = Server(port: 8080, handler: handler)
        try! server.start()
        defer { try! server.stop() }
        
        let expectation = self.expectation(description: expect)
        assert(server, expectation)
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testCanRestartServer() {
        // given server
        let server = Server(port: 8080)

        // when started
        try! server.start()

        // then should beb stopped to restart
        XCTAssertThrowsError(try server.start(), "Should not start server without stopping it first")

        // when stopped
        try! server.stop()

        // then can restart
        XCTAssertNoThrow(try server.start(), "Server should start again after being stopped")
        try! server.stop()
    }

    func testCanRunTwoServersOnDifferentPorts() {
        // given server1
        let server1 = Server(port: 8080)
        // given server2
        let server2 = Server(port: 8081)

        // when started 1
        try! server1.start()

        //then can start another server on another port
        XCTAssertNoThrow(try server2.start(), "Second server should be started on another port")

        try! server1.stop()
        try! server2.stop()
    }

    func testCanReturnDefaultResponse() {
        // given server with empty handler
        withServer { server, expectation in
            // when making a request
            let url = URL(string: "http://localhost:8080")!
            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { expectation.fulfill() }

                // expect to recieve default response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertTrue(data?.count == 0)
            }.resume()
        }
    }

    func testCanRedirectRequestAndInterceptResponse() {
        // given server configured with redirect
        let calledRedirect = self.expectation(description: "")
        let redirectRequest = { (request: Server.HTTPHandler.Request) -> Server.HTTPHandler.Request in
            defer { calledRedirect.fulfill() }
            
            var head = request.head
            head.headers.add(name: "custom-request-header", value: "custom-request-header-value")

            var components = URLComponents(string: head.uri)!
            components.host = "postman-echo.com"
            components.path = "/\(String(describing: request.head.method).lowercased())"
            components.scheme = "https"
            head.uri = components.url!.absoluteString

            return Server.HTTPHandler.Request(head: head, body: request.body, ctx: request.ctx)
        }

        let calledIntercept = self.expectation(description: "")
        var originalResponse: HTTPResponseHead!
        let interceptResponse = { (response: Server.HTTPHandler.Response) in
            defer { calledIntercept.fulfill() }
            
            response.statusCode = .created
            response.headers.add(name: "custom-response-header", value: "custom-response-header-value")

            response.body = response.body
                .flatMap { try? JSONSerialization.jsonObject(with: $0, options: []) }
                .flatMap { try? JSONSerialization.data(withJSONObject: ["response": $0], options: []) }

            originalResponse = HTTPResponseHead(
                version: HTTPVersion(major: 1, minor: 1),
                status: response.statusCode,
                headers: response.headers
            )
        }
        let redirect = SwiftNIOMock.redirect(
            request: redirectRequest,
            response: interceptResponse
        )
        
        struct EchoData: Decodable, Equatable {
            let args: [String: String]
            let data: String
            let headers: [String: String]
            let url: String
        }
        struct ResponseJSON: Decodable, Equatable {
            let response: EchoData
        }
        // expect to recieve intercepted response
        let expectedResponseJSON = ResponseJSON(response: EchoData(
            args: ["query": "value"],
            data: "Hello world!",
            headers: [
                "accept": "*/*",
                "accept-encoding": "gzip",
                "accept-language": "en-gb",
                "cache-control": "no-cache",
                "content-length": "12",
                "content-type": "text/html; charset=utf-8",
                "custom-request-header": "custom-request-header-value",
                "host": "localhost",
                "user-agent": "xctest",
                "x-forwarded-port": "443",
                "x-forwarded-proto": "https"
            ],
            url: "https://localhost/post?query=value"
        ))

        let url = URL(string: "http://localhost:8080?query=value")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "Hello world!".data(using: .utf8)
        request.setValue("text/html; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("xctest", forHTTPHeaderField: "User-Agent")
        request.setValue("en-gb", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        withServer(handler: redirect) { (server, expectation) in
            // when making a request
            URLSession.shared.dataTask(with: request) { data, response, error in
                defer { expectation.fulfill() }
                
                let receivedResponseJSON = data.flatMap { try? JSONDecoder().decode(ResponseJSON.self, from: $0) }

                XCTAssertEqual(expectedResponseJSON.response.args, receivedResponseJSON?.response.args)
                XCTAssertEqual(expectedResponseJSON.response.data, receivedResponseJSON?.response.data)
                XCTAssertEqual(expectedResponseJSON.response.headers, receivedResponseJSON?.response.headers)
                XCTAssertEqual(expectedResponseJSON, receivedResponseJSON)

                let httpResponse = response as! HTTPURLResponse
                var responseHead = HTTPResponseHead(
                    version: HTTPVersion(major: 1, minor: 1),
                    status: HTTPResponseStatus.init(statusCode: httpResponse.statusCode),
                    headers: HTTPHeaders(httpResponse.allHeaderFields.map { ("\($0.key)", "\($0.value)") })
                )

                // content lengths and encoding will be different because of compression
                // see: https://github.com/apple/swift-nio/issues/717
                responseHead.headers.remove(name: "Content-Length")
                originalResponse.headers.remove(name: "Content-Length")
                responseHead.headers.remove(name: "Content-Encoding")
                originalResponse.headers.remove(name: "Content-Encoding")

                XCTAssertEqual(responseHead, originalResponse)
            }.resume()
        }
    }
    
    func testEmptyRouter() {
        // given server with empty router
        withServer(handler: router()) { server, expectation in
            // when making a request
            let url = URL(string: "http://localhost:8080")!
            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { expectation.fulfill() }
                // expect to recieve default not found response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "Not Found")
            }.resume()
        }
    }
    
    func testNonEmptyRouter() {
        // given server with non empty router
        let router = SwiftNIOMock.router {
            route(GET/.helloworld) { (request, response, next) in
                response.sendString(.ok, value: "Hello world!")
                next()
            }
        }
        withServer(handler: router) { server, expectation in
            defer { expectation.fulfill() }
            
            // when making request to known route
            let knownRouteExpectation = self.expectation(description: "")
            let knownUrl = URL(string: "http://localhost:8080/helloworld")!
            URLSession.shared.dataTask(with: knownUrl) { data, response, error in
                defer { knownRouteExpectation.fulfill() }
                // expect to recieve registered response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "Hello world!")
            }.resume()
            
            // when making request to unknown route
            let unknownRouteExpectation = self.expectation(description: "")
            let unknownUrl = URL(string: "http://localhost:8080")!
            URLSession.shared.dataTask(with: unknownUrl) { data, response, error in
                defer { unknownRouteExpectation.fulfill() }
                // expect to recieve default not found response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "Not Found")
            }.resume()
        }
    }
    
    func testMultipleRoutes() {
        let router = SwiftNIOMock.router(services: [
            Service {
                route(GET/.helloworld) { (request, response, next) in
                    response.sendString(.ok, value: "Hello world!")
                    next()
                }
                route(.GET, { $0.head.uri == "/echo" }) { (request, response, next) in
                    response.sendString(.ok, value: "echo")
                    next()
                }
            }
        ])

        withServer(handler: router) { server, expectation in
            defer { expectation.fulfill() }

            // when making request to known route
            let knownRouteExpectation = self.expectation(description: "")
            let knownUrl = URL(string: "http://localhost:8080/helloworld")!
            URLSession.shared.dataTask(with: knownUrl) { data, response, error in
                defer { knownRouteExpectation.fulfill() }
                // expect to recieve registered response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "Hello world!")
            }.resume()

            // when making request to another route
            let anotherRouteExpectation = self.expectation(description: "")
            let anotherUrl = URL(string: "http://localhost:8080/echo")!
            URLSession.shared.dataTask(with: anotherUrl) { data, response, error in
                defer { anotherRouteExpectation.fulfill() }
                // expect to recieve default not found response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "echo")
            }.resume()

            // when making request to unknown route
            let unknownRouteExpectation = self.expectation(description: "")
            let unknownUrl = URL(string: "http://localhost:8080")!
            URLSession.shared.dataTask(with: unknownUrl) { data, response, error in
                defer { unknownRouteExpectation.fulfill() }
                // expect to recieve default not found response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "Not Found")
            }.resume()
        }
    }
    
    func testMultipleServices() {
        let helloService = Service {
            route(GET/.helloworld) { (request, response, next) in
                response.sendString(.ok, value: "Hello world!")
                next()
            }
        }
        let echoService = Service {
            route(GET/.echo) { (request, response, next) in
                response.sendString(.ok, value: "echo")
                next()
            }
        }
        
        let router = SwiftNIOMock.router(services: [
            helloService,
            echoService
        ])

        withServer(handler: router) { server, expectation in
            defer { expectation.fulfill() }
            
            // when making request to known route
            let knownRouteExpectation = self.expectation(description: "")
            let knownUrl = URL(string: "http://localhost:8080/helloworld")!
            URLSession.shared.dataTask(with: knownUrl) { data, response, error in
                defer { knownRouteExpectation.fulfill() }
                // expect to recieve registered response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "Hello world!")
            }.resume()
            
            // when making request to another route
            let anotherRouteExpectation = self.expectation(description: "")
            let anotherUrl = URL(string: "http://localhost:8080/echo")!
            URLSession.shared.dataTask(with: anotherUrl) { data, response, error in
                defer { anotherRouteExpectation.fulfill() }
                // expect to recieve default not found response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "echo")
            }.resume()
            
            // when making request to unknown route
            let unknownRouteExpectation = self.expectation(description: "")
            let unknownUrl = URL(string: "http://localhost:8080")!
            URLSession.shared.dataTask(with: unknownUrl) { data, response, error in
                defer { unknownRouteExpectation.fulfill() }
                // expect to recieve default not found response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "Not Found")
            }.resume()
        }
    }
    
    func testKeyPaths() {
        class HelloService: Service {
            let users: [String]
            var echo: String
            
            func user(byName name: String) -> String? {
                users.first { $0 == name }
            }
            
            init(users: [String], echo: String) {
                self.users = users
                self.echo = echo
                super.init()
                
                routes {
                    GET/.echo == \HelloService.echo
                    GET/.users == \HelloService.users
                    GET/.users/.string == HelloService.user(byName:)
                }
            }
        }
        
        let helloService = HelloService(users: ["Foo", "Bar"], echo: "")
        
        var router: Middleware! = SwiftNIOMock.router(services: [helloService])
        withServer(handler: router) { server, expectation in
            // when making request to known route
            let knownUrl = URL(string: "http://localhost:8080/users")!
            URLSession.shared.dataTask(with: knownUrl) { data, response, error in
                defer { expectation.fulfill() }
                // expect to recieve registered response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                let users = try! JSONEncoder().encode(helloService.users)
                let usersString = "\(String(data: users, encoding: .utf8)!)"
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, usersString)
            }.resume()
            
            helloService.echo = "Hello world!"
            
            // when making request to another route
            let anotherRouteExpectation = self.expectation(description: "")
            let anotherUrl = URL(string: "http://localhost:8080/echo")!
            URLSession.shared.dataTask(with: anotherUrl) { data, response, error in
                defer { anotherRouteExpectation.fulfill() }
                // expect to recieve default not found response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "\"Hello world!\"")
            }.resume()
            
            // when making request to unknown route
            let unknownRouteExpectation = self.expectation(description: "")
            var request = URLRequest(url: URL(string: "http://localhost:8080/echo")!)
            request.httpMethod = "PUT"
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                defer { unknownRouteExpectation.fulfill() }
                // expect to recieve default not found response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "Not Found")
            }.resume()

            // when making request to parametrised route
            let parameterRouteExpectation = self.expectation(description: "")
            let parameterUrl = URL(string: "http://localhost:8080/users/Foo")!
            URLSession.shared.dataTask(with: parameterUrl) { data, response, error in
                defer { parameterRouteExpectation.fulfill() }
                // expect to recieve default not found response
                XCTAssertNil(error)
                XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
                XCTAssertEqual(data.flatMap { String(data: $0, encoding: .utf8) }, "\"Foo\"")
            }.resume()
        }
    }


}

