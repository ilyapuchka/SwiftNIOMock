// swift-tools-version:4.0
//
//  Package.swift
//  SwiftNIOMock
//
//  Created by Ilya Puchka on 18/12/2018.
//
import PackageDescription

let package = Package(
    name: "SwiftNIOMockVinyl",
    products: [
        .library(name: "SwiftNIOMockVinyl", targets: ["SwiftNIOMockVinyl"]),
        ],
    dependencies: [
        .package(url: "https://github.com/Velhotes/Vinyl", .branch("master")),
        ],
    targets: [
        .target(name: "SwiftNIOMockVinyl", dependencies: ["Vinyl"])
    ]
)
