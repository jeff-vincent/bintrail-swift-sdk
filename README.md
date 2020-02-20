![Build Status](https://github.com/bintrail/bintrail-swift-sdk/workflows/Test/badge.svg)

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

In Xcode, go to File > Swift Packages > Add package dependency. Select your project, and enter `https://github.com/bintrail/bintrail/bintrail-swift-sdk` as repository URL.



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
            keyId: "<# Key id #>",
            secret: "<# Key secret #>",
            monitoring: [
                .applicationNotifications,
                .viewControllerLifecycle
            ]
        )
} catch {
    print("Failed to configure Bintrail", error)
}
```



## Logging
Logs should represent system events to provide an audit trail that can be used to understand the activity of the system and to diagnose problems.
Nominally logs are used to represent events in the program and its execution itself, rather than arbitrary events associated
with e.g. the usage of the application.

Bintrail supports logs, with the following properties:

- **Message**, the main payload of a log entry
- **Level**, the severity of the log entry
- **File**, the location of the file in which the log entry originated
- **Line**, the line location in the file of which the log entry originated
- **Column**, the column location in the line of the file of which the log entry originated

Use `bt_log` to queue log messages for ingestion in Bintrail. When a debugger is attached, messages logged using `bt_log` are printed to standard out.

You can specify a log level using `bt_log`

```swift
bt_log(.trace, "Hello world!")
```



Omitting the level defaults to `info`.



## Events

Events are used to communicate occurrences derived from the execution of the program. Often, an event is tied to user activity.

An event consists of a key that should be unique, including optional attributes and metrics. Attribute values are limited to string-value types whereas metrics are limited to single-precision float type values.



You can register simple events by simply specifying a key:

```swift
bt_event_register('My custom event')
```



To better keep tabs of your custom events you can define a set of events like so:

```swift
extension Event.Name {
    public static let myCustomEvent = Event.Name(value: "My custom event")
    public static let myOtherCustomEvent = Event.Name(value: "My other custom event")
}

bt_event_register(.myCustomEvent)
```

Events may pick up attributes, which are limited to string values:

```swift
bt_event_register(.myCustomEvent) { event in
    event.add(value: "My attribute value", forAttribute: "My attribute")
}
```

Metrics are limited to single precision floating point values:

```swift
event.add(value: 5, forMetric: "rating")
```

You can also specify defined metrics, similar to how you can define event names:

```swift
extension Event.Metric {
    public static let myNamedMetric = Event.Metric(rawValue: "MyNamedMetric")
}
bt_event_register(.myNamedMetric)
```

For asynchronous control flows you can define an event and register it later:

```swift
let event = Event(name: .myCustomEvent)

DispatchQueue.global().async {
    event.add(value: Date(), forAttribute: "date")
}

bt_event_register(event)
```



## License

Bintrail Swift SDK is available under the MIT license. See the LICENSE file for more info.