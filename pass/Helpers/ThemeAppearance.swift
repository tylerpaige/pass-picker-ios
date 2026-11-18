//
//  ThemeAppearance.swift
//  pass
//
//  App-wide UIKit appearance for the Pass Picker theme. App target only;
//  the extensions share Theme.swift but not this file.
//

import SVProgressHUD
import UIKit

extension Theme {
    static func applyAppearance(to window: UIWindow?) {
        // The palette is fixed, so pin the light trait to keep system text dark on the light surfaces.
        window?.overrideUserInterfaceStyle = .light
        window?.tintColor = Palette.datumBackground

        let navigationBar = navigationBarAppearance(background: Palette.chrome, text: Palette.chromeText)
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().tintColor = Palette.chromeText

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = Palette.chrome
        tabBar.shadowColor = .clear
        for item in [tabBar.stackedLayoutAppearance, tabBar.inlineLayoutAppearance, tabBar.compactInlineLayoutAppearance] {
            item.normal.iconColor = Palette.chromeText.withAlphaComponent(0.6)
            item.normal.titleTextAttributes = [.foregroundColor: Palette.chromeText.withAlphaComponent(0.6), .font: fixedMono(10)]
            item.selected.iconColor = Palette.accent
            item.selected.titleTextAttributes = [.foregroundColor: Palette.accent, .font: fixedMono(10)]
            item.normal.badgeBackgroundColor = Palette.amber
            item.normal.badgeTextAttributes = [.foregroundColor: Palette.sidebarText, .font: fixedMono(11)]
        }
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        UISegmentedControl.appearance().selectedSegmentTintColor = Palette.accent
        UISegmentedControl.appearance().setTitleTextAttributes([.font: fixedMono(13), .foregroundColor: Palette.surfaceText], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: fixedMono(13), .foregroundColor: Palette.sidebarText], for: .selected)
        UISegmentedControl.appearance(whenContainedInInstancesOf: [UISearchBar.self])
            .setTitleTextAttributes([.font: fixedMono(13), .foregroundColor: Palette.chromeText], for: .normal)

        UISwitch.appearance().onTintColor = Palette.accent
        UISlider.appearance().minimumTrackTintColor = Palette.accent
        UIRefreshControl.appearance().tintColor = Palette.chromeText

        // Settings screens: a monochrome tan sheet in the system font.
        let settings = [SettingsSplitViewController.self]
        let settingsBar = navigationBarAppearance(background: Palette.surface, text: Palette.surfaceText, monospacedTitles: false, buttonFont: .systemFont(ofSize: 17))
        let settingsNavigationBar = UINavigationBar.appearance(whenContainedInInstancesOf: settings)
        settingsNavigationBar.standardAppearance = settingsBar
        settingsNavigationBar.compactAppearance = settingsBar
        if #available(iOS 26.0, *) {
            // Large titles now scroll with the table, under the bar: an opaque bar hides them.
            let edgeBar = navigationBarAppearance(background: Palette.surface, text: Palette.surfaceText, monospacedTitles: false, buttonFont: .systemFont(ofSize: 17))
            edgeBar.configureWithTransparentBackground()
            edgeBar.titleTextAttributes = settingsBar.titleTextAttributes
            edgeBar.largeTitleTextAttributes = settingsBar.largeTitleTextAttributes
            edgeBar.buttonAppearance = settingsBar.buttonAppearance
            edgeBar.doneButtonAppearance = settingsBar.doneButtonAppearance
            edgeBar.backButtonAppearance = settingsBar.backButtonAppearance
            settingsNavigationBar.scrollEdgeAppearance = edgeBar
            settingsNavigationBar.standardAppearance = edgeBar
        } else {
            settingsNavigationBar.scrollEdgeAppearance = settingsBar
        }
        settingsNavigationBar.tintColor = Palette.datumBackground
        UISwitch.appearance(whenContainedInInstancesOf: settings).onTintColor = Palette.datumBackground
        UISegmentedControl.appearance(whenContainedInInstancesOf: settings).selectedSegmentTintColor = Palette.datumBackground
        UISegmentedControl.appearance(whenContainedInInstancesOf: settings)
            .setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 13), .foregroundColor: Palette.datumText], for: .selected)
        UISegmentedControl.appearance(whenContainedInInstancesOf: settings)
            .setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 13), .foregroundColor: Palette.surfaceText], for: .normal)
        UITableView.appearance(whenContainedInInstancesOf: settings).backgroundColor = Palette.surface
        UITableView.appearance(whenContainedInInstancesOf: settings).separatorColor = Palette.fieldRule
        UITableViewCell.appearance(whenContainedInInstancesOf: settings).backgroundColor = Palette.surfaceRaised
        UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self, SettingsSplitViewController.self]).font = .preferredFont(forTextStyle: .body)
        UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self, SettingsSplitViewController.self]).font = .preferredFont(forTextStyle: .footnote)
        UITextField.appearance(whenContainedInInstancesOf: [UITableViewCell.self, SettingsSplitViewController.self]).font = .preferredFont(forTextStyle: .body)

        SVProgressHUD.setFont(fixedMono(15))
    }
}
