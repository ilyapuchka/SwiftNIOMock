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
        URLSession.shared.dataTask(with: URL(string: "http://localhost:8080")!)
        URLSession.shared.dataTask(with: URL(string: "http://localhost:8080")!) { (data, response, error) in
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
