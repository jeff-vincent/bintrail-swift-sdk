//
//  DetailViewController.swift
//  Example
//
//  Created by David Ask on 2019-10-30.
//  Copyright © 2019 Bintrail AB. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {

    private lazy var closeItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close))

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = closeItem
        view.backgroundColor = .white
    }

    @objc
    private func close() {
        dismiss(animated: true)
    }

}
