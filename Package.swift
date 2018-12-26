// swift-tools-version:4.0
//
//  Package.swift
//  SwiftNIOMock
//
//  Created by Ilya Puchka on 18/12/2018.
//
import PackageDescription

let package = Package(
    name: "SwiftNIOMock",
    products: [
        .library(name: "SwiftNIOMock", targets: ["SwiftNIOMock"]),
        ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.12.0"),
        ],
    targets: [
        .target(name: "SwiftNIOMock", dependencies: ["NIO", "NIOHTTP1"]),
        .testTarget(name: "SwiftNIOMockTests", dependencies: ["SwiftNIOMock"]),
    ]
)
