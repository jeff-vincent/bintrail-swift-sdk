import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if !os(Linux)
internal struct Swizzling {
    static func exchange(selector: Selector, for swizzledSelector: Selector, of cls: AnyClass) {
        let originalMethod = class_getInstanceMethod(cls, selector)
        let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector)
        method_exchangeImplementations(originalMethod!, swizzledMethod!)
    }

    #if os(iOS) || os(tvOS)
    private static var isAppliedToViewControllers = false

    static func applyToViewControllers() {
        guard !isAppliedToViewControllers else {
            return
        }

        defer {
            isAppliedToViewControllers = true
        }

        let cls = UIViewController.self

        let swizzleMap: [Selector: Selector] = [
            #selector(cls.viewDidLoad): #selector(cls.bintrail_viewDidLoad),
            #selector(cls.viewWillAppear(_:)): #selector(cls.bintrail_viewWillAppear(_:)),
            #selector(cls.viewDidAppear(_:)): #selector(cls.bintrail_viewDidAppear(_:)),
            #selector(cls.viewWillDisappear(_:)): #selector(cls.bintrail_viewWillDisappear(_:)),
            #selector(cls.viewDidDisappear(_:)): #selector(cls.bintrail_viewDidDisappear(_:))
        ]

        for (originalSelector, swizzledSelector) in swizzleMap {
            exchange(selector: originalSelector, for: swizzledSelector, of: cls)
        }
    }
    #endif
}
#endif

#if os(iOS) || os(tvOS)
extension UIViewController {
    private var bintrailProjectedName: String {
        String(reflecting: type(of: self))
    }

    private func registerBintrailEvent(named name: String) {
        bt_event_register(Event.Name(value: name, namespace: .viewControllerLifecycle)) { event in
            event.add(attribute: bintrailProjectedName, for: "viewControllerName")
        }
    }

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
}
#endif
