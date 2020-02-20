import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if os(iOS) || os(tvOS)
private typealias ViewController = UIViewController
#elseif os(macOS)
private typealias ViewController = NSViewController
#endif

// TODO: Swizzle WatchKit lifecycle notification events
// See https://developer.apple.com/documentation/watchkit/wkextensiondelegate

internal struct Swizzling {
    static func exchange(selector: Selector, for swizzledSelector: Selector, of cls: AnyClass) {
        let originalMethod = class_getInstanceMethod(cls, selector)
        let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector)
        method_exchangeImplementations(originalMethod!, swizzledMethod!)
    }

    #if os(iOS) || os(tvOS) || os(macOS)
    private static var isAppliedToViewControllers = false

    static func applyToViewControllers() {
        guard !isAppliedToViewControllers else {
            return
        }

        defer {
            isAppliedToViewControllers = true
        }

        let cls = ViewController.self

        var swizzleMap: [Selector: Selector] = [
            #selector(cls.viewDidLoad): #selector(cls.bintrail_viewDidLoad)
        ]

        #if os(iOS) || os(tvOS)
        swizzleMap[#selector(cls.viewWillAppear(_:))] = #selector(cls.bintrail_viewWillAppear(_:))
        swizzleMap[#selector(cls.viewDidAppear(_:))] = #selector(cls.bintrail_viewDidAppear(_:))
        swizzleMap[#selector(cls.viewWillDisappear(_:))] = #selector(cls.bintrail_viewWillDisappear(_:))
        swizzleMap[#selector(cls.viewDidDisappear(_:))] = #selector(cls.bintrail_viewDidDisappear(_:))
        #elseif os(macOS)
        swizzleMap[#selector(cls.viewWillAppear)] = #selector(cls.bintrail_viewWillAppear)
        swizzleMap[#selector(cls.viewDidAppear)] = #selector(cls.bintrail_viewDidAppear)
        swizzleMap[#selector(cls.viewWillDisappear)] = #selector(cls.bintrail_viewWillDisappear)
        swizzleMap[#selector(cls.viewDidDisappear)] = #selector(cls.bintrail_viewDidDisappear)
        #endif

        for (originalSelector, swizzledSelector) in swizzleMap {
            exchange(selector: originalSelector, for: swizzledSelector, of: cls)
        }
    }
    #endif
}

#if os(iOS) || os(tvOS) || os(macOS)
extension ViewController {
    private var bintrailProjectedName: String {
           String(reflecting: type(of: self))
       }

       private func registerBintrailEvent(named name: String) {
           bt_event_register(Event.Name(value: name, namespace: .viewControllerLifecycle)) { event in
               event.add(attribute: bintrailProjectedName, for: "viewControllerName")
           }
       }
#if os(iOS) || os(tvOS)
    @objc
    func bintrail_viewDidLoad() {
        self.bintrail_viewDidLoad()
        registerBintrailEvent(named: "viewDidLoad")
    }

    @objc
    func bintrail_viewWillAppear(_ animated: Bool) {
        self.bintrail_viewWillAppear(animated)
        registerBintrailEvent(named: "viewWillAppear")
    }

    @objc
    func bintrail_viewDidAppear(_ animated: Bool) {
        self.bintrail_viewDidAppear(animated)
        registerBintrailEvent(named: "viewDidAppear")
    }

    @objc
    func bintrail_viewWillDisappear(_ animated: Bool) {
        self.bintrail_viewWillDisappear(animated)
        registerBintrailEvent(named: "viewWillDisappear")
    }

    @objc
    func bintrail_viewDidDisappear(_ animated: Bool) {
        self.bintrail_viewDidDisappear(animated)
        registerBintrailEvent(named: "viewDidDisappear")
    }

#elseif os(macOS)
    @objc
    func bintrail_viewDidLoad() {
        self.bintrail_viewDidLoad()
        registerBintrailEvent(named: "viewDidLoad")
    }

    @objc
    func bintrail_viewWillAppear() {
        self.bintrail_viewWillAppear()
        registerBintrailEvent(named: "viewWillAppear")
    }

    @objc
    func bintrail_viewDidAppear() {
        self.bintrail_viewDidAppear()
        registerBintrailEvent(named: "viewDidAppear")
    }

    @objc
    func bintrail_viewWillDisappear() {
        self.bintrail_viewWillDisappear()
        registerBintrailEvent(named: "viewWillDisappear")
    }

    @objc
    func bintrail_viewDidDisappear() {
        self.bintrail_viewDidDisappear()
        registerBintrailEvent(named: "viewDidDisappear")
    }
#endif
}
#endif
