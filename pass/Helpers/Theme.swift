//
//  Theme.swift
//  pass
//
//  Visual language ported from Pass Picker (https://github.com/tylerpaige/pass-picker):
//  iA Writer Mono everywhere, olive chrome, a zebra-striped folder tree,
//  a tan detail surface with dark "datum" pills, and full-bleed color modes
//  for editing (blue), creating (green) and deleting (rust).
//

import UIKit

enum Theme {
    enum Palette {
        // App chrome
        static let chrome = UIColor(hex: 0x3B442B)
        static let chromeAlt = UIColor(hex: 0x524B3B)
        static let chromeText = UIColor(hex: 0xC8C4B6)

        // Folder tree
        static let treeA = UIColor(hex: 0xA7C28B)
        static let treeB = UIColor(hex: 0x96BA86)
        static let treeFocused = UIColor(hex: 0x87AB4E)
        static let treeSelected = UIColor(hex: 0xA6A636)
        static let hierarchy = UIColor(hex: 0xA6A636)
        static let sidebarText = UIColor(hex: 0x2F3A28)
        static let sidebarMuted = UIColor(hex: 0x5A6B4A)
        static let sidebarControls = UIColor(hex: 0xC5D4B0)

        // Detail surface
        static let surface = UIColor(hex: 0xAFA58C)
        static let surfaceRaised = UIColor(hex: 0xBEB5A0)
        static let surfaceText = UIColor(hex: 0x322E25)
        static let surfaceMuted = UIColor(hex: 0x524B3B)
        static let entryTitle = UIColor.black
        static let fieldLabel = UIColor.black
        static let datumBackground = UIColor(hex: 0x3E3D23)
        static let datumText = UIColor(hex: 0xBEB5A0)
        static let fieldRule = UIColor(hex: 0xB3B0AB)

        // Accents
        static let accent = UIColor(hex: 0x8FBF4A)
        static let amber = UIColor(hex: 0xA6A636)
        static let danger = UIColor(hex: 0xC44B4B)
    }

    /// Full-bleed color schemes used by the editor and delete confirmation screens.
    struct Mode {
        let background: UIColor
        let input: UIColor
        let label: UIColor
        let text: UIColor
        let rule: UIColor

        static let edit = Self(
            background: UIColor(hex: 0x2C3E6B),
            input: UIColor(hex: 0x233274),
            label: UIColor(hex: 0x9AADC8),
            text: UIColor(hex: 0xE8EEF8),
            rule: UIColor(hex: 0x3A5080)
        )

        static let new = Self(
            background: UIColor(hex: 0x425A33),
            input: UIColor(hex: 0x254C28),
            label: UIColor(hex: 0xB8C9AE),
            text: UIColor(hex: 0xC9E0C6),
            rule: UIColor(hex: 0x37654C)
        )

        static let delete = Self(
            background: UIColor(hex: 0x7A4434),
            input: UIColor(hex: 0x5E3326),
            label: UIColor(hex: 0xC4A89C),
            text: UIColor(hex: 0xE8D8D0),
            rule: UIColor(hex: 0x8E5544)
        )
    }

    static let regularFontName = "iAWriterMonoS-Regular"
    static let boldFontName = "iAWriterMonoS-Bold"

    /// iA Writer Mono at `size`, scaled for Dynamic Type relative to `style`.
    static func mono(_ size: CGFloat, bold: Bool = false, relativeTo style: UIFont.TextStyle = .body) -> UIFont {
        let base = UIFont(name: bold ? boldFontName : regularFontName, size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }

    /// Fixed-size variant for places that must not grow with Dynamic Type (bars, tabs).
    static func fixedMono(_ size: CGFloat, bold: Bool = false) -> UIFont {
        UIFont(name: bold ? boldFontName : regularFontName, size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    /// ASCII directory tree for an entry path, e.g. "finance\n   └ tax-portal".
    static func pathTree(_ path: String, suffix: String = "") -> String {
        let parts = path.split(separator: "/").map(String.init)
        guard !parts.isEmpty else {
            return "(root)"
        }
        let lines = parts.enumerated().map { index, part in
            index == 0 ? part : String(repeating: "   ", count: index - 1) + " └ " + part
        }
        return lines.joined(separator: "\n") + suffix
    }

    /// Password with digits and symbols tinted, readable on a dark field.
    static func attributedPassword(_ plainPassword: String, textColor: UIColor, font: UIFont? = nil) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: plainPassword)
        for (index, scalar) in plainPassword.unicodeScalars.enumerated() {
            var color = textColor
            if CharacterSet.decimalDigits.contains(scalar) {
                color = Palette.amber
            } else if !CharacterSet.letters.contains(scalar) {
                color = Palette.accent
            }
            attributed.addAttribute(.foregroundColor, value: color, range: NSRange(location: index, length: 1))
        }
        if let font {
            attributed.addAttribute(.font, value: font, range: NSRange(location: 0, length: attributed.length))
        }
        return attributed
    }

    /// System text for places where the mono face reads badly: Settings, and the editor's buttons.
    static let sansButtonFont = UIFont.systemFont(ofSize: 17, weight: .semibold)

    static func navigationBarAppearance(
        background: UIColor,
        text: UIColor,
        monospacedTitles: Bool = true,
        buttonFont: UIFont = fixedMono(16)
    ) -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = .clear
        let titleFont = monospacedTitles ? fixedMono(17) : .systemFont(ofSize: 17, weight: .semibold)
        let largeTitleFont = monospacedTitles ? fixedMono(30) : .systemFont(ofSize: 34, weight: .bold)
        appearance.titleTextAttributes = [.foregroundColor: text, .font: titleFont]
        appearance.largeTitleTextAttributes = [.foregroundColor: text, .font: largeTitleFont]

        let button = UIBarButtonItemAppearance()
        button.normal.titleTextAttributes = [.foregroundColor: text, .font: buttonFont]
        button.disabled.titleTextAttributes = [.foregroundColor: text.withAlphaComponent(0.35), .font: buttonFont]
        appearance.buttonAppearance = button
        appearance.doneButtonAppearance = button
        appearance.backButtonAppearance = button
        return appearance
    }

    /// Gives a view controller pushed onto the shared navigation stack its own bar colors.
    static func apply(_ mode: Mode, to navigationItem: UINavigationItem) {
        let appearance = navigationBarAppearance(background: mode.background, text: mode.text, buttonFont: sansButtonFont)
        navigationItem.standardAppearance = appearance
        navigationItem.compactAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
