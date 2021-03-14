# JQ for Darwin

Build [jq](https://stedolan.github.io/jq/) for various Apple platforms. This repository hosts scripts to conveniently build jq for all of the numerous supported Apple Platforms and generate XCFrameworks for the jq library. The compressed frameworks are hosted as release assets.

## Requirements

Xcode 12 or higher is required to generate a build for all the platforms supported by the `build.sh` script. In addition to that, all the system dependencies for building `jq` are also required. You'll need to have `git`, `libtool`, `make`, `automake`, and `autoconf` installed on your Mac.

## Building

To build, make sure you have all of the required dependencies, and run the `build.sh` file.

```
./build.sh
```

The build script will compile static libraries and executables for `jq` and `oniguruma` (a dependency of `jq`) for all the [supported targets](#Supported-Targets). The generated static libraries are then used to create a single [XCFramework](https://help.apple.com/xcode/mac/11.4/#/dev6f6ac218b) for `jq` and `oniguruma`.

All the build artifacts are available under the `Products` directory once the script finishes building.

## jq

Currently this repository targets the [`jq-1.6` release tag](https://github.com/stedolan/jq/tree/jq-1.6) of the [`jq` repository on GitHub](https://github.com/stedolan/jq), which is the latest stable release.

## Generated XCFramework

The `build.sh` script generates an `XCFramework` for `jq` and the associated version of `oniguruma`. To allow interoperability with Swift, these frameworks expose `Cjq` and `Coniguruma` clang modules for the respective static library. Both the `XCFramework`s are required for using the `jq` library. To use an `XCFramework`, you can [link the framework in your Xcode project](https://help.apple.com/xcode/mac/11.4/#/dev51a648b07), or [add it as a binary target to your Swift Package manifest](https://developer.apple.com/documentation/swift_packages/distributing_binary_frameworks_as_swift_packages).

## XCFramework Releases

A zip archive of the `XCFramework`s for `jq` and the associated version of `oniguruma` are available for download as part of the release assets. The release info should contain the `SHA-1` hashes of both the zip archives. The authenticity of the builds can be verified by checking out the release tag for the particular release and running the `build.sh` script. When the script finishes running, it prints the `SHA-1` hashes of the zip archives of the newly built `XCFrameworks`. This hash must match the hash on the release page, and hash of the downloaded zip archive obtained by running:

```
shasum -a 1 path/to/framework.xcframework.zip
```

## Supported Targets

The `build.sh` file supports the following targets:

|   | Platform | Deployment Target | Architecture | Varient     |
|---|----------|-------------------|--------------|-------------|
| 📱 | iOS      | 9.0               | armv7        | iPhone/iPad |
| 📱 | iOS      | 9.0               | armv7s       | iPhone/iPad |
| 📱 | iOS      | 9.0               | arm64        | iPhone/iPad |
| 📱 | iOS      | 9.0               | i386         | Simulator   |
| 📱 | iOS      | 9.0               | x86_64       | Simulator   |
| 📱 | iOS      | 9.0               | arm64        | Simulator   |
| 📱 | iOS      | 13.0              | x86_64       | Catalyst    |
| 📱 | iOS      | 13.0              | arm64        | Catalyst    |
| 🖥 | macOS    | 10.10             | x86_64       | Mac         |
| 🖥 | macOS    | 11.0              | arm64        | Mac         |
| ⌚️ | watchOS  | 2.0               | armv7k       | Watch       |
| ⌚️ | watchOS  | 5.0               | arm64_32     | Watch       |
| ⌚️ | watchOS  | 2.0               | x86_64       | Simulator   |
| ⌚️ | watchOS  | 2.0               | arm64        | Simulator   |
| 📺 | tvOS     | 9.0               | arm64        | TV          |
| 📺 | tvOS     | 9.0               | x86_64       | Simulator   |
| 📺 | tvOS     | 9.0               | arm64        | Simulator   |

## License

The code in this repository is licensed under the MIT license. The zip archive of the `XCFramework`s for `jq` and `oniguruma` are licensed under their respective licenses. A copy of the `COPYING` license file is shipped with both the frameworks.
