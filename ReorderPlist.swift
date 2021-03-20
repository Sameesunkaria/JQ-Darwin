#!/usr/bin/env swift
import Foundation

func sort<T, E, C: Comparable>(
    _ arrayPath: WritableKeyPath<T, [E]>,
    by sortPath: KeyPath<E, C>,
    on value: T
) -> T {
    var mutableValue = value
    mutableValue[keyPath: arrayPath]
        .sort { $0[keyPath: sortPath] < $1[keyPath: sortPath] }
    return mutableValue
}

struct Info: Codable {
    var availableLibraries: [Library]
    var bundlePackageType: String
    var xcFrameworkFormatVersion: String

    enum CodingKeys: String, CodingKey {
        case availableLibraries = "AvailableLibraries"
        case bundlePackageType = "CFBundlePackageType"
        case xcFrameworkFormatVersion = "XCFrameworkFormatVersion"
    }

    struct Library: Codable {
        var headersPath: String
        var libraryIdentifier: String
        var libraryPath: String
        var supportedArchitectures: [String]
        var supportedPlatform: String
        var supportedPlatformVariant: String?

        enum CodingKeys: String, CodingKey {
            case headersPath = "HeadersPath"
            case libraryIdentifier = "LibraryIdentifier"
            case libraryPath = "LibraryPath"
            case supportedArchitectures = "SupportedArchitectures"
            case supportedPlatform = "SupportedPlatform"
            case supportedPlatformVariant = "SupportedPlatformVariant"
        }
    }
}

let decoder = PropertyListDecoder()
let encoder = PropertyListEncoder()
encoder.outputFormat = .xml

try CommandLine.arguments
    .dropFirst()
    .compactMap(URL.init(fileURLWithPath:))
    .map { (try Data.init(contentsOf: $0), $0) }
    .map { (try decoder.decode(Info.self, from: $0), $1) }
    .map { (sort(\.availableLibraries, by: \.libraryIdentifier, on: $0), $1) }
    .map { (try encoder.encode($0), $1) }
    .forEach { try $0.write(to: $1) }
