# Bintrail Swift SDK
[Bintrail](https://www.bintrail.com) allows you to remotely gather, search and analyze your application logs in the cloud.

## Requirements

Bintrail requires Swift 4.0 or later, Objective-C, compatible with following platform versions or later:

* iOS 8.0
* macOS 10.0
* watchOS 3.0
* tvOS 9.0



## Installation

Bintrail Swift SDK is available through:

* [Swift Package Manager](https://github.com/apple/swift-package-manager)
* [Carthage](https://github.com/Carthage/Carthage)



### Using Carthage

Install Carthage using `brew install carthage`

```
github "bintrail/bintrail-swift-sdk"
```

### Using Swift Package Manager

In Xcode, go to File > Swift Packages > Add package dependency. Select your project, and enter `https://github.com/bintrail/bintrail/swift-sdk` as repository URL.



## Integrating Bintrail

### For iOS, tvOS and macOS

In the `AppDelegate` file import Bintrail.

```swift
import Bintrail
```

In `application(_:didFinishLaunchingWithOptions:)` add the following snippet, replacing the place holders with your *Bintrail ingest key pair*.

```swift
do {
    try Bintrail.shared.configure(
        keyId: <# Ingest key pair id #>,
        secret: <# Ingest key pair secret #>,
        options: [
            .includeApplicationNotifications,
            .includeViewControllerLifecycle
        ]
    )   
} catch {
    print("Failed to configure Bintrail", error)
}

bt_log("Application launched successfully!", .info)
```



## License

Bintrail Swift SDK is available under the MIT license. See the LICENSE file for more info.