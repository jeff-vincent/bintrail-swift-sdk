//
//  ViewController.swift
//  Example
//
//  Created by David Ask on 2019-10-03.
//  Copyright © 2019 Bintrail AB. All rights reserved.
//

import Bintrail
import UIKit

class ViewController: UIViewController {

    private var tapCounter: Int = 1

    @IBAction
    func buttonAction(sender: UIButton) {
        bt_log("Button tapped", type: .debug)

        [0][1]

        tapCounter += 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


}

