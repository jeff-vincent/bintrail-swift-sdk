//
//  ViewController.swift
//  Example
//
//  Created by David Ask on 2019-10-03.
//  Copyright © 2019 Bintrail AB. All rights reserved.
//

import Bintrail
import UIKit

extension EventType {
    public static let buttonTapped = EventType(name: "buttonTapped for this is a very long event name. That's ok though, we'll allow it, wont' we? Yes we will.", outcome: .positive(.low))
    public static let presentViewController = EventType(name: "presentViewController", outcome: .neutral)
}

class ViewController: UIViewController {

    private var tapCounter: Int = 1

    @IBAction
    func buttonAction(sender: UIButton) {
        bt_log("Button tapped", type: .debug)
        bt_event_register(.buttonTapped) { event in
            event.add(metric: tapCounter, for: "tapCount")
            event.add(attribute: Date(), for: "date")
            event.add(attribute: Int.max, for: "intMax")
            event.add(attribute: Int.min, for: "intMin")
            event.add(attribute: Int.random(in: Int.min..<Int.max), for: "intRnd")
        }

        let detailController = UINavigationController(
            rootViewController: DetailViewController(nibName: nil, bundle: nil)
        )

        bt_log("Presenting detail controller", detailController, type: .info)



        let event = bt_event_start(.presentViewController)
        event.add(attribute: detailController, for: "viewController")
        present(detailController, animated: true) {
            bt_event_finish(event)
        }

        tapCounter += 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        bt_log("Received memory warning", type: .error)
    }

}

