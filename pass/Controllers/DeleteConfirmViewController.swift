//
//  DeleteConfirmViewController.swift
//  pass
//
//  Full-screen delete confirmation in Pass Picker's rust color scheme.
//

import passKit
import UIKit

class DeleteConfirmViewController: UIViewController {
    private let path: String
    private let onConfirm: () -> Void

    init(path: String, onConfirm: @escaping () -> Void) {
        self.path = path
        self.onConfirm = onConfirm
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let mode = Theme.Mode.delete
        view.backgroundColor = mode.background

        let cancelButton = makeButton(title: "Cancel".localize(), action: #selector(cancel))
        let deleteButton = makeButton(title: "Delete".localize(), action: #selector(confirm))
        let buttons = UIStackView(arrangedSubviews: [cancelButton, deleteButton])
        buttons.spacing = 24

        let caption = makeLabel("delete confirmation for...", font: Theme.mono(14, relativeTo: .footnote), color: mode.label)
        let pathLabel = makeLabel(Theme.pathTree(path), font: Theme.mono(22, relativeTo: .title2), color: mode.text)
        let question = makeLabel("Are you sure you want to delete this file?", font: Theme.mono(22, bold: true, relativeTo: .title2), color: mode.text)

        let content = UIStackView(arrangedSubviews: [caption, pathLabel, question])
        content.axis = .vertical
        content.spacing = 16
        content.setCustomSpacing(40, after: pathLabel)

        for subview in [buttons, content] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let margins = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            buttons.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            buttons.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            content.topAnchor.constraint(equalTo: buttons.bottomAnchor, constant: 32),
            content.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: -8),
        ])
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override var keyCommands: [UIKeyCommand]? {
        [
            .shortcut(UIKeyCommand.inputEscape, action: #selector(cancel), title: "Cancel"),
            .shortcut("\r", action: #selector(confirm), modifiers: .command, title: "Delete"),
        ]
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = Theme.mono(17)
        button.tintColor = Theme.Mode.delete.text
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    @objc
    private func cancel() {
        dismiss(animated: true)
    }

    @objc
    private func confirm() {
        dismiss(animated: true) { [onConfirm] in
            onConfirm()
        }
    }
}
