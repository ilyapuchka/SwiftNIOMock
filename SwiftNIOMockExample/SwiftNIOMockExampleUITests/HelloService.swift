//
//  HelloService.swift
//  SwiftNIOMockExampleUITests
//
//  Created by Ilya Puchka on 09/02/2020.
//  Copyright © 2020 Ilya Puchka. All rights reserved.
//

import SwiftNIOMock

class HelloService: Service {
    //sourcery:wrap:Route: GET/.hello/.string
    func _helloworld(name: String) -> String {
        "Hello \(name)!"
    }
    
    override init() {
        super.init()
        __helloworld.registerRoute(self)
    }
}
