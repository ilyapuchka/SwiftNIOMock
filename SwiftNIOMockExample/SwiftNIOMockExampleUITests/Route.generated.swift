// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import URLFormat
import SwiftNIOMock

extension HelloService {
    var __helloworld: Route<HelloService, String> {
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

}
