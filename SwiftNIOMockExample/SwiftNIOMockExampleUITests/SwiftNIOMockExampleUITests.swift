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

    override func setUp() {
        continueAfterFailure = false
        XCUIApplication().launch()
        server = Server(port: 8080)
        try! server.start()
    }

    override func tearDown() {
        try! server.stop()
        server = nil
    }

    func testExample() {
        let exp = expectation(description: "Recieved response")
        var request = URLRequest(url: URL(string: "http://localhost:8080")!)
        request.httpMethod = "POST"
        request.httpBody = "Hello world".data(using: .utf8)
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
