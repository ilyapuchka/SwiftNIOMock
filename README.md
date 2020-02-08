# SwiftNIOMock
A web server based on [SwiftNIO](https://github.com/apple/swift-nio) designed to be used as a mock server in UI automation tests.

When running UI tests against real server several issues can come along: network can be unstable, content on the remote server can change, some of the test scenarios may require actions in some external system, and in general making network calls slows down all the tests.

SwiftNIOMock aims to address these issues by providing a mock web server implementation that runs on the `localhost` and which app should access instead of a real server when running under UI test. Unlike other solutions like registering custom `URLProtocol` using mock server requires only switching the app to the `localhost` and gives you much more flexibility and control as the server is controlled by the test and you can change its state from within the test scenarios. 

SwiftNIOMock supports three common scenarios:

- redirect requests to the real service using `redirect` middleware. This can be used for logging purposes which can make debugging easier as all the network logs will be in the console log of the test runner process

- mock endpoints using `router` middleware. This is useful when you need to have more control over the state of the mock server and allows you to completely mock out all network requests the app makes (although it can be used along with `redirect` middleware). This is usually needed when tests scenarios require actions in some external systems. When you control the state of the server completely you can easily fake such actions

- record & replay network calls using `redirect` middleware provided with the implementation of `URLSession` that can record and replay requests (using [Vinyl](https://github.com/Velhotes/Vinyl) or any other similar implementation). This is useful to ensure that tests receive the same data between runs and aims to guard against changes on the remote server that are out of your control

## Usage

In the test create an instance of the server and start it in the `setUp` method and provide it with a middleware to handle requests. In the `tearDown` method stop the server.

```swift
override func setUp() {
    server = Server(port: 8080, handler: <#Middleware#>)
    try! server.start()
}

override func tearDown() {
    try! server.stop()
    server = nil
}
```

A middleware is a function that is based on an incoming request can modify a response. 

```swift
typealias Middleware = (
    _ request: Server.HTTPHandler.Request,
    _ response: Server.HTTPHandler.Response,
    _ next: @escaping () -> Void
) -> Void
```

When middleware function is done with response it should call the `next` closure (it's fine to call it asynchronously) that is passed to it to return control to the server.  You can write your own middleware or use those provided by SwiftNIOMock, which are `redirect`, `router` and `delay`.  Here is an example of a simple middleware that echoes back any incoming request:

```swift
func echo(
    request: Server.HTTPHandler.Request,
    response: Server.HTTPHandler.Response,
    next: @escaping () -> Void
) {
    response.statusCode = .ok
    response.body = request.body
    next()
}
```

`redirect` middleware allows you to redirect incoming requests and intercept responses. It also accepts an instance of `URLSession` (`URLSession.shared` session by default) that it will use to perform a request, which allows it to record & replay all requests. Check out `SwiftNIOMockExampleUITests.swift` to see the example of how to use SwiftNIOMock in record & replay mode powered by Vinyl.

```swift
func redirect(
    session: URLSession = URLSession.shared,
    request override: @escaping (Server.HTTPHandler.Request) -> Server.HTTPHandler.Request,
    response intercept: @escaping (Server.HTTPHandler.Response) -> Void = { _ in }
) -> Middleware
```

`router` middleware allows you to return arbitrary middleware based on a request, i.e. its method and path. If request can't be handled a fallback middleware passed as `notFound` parameter will be used.

```swift
func router(
    route: @escaping (Server.HTTPHandler.Request) -> Middleware?,
    notFound: @escaping Middleware
) -> Middleware
```

To see an example of usage SwiftNIOMock in UI tests check SwiftNIOMockExample.

### Routing

While you can use the `router` function to create a routing middleware for the mock server on the practice it is a good idea to break it down into smaller services. For that you can use `Service` type:

```swift
let fooService = Service {
    route({ $0.head.uri == "/foo" }) { (request, response, next) in
        response.sendString(.ok, value: "Foo")
        next()
    }
}
let barService = Service {
    route({ $0.head.uri == "/bar" }) { (request, response, next) in
        response.sendString(.ok, value: "Bar")
        next()
    }
}

let router = SwiftNIOMock.router(services: [
    fooService,
    barService
])
```

You can as well implement your own service by subclassing `Service`:

```swift
class HelloService: Service {
    override init() {
        super.init()
        routes {
            route({ $0.head.uri == "/helloworld" }) { (request, response, next) in
                response.sendString(.ok, value: "Hello World!")
                next()
            }
        }
    }
}
let helloService = HelloService()
let router = SwiftNIOMock.router(services: [helloService])
```

You can register routes using closure predicates as in above examples or using [URLFormat](https://github.com/ilyapuchka/URLFormat):

```swift
import URLFormat

routes {
    route(GET/.helloworld) { (request, response, next) in
        response.sendString(.ok, value: "Hello World!")
        next()
    }
}
```

You can also use a shorthand syntax to bind routes to a service KeyPath or a function with `Encodable` return value type:

```swift
class HelloService: Service {
    let users: [String]
    
    func user(byName name: String) -> String? {
        users.first { $0 == name }
    }
    
    init(users: [String]) {
        self.users = users
        super.init()
        
        routes {
            GET/.users == \HelloService.users
            GET/.users/.string == HelloService.user(byName:)
        }
    }
}
```

As routes are bound to key paths or functions you can mutate the state of your service and these changes will be reflected in the later responses.

When binding a route to a function its parameters types must match `URLFormat` type, i.e. `URLFormat<((String, String), Int)>` can be only bound to a function `(String, String, Int) -> T where T: Encodable`. Additionally you can add a `Server.HTTPHandler.Request` parameter as the last parameter of the function to access a request body data.

## Installation

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .package(url: "https://github.com/ilyapuchka/SwiftNIOMock.git", .branch("master")),
    ]
)
```

