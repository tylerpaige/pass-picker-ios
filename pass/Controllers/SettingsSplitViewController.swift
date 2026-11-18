//
//  SettingsSplitViewController.swift
//  pass
//
//  Created by Mingshen Sun on 6/21/17.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import UIKit

class SettingsSplitViewController: UISplitViewController, UISplitViewControllerDelegate, UINavigationControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        preferredDisplayMode = .allVisible
        for case let navigationController as UINavigationController in viewControllers {
            navigationController.delegate = self
        }
    }

    // On iOS 26 "done" buttons (Done, Clone, Save ✓) are filled with the dark tint, which hides their
    // dark text. In Settings they are plain glass buttons instead.
    func navigationController(_: UINavigationController, willShow viewController: UIViewController, animated _: Bool) {
        let items = (viewController.navigationItem.leftBarButtonItems ?? []) + (viewController.navigationItem.rightBarButtonItems ?? [])
        for item in items where item.style == .done {
            item.style = .plain
        }
    }

    func splitViewController(
        _: UISplitViewController,
        collapseSecondary _: UIViewController,
        onto _: UIViewController
    ) -> Bool {
        // Return true to prevent UIKit from applying its default behavior
        true
    }
}
