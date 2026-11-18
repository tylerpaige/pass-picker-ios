//
//  SceneDelegate.swift
//  pass
//
//  Window setup for the scene lifecycle, which current iOS requires to launch the app.
//  This was previously done by AppDelegate.
//

import passKit
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    enum ViewTag: Int {
        case blur = 100, appicon
    }

    // Set from Main.storyboard (UISceneStoryboardFile) before the scene connects.
    var window: UIWindow?

    func scene(_: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        Theme.applyAppearance(to: window)
        PasswordBrowserViewController.install(in: window)
        // The app no longer has a passcode lock; drop one set before, so AutoFill isn't locked by it either.
        PasscodeLock.shared.delete()
        if connectionOptions.shortcutItem?.type == Globals.bundleIdentifier + ".search" {
            perform(#selector(postSearchNotification), with: nil, afterDelay: 0.4)
        }
    }

    @objc
    func postSearchNotification() {
        NotificationCenter.default.post(name: .passwordSearch, object: nil)
    }

    func windowScene(_: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard shortcutItem.type == Globals.bundleIdentifier + ".search" else {
            completionHandler(false)
            return
        }
        window?.rootViewController?.dismiss(animated: false)
        (window?.rootViewController as? UINavigationController)?.popToRootViewController(animated: false)
        perform(#selector(postSearchNotification), with: nil, afterDelay: 0.4)
        completionHandler(true)
    }

    func sceneWillResignActive(_: UIScene) {
        guard let window else {
            return
        }
        // Display a blur effect view
        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blurEffectView.frame = window.bounds
        blurEffectView.tag = ViewTag.blur.rawValue
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(blurEffectView)

        // Display the Pass icon in the middle of the screen
        let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? NSDictionary
        let primaryIconsDictionary = iconsDictionary?["CFBundlePrimaryIcon"] as? NSDictionary
        if let iconName = (primaryIconsDictionary?["CFBundleIconFiles"] as? NSArray)?.lastObject as? String, let appIcon = UIImage(named: iconName) {
            let appIconView = UIImageView(image: appIcon)
            appIconView.layer.cornerRadius = appIcon.size.height / 5
            appIconView.layer.masksToBounds = true
            appIconView.center = window.center
            appIconView.tag = ViewTag.appicon.rawValue
            window.addSubview(appIconView)
        }

        PersistenceController.shared.save()
    }

    func sceneDidBecomeActive(_: UIScene) {
        window?.viewWithTag(ViewTag.appicon.rawValue)?.removeFromSuperview()
        window?.viewWithTag(ViewTag.blur.rawValue)?.removeFromSuperview()
    }

    func sceneDidEnterBackground(_: UIScene) {
        PersistenceController.shared.save()
    }
}
