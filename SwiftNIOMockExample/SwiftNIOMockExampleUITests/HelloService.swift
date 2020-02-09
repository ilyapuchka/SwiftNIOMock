//
//  HelloService.swift
//  SwiftNIOMockExampleUITests
//
//  Created by Ilya Puchka on 09/02/2020.
//  Copyright © 2020 Ilya Puchka. All rights reserved.
//

import SwiftNIOMock
import URLFormat

class HelloService: Service {
    //sourcery:wrap:Route: GET/.hello/.string
    func _helloworld(name: String) -> String {
        "Hello \(name)!"
    }
    
    //sourcery:inline:HelloService.Wrapper
    private var __helloworld: Route<HelloService, String> {
        func _helloworld(name: String) -> String {
            "Hello \(name)!"
        }
        return Route(GET/.hello/.string) { params in
            return _helloworld(name: params)
        }
    }
    func helloworld(name: String) -> String {
        __helloworld(name: name)
    }
    //sourcery:end
    
    override init() {
        super.init()
        __helloworld.registerRoute(self)
    }
}
