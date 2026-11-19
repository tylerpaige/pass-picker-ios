//
//  LabelTableViewCell.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import SVProgressHUD
import UIKit

struct LabelTableViewCellData {
    var title: String
    var content: String
}

class LabelTableViewCell: UITableViewCell {
    @IBOutlet var contentLabel: UILabel!
    @IBOutlet var titleLabel: UILabel!

    private enum CellType {
        case password, URL, HOTP, other
    }

    private var type = CellType.other
    private var isReveal = false

    weak var delegatePasswordTableView: PasswordDetailTableViewController?

    private var passwordDisplayButton: UIButton?

    // Pass Picker field block: a rule above, the label, then the value in a dark rounded pill.
    private let ruleView = UIView()
    private let datumView = UIView()
    private let buttonStack = UIStackView()
    private var ruleHeightConstraint: NSLayoutConstraint!
    private var titleTopConstraint: NSLayoutConstraint!
    private var datumTopConstraint: NSLayoutConstraint!
    private var datumBottomConstraint: NSLayoutConstraint!
    private var contentTopConstraint: NSLayoutConstraint!
    private var contentBottomConstraint: NSLayoutConstraint!

    /// Bulleted-list items sit close together, with the list's title only above the first.
    var listPosition = (isItem: false, continuesList: false, listContinues: false) {
        didSet {
            titleTopConstraint.constant = listPosition.continuesList ? 0 : 18
            datumTopConstraint.constant = listPosition.continuesList ? 0 : 10
            datumBottomConstraint.constant = listPosition.listContinues ? -6 : -18
            contentTopConstraint.constant = listPosition.isItem ? 7 : 12
            contentBottomConstraint.constant = listPosition.isItem ? -7 : -12
        }
    }

