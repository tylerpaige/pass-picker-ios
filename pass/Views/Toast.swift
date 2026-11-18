//
//  Toast.swift
//  pass
//
//  A small lime-green notice near the top of the screen, e.g. "copied".
//

import UIKit

enum Toast {
    private static let tag = 0x7057

    static func show(_ message: String, duration: TimeInterval = 1.2) {
        DispatchQueue.main.async {
            guard let window = keyWindow else {
                return
            }
            window.viewWithTag(tag)?.removeFromSuperview()

            let label = PaddedLabel()
            label.tag = tag
            label.text = message
            label.font = Theme.mono(13, relativeTo: .footnote)
            label.textColor = Theme.Palette.sidebarText
            label.backgroundColor = Theme.Palette.accent
            label.layer.cornerRadius = 6
            label.layer.masksToBounds = true
            label.isUserInteractionEnabled = false
            label.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                label.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 8),
            ])

            label.alpha = 0
            label.transform = CGAffineTransform(translationX: 0, y: -8)
            UIView.animate(withDuration: 0.15) {
                label.alpha = 1
                label.transform = .identity
            }
            UIView.animate(withDuration: 0.25, delay: duration, options: []) {
                label.alpha = 0
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

private class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
