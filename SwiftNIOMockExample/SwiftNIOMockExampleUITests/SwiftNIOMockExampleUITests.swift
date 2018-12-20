//
//  SwiftNIOMockExampleUITests.swift
//  SwiftNIOMockExampleUITests
//
//  Created by Ilya Puchka on 18/12/2018.
//  Copyright © 2018 Ilya Puchka. All rights reserved.
//

import XCTest
import SwiftNIOMock

class SwiftNIOMockExampleUITests: XCTestCase {
    var server: Server!
    let notFound = SwiftNIOMock.redirect(
        session: URLSession.shared,
        request: { (request) in
            var head = request.head
            head.uri = "https://postman-echo.com/\(String(describing: request.head.method).lowercased())"
            return Server.HTTPHandler.Request(head: head, body: request.body, ctx: request.ctx)
    }, body: { data in
        let string = String.init(data: data, encoding: .utf8)!
        return ("This response was intercepted!\r\n" + string).data(using: .utf8)!
    })

    override func setUp() {
        continueAfterFailure = false
        XCUIApplication().launch()

        server = Server(port: 8080, router:
            SwiftNIOMock.router(route: { request in
                guard case .GET = request.head.method, request.head.uri == "/helloworld" else {
                    return nil
                }
                return { (request, response, next) in
                    response.sendString(.ok, value: "Hello world!")
                    next()
                }
            }, notFound: notFound)
        )
        try! server.start()
    }

    override func tearDown() {
        try! server.stop()
        server = nil
    }

    func testGET() {
        let exp = expectation(description: "Recieved response")
        var request = URLRequest(url: URL(string: "http://localhost:8080")!)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            print(String(data: data ?? Data(), encoding: .utf8) ?? "nil")
            print(response ?? "nil")
            print(error ?? "nil")
            if response != nil {
                exp.fulfill()
            }
        }.resume()
        wait(for: [exp], timeout: 5)
    }

    func testPOST() {
        let exp = expectation(description: "Recieved response")
        var request = URLRequest(url: URL(string: "http://localhost:8080")!)
        request.httpMethod = "POST"
        request.httpBody = "Hello world".data(using: .utf8)
        request.setValue("text/html; charset=utf-8", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            print(String(data: data ?? Data(), encoding: .utf8) ?? "nil")
            print(response ?? "nil")
            print(error ?? "nil")
            if response != nil {
                exp.fulfill()
            }
            }.resume()
        wait(for: [exp], timeout: 5)
    }

    func testRoute() {
        let exp = expectation(description: "Recieved response")
        var request = URLRequest(url: URL(string: "http://localhost:8080/helloworld")!)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            print(String(data: data ?? Data(), encoding: .utf8) ?? "nil")
            print(response ?? "nil")
            print(error ?? "nil")
            if response != nil {
                exp.fulfill()
            }
            }.resume()
        wait(for: [exp], timeout: 5)
    }

    func testDelay() {
        try! server.stop()

        server = Server(port: 8080, router: SwiftNIOMock.delay(.seconds(2), middleware: notFound))
        try! server.start()

        let exp = expectation(description: "Recieved response")
        var request = URLRequest(url: URL(string: "http://localhost:8080")!)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            print(String(data: data ?? Data(), encoding: .utf8) ?? "nil")
            print(response ?? "nil")
            print(error ?? "nil")
            if response != nil {
                exp.fulfill()
            }
            }.resume()
        wait(for: [exp], timeout: 5)
    }

}