    var showsRuleAbove = true {
        didSet {
            ruleHeightConstraint.constant = showsRuleAbove ? 6 : 0
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = Theme.Palette.surface
        titleLabel.font = Theme.mono(14, relativeTo: .subheadline)
        titleLabel.textColor = Theme.Palette.fieldLabel
        titleLabel.adjustsFontForContentSizeCategory = true
        contentLabel.textColor = Theme.Palette.datumText
        contentLabel.adjustsFontForContentSizeCategory = true

        ruleView.backgroundColor = Theme.Palette.fieldRule
        datumView.backgroundColor = Theme.Palette.datumBackground
        let focusBackground = UIView()
        focusBackground.backgroundColor = Theme.Palette.fieldRule
        selectedBackgroundView = focusBackground
        datumView.layer.cornerRadius = 12
        buttonStack.axis = .horizontal
        buttonStack.spacing = 4

        // Replace the nib layout with the field block layout, keeping UIKit's margin guide constraints.
        let nibLabels: [UIView] = [titleLabel, contentLabel]
        NSLayoutConstraint.deactivate(contentView.constraints.filter { constraint in
            nibLabels.contains { $0 === constraint.firstItem || $0 === constraint.secondItem }
        })
        contentLabel.removeFromSuperview()
        for view in [ruleView, datumView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }
        for view in [contentLabel!, buttonStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            datumView.addSubview(view)
        }
        contentLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        contentLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        buttonStack.setContentHuggingPriority(.required, for: .horizontal)
        buttonStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        let margins = contentView.layoutMarginsGuide
        ruleHeightConstraint = ruleView.heightAnchor.constraint(equalToConstant: 6)
        titleTopConstraint = titleLabel.topAnchor.constraint(equalTo: ruleView.bottomAnchor, constant: 18)
        datumTopConstraint = datumView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10)
        datumBottomConstraint = datumView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        contentTopConstraint = contentLabel.topAnchor.constraint(equalTo: datumView.topAnchor, constant: 12)
        contentBottomConstraint = contentLabel.bottomAnchor.constraint(equalTo: datumView.bottomAnchor, constant: -12)
        NSLayoutConstraint.activate([
            ruleView.topAnchor.constraint(equalTo: contentView.topAnchor),
            ruleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            ruleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            ruleHeightConstraint,

            titleTopConstraint,
            titleLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),

            datumTopConstraint,
            datumView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            datumView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            datumBottomConstraint,

            contentTopConstraint,
            contentBottomConstraint,
            contentLabel.leadingAnchor.constraint(equalTo: datumView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: buttonStack.leadingAnchor, constant: -8),
            contentLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 21),

            buttonStack.trailingAnchor.constraint(equalTo: datumView.trailingAnchor, constant: -10),
            buttonStack.centerYAnchor.constraint(equalTo: datumView.centerYAnchor),
        ])
    }

    var cellData: LabelTableViewCellData? {
        didSet {
            guard let title = cellData?.title, let content = cellData?.content else {
                type = .other
                return
            }
            titleLabel.text = title
            if title.caseInsensitiveCompare("password") == .orderedSame {
                type = .password
                contentLabel.font = Theme.mono(17)
                if isReveal {
                    contentLabel.attributedText = Theme.attributedPassword(content, textColor: Theme.Palette.datumText, font: contentLabel.font)
                } else {
                    if content.isEmpty {
                        contentLabel.text = ""
                    } else {
                        contentLabel.text = Globals.passwordDots
                    }
                }
            } else if title.caseInsensitiveCompare("HmacBased".localize()) == .orderedSame {
                type = .HOTP
                if isReveal {
                    contentLabel.text = content
                } else {
                    contentLabel.text = Globals.oneTimePasswordDots
                }
                contentLabel.font = Theme.mono(17)
            } else if title.lowercased().contains("url") {
                type = .URL
                contentLabel.text = content
                contentLabel.font = Theme.mono(17)
            } else {
                // default
                type = .other
                contentLabel.text = content
                contentLabel.font = Theme.mono(17)
            }
            updateButtons()
        }
    }

    var isSecret: Bool {
        type == .password || type == .HOTP
    }

    // UIKit clears subview backgrounds on selection; keep the rule and pill visible when a field is keyboard-focused.
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        restoreFieldColors()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        restoreFieldColors()
    }

    private func restoreFieldColors() {
        ruleView.backgroundColor = Theme.Palette.fieldRule
        datumView.backgroundColor = Theme.Palette.datumBackground
    }

    /// The long-press menu for this field.
    var menuActions: [UIAction] {
        var actions = [
            UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                SecurePasteboard.shared.copy(textToCopy: self?.cellData?.content)
            },
        ]
        if isSecret {
            actions.append(isReveal
                ? UIAction(title: "Conceal".localize(), image: UIImage(systemName: "eye.slash")) { [weak self] _ in self?.concealPassword(nil) }
                : UIAction(title: "Reveal".localize(), image: UIImage(systemName: "eye")) { [weak self] _ in self?.revealPassword(nil) })
        }
        if type == .HOTP {
            actions.append(UIAction(title: "NextPassword".localize(), image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
                self?.getNextHOTP(nil)
            })
        }
        if type == .URL {
            actions.append(UIAction(title: "CopyAndOpen".localize(), image: UIImage(systemName: "safari")) { [weak self] _ in
                self?.openLink(nil)
            })
        }
        return actions
    }

    @objc
    func revealPassword(_: Any?) {
        let plainPassword = cellData?.content ?? ""
        if type == .password {
            contentLabel.attributedText = Theme.attributedPassword(plainPassword, textColor: Theme.Palette.datumText, font: contentLabel.font)
        } else {
            contentLabel.text = plainPassword
        }
        isReveal = true
        passwordDisplayButton?.setTitle("◉", for: .normal)
    }

    @objc
    func concealPassword(_: Any?) {
        if type == .password {
            if cellData?.content.isEmpty == false {
                contentLabel.text = Globals.passwordDots
                contentLabel.textColor = Theme.Palette.datumText
            } else {
                contentLabel.text = ""
            }
        } else {
            contentLabel.text = Globals.oneTimePasswordDots
        }
        isReveal = false
        passwordDisplayButton?.setTitle("◎", for: .normal)
    }

    @objc
    func reversePasswordDisplay(_ sender: Any?) {
        if isReveal {
            // conceal
            concealPassword(sender)
        } else {
            // reveal
            revealPassword(sender)
        }
    }

    @objc
    func openLink(_: Any?) {
        // if isURLCell, passwordTableView should not be nil
        delegatePasswordTableView!.openLink(to: cellData?.content)
    }

    @objc
    func getNextHOTP(_: Any?) {
        // if isHOTPCell, passwordTableView should not be nil
        delegatePasswordTableView!.getNextHOTP()
    }

    private func makeGlyphButton(_ glyph: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(glyph, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20)
        button.tintColor = Theme.Palette.datumText.withAlphaComponent(0.7)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return button
    }

    private func updateButtons() {
        buttonStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        passwordDisplayButton = nil

        switch type {
        case .password:
            if let content = cellData?.content, !content.isEmpty {
                passwordDisplayButton = makeGlyphButton(isReveal ? "◉" : "◎", action: #selector(reversePasswordDisplay))
            }
        case .HOTP:
            buttonStack.addArrangedSubview(makeGlyphButton("↻", action: #selector(getNextHOTP)))
            passwordDisplayButton = makeGlyphButton(isReveal ? "◉" : "◎", action: #selector(reversePasswordDisplay))
        default:
            break
        }
        if let passwordDisplayButton {
            buttonStack.addArrangedSubview(passwordDisplayButton)
        }
    }
}
