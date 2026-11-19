//
//  PasswordEditorTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 12/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import OneTimePassword
import passKit
import SafariServices
import UIKit

enum PasswordEditorCellType: Equatable {
    case nameCell
    case currentPasswordCell
    case fillPasswordCell
    case generatorToggleCell
    case generatorSettingsCell
    case additionsCell
    case deletePasswordCell
    case scanQRCodeCell
}

enum PasswordEditorCellKey {
    case type, title, content
}

protocol PasswordSettingSliderTableViewCellDelegate: AnyObject {
    func generateAndCopyPassword()
}

class PasswordEditorTableViewController: UITableViewController {
    var tableData = [[[PasswordEditorCellKey: Any]]]()
    var password: Password?

    /// Color scheme for the whole screen; editing is blue, creating is green.
    var mode: Theme.Mode {
        .new
    }

    private var navigationItemTitle: String?

    // As in Pass Picker: the current password read-only, then a new one that may stay blank to keep it.
    private var sectionHeaderTitles = [String?]()
    private let nameSection = 0
    private var passwordSection: Int {
        password == nil ? 1 : 2
    }

    private var additionsSection: Int {
        passwordSection + 1
    }

    private var generatorOpen = false
    private var generatorLength = Defaults.passwordGeneratorLength
    private var generatorSpecialCharacters = Defaults.passwordGeneratorSpecialCharacters

    var nameCell: TextFieldTableViewCell?
    var fillPasswordCell: FillPasswordTableViewCell?
    var additionsCell: TextViewTableViewCell?
    private var deletePasswordCell: UITableViewCell?
    private var scanQRCodeCell: UITableViewCell?
    private lazy var lengthLabel = UILabel()

    // Pass Picker's path suggestions: every folder in the store, offered under the name field as you type.
    private lazy var folderSuggestions: [String] = {
        var folders = Set<String>()
        for entity in PasswordStore.shared.fetchPasswordEntityCoreData(withDir: false) {
            let parts = entity.nameWithDir.split(separator: "/")
            for index in parts.indices.dropLast() {
                folders.insert(parts[...index].joined(separator: "/") + "/")
            }
        }
        return folders.sorted { $0.localizedCompare($1) == .orderedAscending }
    }()

    private let suggestionsView = UIStackView()
    private var shownSuggestions = [String]()
    private var suggestionIndex = -1

    var plainText: String {
        // A blank new password keeps the current one.
        var plainText = fillPasswordCell?.getContent() ?? ""
        if plainText.isEmpty, let currentPassword = password?.password {
            plainText = currentPassword
        }
        if let additionsString = additionsCell?.getContent(), !additionsString.isEmpty {
            plainText.append("\n")
            plainText.append(additionsString)
        }
        if !plainText.trimmingCharacters(in: .whitespaces).hasSuffix("\n") {
            plainText.append("\n")
        }
        return plainText
    }

    override func loadView() {
        super.loadView()

        deletePasswordCell = makeButtonCell(
            title: "DeletePassword".localize(),
            textColor: Theme.Mode.delete.text,
            fill: Theme.Mode.delete.background,
            action: #selector(deletePassword)
        )
        scanQRCodeCell = makeButtonCell(title: "AddOneTimePassword".localize(), textColor: mode.text, fill: nil, action: #selector(addOneTimePassword))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if navigationItemTitle != nil {
            navigationItem.title = navigationItemTitle
        }
        Theme.apply(mode, to: navigationItem)
        navigationController?.navigationBar.tintColor = mode.text
        // The editor's colors are all dark, so its glass buttons (Save, Close, the form's buttons) are too.
        overrideUserInterfaceStyle = .dark
        if navigationController?.viewControllers.first === self {
            navigationController?.overrideUserInterfaceStyle = .dark
        }
        // A plain glass Save: the "done" style fills the capsule with the tint and hides its text.
        navigationItem.rightBarButtonItem?.style = .plain
        navigationItem.rightBarButtonItem?.tintColor = mode.text
        tableView.backgroundColor = mode.background
        tableView.separatorStyle = .none
        // The same side margins as the entry page.
        tableView.cellLayoutMarginsFollowReadableWidth = false
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        tableView.register(UINib(nibName: "TextFieldTableViewCell", bundle: nil), forCellReuseIdentifier: "textFieldCell")
        tableView.register(UINib(nibName: "TextViewTableViewCell", bundle: nil), forCellReuseIdentifier: "textViewCell")
        tableView.register(UINib(nibName: "FillPasswordTableViewCell", bundle: nil), forCellReuseIdentifier: "fillPasswordCell")
        tableView.register(UINib(nibName: "SliderTableViewCell", bundle: nil), forCellReuseIdentifier: "sliderCell")
        tableView.register(UINib(nibName: "SwitchTableViewCell", bundle: nil), forCellReuseIdentifier: "switchCell")

        tableData = [
            [
                [.type: PasswordEditorCellType.nameCell, .title: "Name".localize(), .content: password?.namePath ?? ""],
            ],
            [
                [.type: PasswordEditorCellType.fillPasswordCell, .content: ""],
                [.type: PasswordEditorCellType.generatorToggleCell],
                [.type: PasswordEditorCellType.generatorSettingsCell],
            ],
            [
                [.type: PasswordEditorCellType.additionsCell, .title: "Additions".localize(), .content: password?.additionsPlainText ?? ""],
            ],
            [
                [.type: PasswordEditorCellType.scanQRCodeCell],
            ],
        ]

        sectionHeaderTitles = ["Name".localize(), "New Password", "Additions".localize(), nil]
        if let currentPassword = password?.password {
            tableData.insert([[.type: PasswordEditorCellType.currentPasswordCell, .content: currentPassword]], at: 1)
            sectionHeaderTitles.insert("Current Password", at: 1)
        }

        if password != nil {
            // Right under "Add One-Time Password", in the same group.
            tableData[tableData.count - 1].append([.type: PasswordEditorCellType.deletePasswordCell])
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellData = tableData[indexPath.section][indexPath.row]

        switch cellData[PasswordEditorCellKey.type] as! PasswordEditorCellType {
        case .nameCell:
            nameCell = tableView.dequeueReusableCell(withIdentifier: "textFieldCell", for: indexPath) as? TextFieldTableViewCell
            nameCell?.contentTextField.delegate = self
            nameCell?.contentTextField.autocorrectionType = .no
            nameCell?.contentTextField.autocapitalizationType = .none
            nameCell?.contentTextField.spellCheckingType = .no
            nameCell?.contentTextField.addTarget(self, action: #selector(nameDidChange), for: .editingChanged)
            nameCell?.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            return nameCell!
        case .fillPasswordCell:
            fillPasswordCell = tableView.dequeueReusableCell(withIdentifier: "fillPasswordCell", for: indexPath) as? FillPasswordTableViewCell
            fillPasswordCell?.delegate = self
            fillPasswordCell?.contentTextField.delegate = self
            fillPasswordCell?.passwordTextColor = mode.text
            fillPasswordCell?.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            // The accordion below holds the generator settings; 🔄 stays.
            fillPasswordCell?.settingButton.isHidden = true
            if password != nil {
                fillPasswordCell?.contentTextField.attributedPlaceholder = NSAttributedString(
                    string: "blank keeps the current password",
                    attributes: [.foregroundColor: mode.label.withAlphaComponent(0.6), .font: Theme.mono(15)]
                )
            }
            return fillPasswordCell!
        case .currentPasswordCell:
            return currentPasswordCell(showing: cellData[PasswordEditorCellKey.content] as? String ?? "")
        case .generatorToggleCell:
            return generatorToggleCell()
        case .generatorSettingsCell:
            return generatorSettingsCell()
        case .additionsCell:
            additionsCell = tableView.dequeueReusableCell(withIdentifier: "textViewCell", for: indexPath) as? TextViewTableViewCell
            additionsCell?.contentTextView.delegate = self
            additionsCell?.setContent(content: cellData[PasswordEditorCellKey.content] as? String)
            additionsCell?.contentTextView.textColor = mode.text
            // The field grows with its content instead of scrolling inside the form.
            additionsCell?.contentTextView.isScrollEnabled = false
            return additionsCell!
        case .deletePasswordCell:
            return deletePasswordCell!
        case .scanQRCodeCell:
            return scanQRCodeCell!
        }
    }

    override func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt _: IndexPath) {
        cell.backgroundColor = mode.background
        cell.textLabel?.textColor = mode.label
        // Inputs sit close together, like the fields on the entry page; the two buttons 8pt apart.
        // The content view takes the larger of its own and the cell's margins, so set both.
        let isButton = cell == scanQRCodeCell || cell == deletePasswordCell
        for view in [cell, cell.contentView] {
            view.directionalLayoutMargins.top = isButton ? 4 : 2
            view.directionalLayoutMargins.bottom = isButton ? 4 : 2
        }

        switch cell {
        case let cell as TextFieldTableViewCell:
            styleInput(cell.contentTextField)
        case let cell as FillPasswordTableViewCell:
            styleInput(cell.contentTextField)
            cell.generateButton.tintColor = mode.label
            cell.settingButton.tintColor = mode.label
        case let cell as TextViewTableViewCell:
            cell.contentTextView.font = Theme.mono(17)
            cell.contentTextView.backgroundColor = mode.input
            cell.contentTextView.layer.cornerRadius = 12
            cell.contentTextView.textContainerInset = UIEdgeInsets(top: 12, left: 11, bottom: 12, right: 11)
            cell.contentTextView.tintColor = mode.text
        case let cell as SliderTableViewCell:
            cell.titleLabel.font = Theme.mono(13, relativeTo: .footnote)
            cell.titleLabel.textColor = mode.label
            cell.valueLabel.font = Theme.mono(13, relativeTo: .footnote)
            cell.valueLabel.textColor = mode.text
            cell.slider.minimumTrackTintColor = mode.text
            cell.slider.maximumTrackTintColor = mode.input
        case let cell as SwitchTableViewCell:
            cell.titleLabel.font = Theme.mono(13, relativeTo: .footnote)
            cell.titleLabel.textColor = mode.label
            cell.controlSwitch.onTintColor = mode.rule
            cell.controlSwitch.backgroundColor = mode.input
            cell.controlSwitch.layer.cornerRadius = cell.controlSwitch.bounds.height / 2
        default:
            break
        }
    }

    // Sized like the entry page's value pills: 17pt text, 12pt above and below, 16pt inset, radius 12.
    private func styleInput(_ textField: UITextField) {
        textField.font = Theme.mono(17)
        textField.textColor = mode.text
        textField.tintColor = mode.text
        textField.backgroundColor = mode.input
        textField.borderStyle = .none
        textField.layer.cornerRadius = 12
        if textField.leftView == nil {
            textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
            textField.leftViewMode = .always
        }
        if !textField.constraints.contains(where: { $0.identifier == "datumHeight" }) {
            let height = textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 45)
            height.identifier = "datumHeight"
            height.isActive = true
        }
    }

    private func makeButtonCell(title: String, textColor: UIColor, fill: UIColor?, action: Selector) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        let button = UIButton(type: .system)
        if #available(iOS 26.0, *) {
            var configuration: UIButton.Configuration = fill == nil ? .glass() : .prominentGlass()
            configuration.baseForegroundColor = textColor
            configuration.baseBackgroundColor = fill
            configuration.attributedTitle = AttributedString(title, attributes: AttributeContainer([.font: Theme.sansButtonFont]))
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            button.configuration = configuration
            button.tintColor = fill
        } else {
            var configuration = UIButton.Configuration.filled()
            configuration.baseForegroundColor = textColor
            configuration.baseBackgroundColor = fill ?? mode.input
            configuration.cornerStyle = .capsule
            configuration.attributedTitle = AttributedString(title, attributes: AttributeContainer([.font: Theme.sansButtonFont]))
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
            button.configuration = configuration
        }
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(button)
        let margins = cell.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: margins.topAnchor),
            button.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ])
        return cell
    }

    // MARK: - Path suggestions

    /// Up to eight folders containing what's typed, those starting with it first, as in Pass Picker.
    private func filteredFolderSuggestions(for name: String) -> [String] {
        guard !name.isEmpty else {
            return Array(folderSuggestions.prefix(8))
        }
        let lower = name.lowercased()
        let matches = folderSuggestions.filter { $0.lowercased().contains(lower) && $0 != name }
        let starting = matches.filter { $0.lowercased().hasPrefix(lower) }
        let others = matches.filter { !$0.lowercased().hasPrefix(lower) }
        return Array((starting + others).prefix(8))
    }

    @objc
    private func nameDidChange() {
        suggestionIndex = -1
        showSuggestions()
    }

    private func showSuggestions() {
        guard let field = nameCell?.contentTextField else {
            return
        }
        shownSuggestions = filteredFolderSuggestions(for: field.text ?? "")
        suggestionsView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !shownSuggestions.isEmpty else {
            hideSuggestions()
            return
        }
        for (index, folder) in shownSuggestions.enumerated() {
            let button = UIButton(type: .custom)
            button.setTitle(folder, for: .normal)
            button.setTitleColor(mode.text, for: .normal)
            button.titleLabel?.font = Theme.mono(13, relativeTo: .footnote)
            button.titleLabel?.lineBreakMode = .byTruncatingMiddle
            button.contentHorizontalAlignment = .leading
            button.contentEdgeInsets = UIEdgeInsets(top: 9, left: 12, bottom: 9, right: 12)
            button.backgroundColor = index == suggestionIndex ? UIColor.white.withAlphaComponent(0.1) : .clear
            button.tag = index
            button.addTarget(self, action: #selector(tapSuggestion), for: .touchUpInside)
            suggestionsView.addArrangedSubview(button)
        }
        if suggestionsView.superview == nil {
            suggestionsView.axis = .vertical
            suggestionsView.backgroundColor = mode.input
            suggestionsView.layer.cornerRadius = 8
            suggestionsView.clipsToBounds = true
            // Set apart from the input it covers.
            suggestionsView.layer.borderWidth = 1
            suggestionsView.layer.borderColor = mode.label.withAlphaComponent(0.5).cgColor
            suggestionsView.layer.zPosition = 10
            tableView.addSubview(suggestionsView)
        }
        // Just under the field, over the rows below it.
        let fieldFrame = field.convert(field.bounds, to: tableView)
        let size = suggestionsView.systemLayoutSizeFitting(CGSize(width: fieldFrame.width, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        suggestionsView.frame = CGRect(x: fieldFrame.minX, y: fieldFrame.maxY + 4, width: fieldFrame.width, height: size.height)
        suggestionsView.isHidden = false
        tableView.bringSubviewToFront(suggestionsView)
    }

    private func hideSuggestions() {
        suggestionsView.isHidden = true
        shownSuggestions = []
        suggestionIndex = -1
    }

    private var suggestionsAreShown: Bool {
        !suggestionsView.isHidden && !shownSuggestions.isEmpty
    }

    private func applySuggestion(_ folder: String) {
        nameCell?.contentTextField.text = folder
        tableData[nameSection][0][PasswordEditorCellKey.content] = folder
        hideSuggestions()
        nameCell?.contentTextField.becomeFirstResponder()
    }

    @objc
    private func tapSuggestion(_ sender: UIButton) {
        applySuggestion(shownSuggestions[sender.tag])
    }

    @objc
    private func nextSuggestion() {
        suggestionIndex = min(suggestionIndex + 1, shownSuggestions.count - 1)
        showSuggestions()
    }

    @objc
    private func previousSuggestion() {
        suggestionIndex = max(suggestionIndex - 1, -1)
        showSuggestions()
    }

    @objc
    private func applySelectedSuggestion() {
        guard shownSuggestions.indices.contains(suggestionIndex) else {
            return
        }
        applySuggestion(shownSuggestions[suggestionIndex])
    }

    // MARK: - Password generator

    /// Pass Picker's generator: at least one lowercase letter, capital, digit and special character, shuffled.
    static func generatePassword(length: Int, specialCharacters: String) -> String {
        let charsets = ["abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "0123456789", specialCharacters]
            .map(Array.init)
            .filter { !$0.isEmpty }
        let pool = charsets.flatMap(\.self)
        guard !pool.isEmpty else {
            return ""
        }
        var generator = SystemRandomNumberGenerator()
        var characters = charsets.compactMap { $0.randomElement(using: &generator) }
        while characters.count < length {
            characters.append(pool.randomElement(using: &generator)!)
        }
        return String(characters.shuffled(using: &generator))
    }

    private func toggleGenerator() {
        generatorOpen.toggle()
        let settingsRow = IndexPath(row: tableData[passwordSection].count - 1, section: passwordSection)
        let toggleRow = IndexPath(row: settingsRow.row - 1, section: passwordSection)
        tableView.performBatchUpdates {
            if generatorOpen {
                tableView.insertRows(at: [settingsRow], with: .fade)
            } else {
                tableView.deleteRows(at: [settingsRow], with: .fade)
            }
            tableView.reloadRows(at: [toggleRow], with: .none)
        }
    }

    // Changing a setting redraws a password that was already generated.
    private func regenerateIfFilled() {
        if fillPasswordCell?.getContent()?.isEmpty == false {
            generateAndCopyPasswordNoOtpCheck()
        }
    }

    private func currentPasswordCell(showing currentPassword: String) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        let datum = UIView()
        datum.backgroundColor = mode.input
        datum.layer.cornerRadius = 12
        let label = UILabel()
        label.attributedText = Theme.attributedPassword(currentPassword, textColor: mode.text, font: Theme.mono(17))
        label.lineBreakMode = .byTruncatingTail
        for view in [datum, label] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        cell.contentView.addSubview(datum)
        datum.addSubview(label)
        let margins = cell.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            datum.topAnchor.constraint(equalTo: margins.topAnchor),
            datum.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            datum.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            datum.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            label.leadingAnchor.constraint(equalTo: datum.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: datum.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: datum.centerYAnchor),
        ])
        return cell
    }

    private func generatorToggleCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.textLabel?.text = (generatorOpen ? "\u{25BD}" : "\u{25B7}") + " Generator settings"
        cell.textLabel?.font = Theme.mono(13, relativeTo: .footnote)
        cell.textLabel?.textColor = mode.label
        return cell
    }

    // Length (− n +) and the special characters to draw from, side by side as in Pass Picker.
    private func generatorSettingsCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none

        let minus = makeStepperButton("−", action: #selector(decreaseLength))
        let plus = makeStepperButton("+", action: #selector(increaseLength))
        lengthLabel.text = "\(generatorLength)"
        lengthLabel.font = Theme.mono(15)
        lengthLabel.textColor = mode.text
        lengthLabel.textAlignment = .center
        let stepper = UIStackView(arrangedSubviews: [minus, lengthLabel, plus])
        stepper.distribution = .fill
        stepper.backgroundColor = mode.input
        stepper.layer.cornerRadius = 8
        lengthLabel.widthAnchor.constraint(equalToConstant: 32).isActive = true

        let special = UITextField()
        special.text = generatorSpecialCharacters
        special.font = Theme.mono(15)
        special.textColor = mode.text
        special.tintColor = mode.text
        special.backgroundColor = mode.input
        special.layer.cornerRadius = 8
        special.autocapitalizationType = .none
        special.autocorrectionType = .no
        special.spellCheckingType = .no
        special.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        special.leftViewMode = .always
        special.addTarget(self, action: #selector(specialCharactersChanged), for: .editingChanged)

        let lengthColumn = UIStackView(arrangedSubviews: [settingLabel("Length"), stepper])
        let specialColumn = UIStackView(arrangedSubviews: [settingLabel("Special characters"), special])
        for column in [lengthColumn, specialColumn] {
            column.axis = .vertical
            column.spacing = 6
        }
        lengthColumn.widthAnchor.constraint(equalToConstant: 128).isActive = true
        for control in [stepper, special] as [UIView] {
            control.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }
        let row = UIStackView(arrangedSubviews: [lengthColumn, specialColumn])
        row.spacing = 12
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(row)
        let margins = cell.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: margins.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: margins.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ])
        return cell
    }

    private func settingLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = Theme.mono(12, relativeTo: .caption1)
        label.textColor = mode.label
        return label
    }

    private func makeStepperButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20)
        button.tintColor = mode.text.withAlphaComponent(0.7)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    private func setGeneratorLength(_ length: Int) {
        generatorLength = min(max(length, 4), 64)
        Defaults.passwordGeneratorLength = generatorLength
        lengthLabel.text = "\(generatorLength)"
        regenerateIfFilled()
    }

    @objc
    private func decreaseLength() {
        setGeneratorLength(generatorLength - 1)
    }

    @objc
    private func increaseLength() {
        setGeneratorLength(generatorLength + 1)
    }

    @objc
    private func specialCharactersChanged(_ sender: UITextField) {
        generatorSpecialCharacters = sender.text ?? ""
        Defaults.passwordGeneratorSpecialCharacters = generatorSpecialCharacters
    }

    @objc
    private func deletePassword() {
        let confirmation = DeleteConfirmViewController(path: password?.namePath ?? "") { [unowned self] in
            performSegue(withIdentifier: "deletePasswordSegue", sender: self)
        }
        present(confirmation, animated: true)
    }

    @objc
    private func addOneTimePassword() {
        performSegue(withIdentifier: "showQRScannerSegue", sender: self)
    }

    // Field labels are spaced like the entry page's: 18pt above the label, 10pt between it and the input
    // (8pt here plus the cell's 2pt top margin).
    override func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UITableViewHeaderFooterView()
        header.backgroundConfiguration = .clear()
        guard let title = sectionHeaderTitles[section] else {
            return header
        }
        let label = UILabel()
        label.text = title
        label.font = Theme.mono(14, relativeTo: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = mode.label
        label.translatesAutoresizingMaskIntoConstraints = false
        header.contentView.addSubview(label)
        let margins = header.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: header.contentView.topAnchor, constant: 18),
            label.bottomAnchor.constraint(equalTo: header.contentView.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ])
        return header
    }

    override func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        sectionHeaderTitles[section] == nil ? 24 : UITableView.automaticDimension
    }

    override func tableView(_: UITableView, estimatedHeightForHeaderInSection _: Int) -> CGFloat {
        44
    }

    override func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        .leastNonzeroMagnitude
    }

    override func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        nil
    }

    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch tableData[indexPath.section][indexPath.row][PasswordEditorCellKey.type] as! PasswordEditorCellType {
        case .generatorToggleCell:
            return 36
        case .generatorSettingsCell:
            // Labels, the 40pt controls, and a little room before the next heading.
            return 78
        case .currentPasswordCell, .fillPasswordCell, .nameCell:
            // A 45pt input, like the entry page's value pills, plus the 2pt margins.
            return 49
        case .deletePasswordCell, .scanQRCodeCell:
            // The button's own height plus 4pt above and below.
            return 52
        default:
            return UITableView.automaticDimension
        }
    }

    override func numberOfSections(in _: UITableView) -> Int {
        tableData.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == passwordSection, !generatorOpen {
            // The generator settings row shows while the accordion is open.
            return tableData[section].count - 1
        }
        return tableData[section].count
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch tableData[indexPath.section][indexPath.row][PasswordEditorCellKey.type] as? PasswordEditorCellType {
        case .currentPasswordCell:
            SecurePasteboard.shared.copy(textToCopy: password?.password)
            Toast.show("copied")
        case .generatorToggleCell:
            toggleGenerator()
        default:
            break
        }
    }

    // generate the password, don't care whether the original line is otp
    private func generateAndCopyPasswordNoOtpCheck() {
        let plainPassword = Self.generatePassword(length: generatorLength, specialCharacters: generatorSpecialCharacters)

        // update tableData so to make sure reloadData() works correctly
        tableData[passwordSection][0][PasswordEditorCellKey.content] = plainPassword

        // update cell manually, no need to call reloadData()
        fillPasswordCell?.setContent(content: plainPassword)
    }

    private func insertScannedOTPFields(_ otpauth: String) {
        // update tableData
        var additionsString = ""
        if let additionsPlainText = (tableData[additionsSection][0][PasswordEditorCellKey.content] as? String)?.trimmed, !additionsPlainText.isEmpty {
            additionsString = additionsPlainText + "\n" + otpauth
        } else {
            additionsString = otpauth
        }
        tableData[additionsSection][0][PasswordEditorCellKey.content] = additionsString

        // reload the additions cell
        additionsCell?.setContent(content: additionsString)
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "showQRScannerSegue" {
            if let navController = segue.destination as? UINavigationController {
                if let viewController = navController.topViewController as? QRScannerController {
                    viewController.delegate = self
                }
            } else if let viewController = segue.destination as? QRScannerController {
                viewController.delegate = self
            }
        }
    }

    func getNamePath() -> (String, String) {
        guard let encodedName = nameCell?.getContent()?.stringByAddingPercentEncodingForRFC3986(), let url = URL(string: encodedName) else {
            return ("", "")
        }
        let name = url.lastPathComponent
        let path = url.appendingPathExtension("gpg").path
        return (name, path)
    }

    func checkName() -> Bool {
        // the name field should not be empty
        guard let name = nameCell?.getContent(), name.isEmpty == false else {
            Utils.alert(title: "CannotSave".localize(), message: "FillInName.".localize(), controller: self, completion: nil)
            return false
        }

        // the name should not start with /
        guard name.hasPrefix("/") == false else {
            Utils.alert(title: "CannotSave".localize(), message: "RemovePrefix.".localize(), controller: self, completion: nil)
            return false
        }

        // the name field should be a valid url
        guard let path = name.stringByAddingPercentEncodingForRFC3986(),
              var passwordURL = URL(string: path) else {
            Utils.alert(title: "CannotSave".localize(), message: "PasswordNameInvalid.".localize(), controller: self, completion: nil)
            return false
        }

        // check whether we can parse the filename (be consistent with PasswordStore::addPasswordEntities)
        var previousPathLength = Int.max
        while passwordURL.path != "." {
            passwordURL = passwordURL.deletingLastPathComponent()
            if passwordURL.path != ".", passwordURL.path.count >= previousPathLength {
                Utils.alert(title: "CannotSave".localize(), message: "CannotParseFilename.".localize(), controller: self, completion: nil)
                return false
            }
            previousPathLength = passwordURL.path.count
        }

        return true
    }
}

// MARK: - FillPasswordTableViewCellDelegate

extension PasswordEditorTableViewController: FillPasswordTableViewCellDelegate {
    // generate password, copy to pasteboard, and set the cell
    // check whether the current password looks like an OTP field
    func generateAndCopyPassword() {
        if let currentPassword = fillPasswordCell?.getContent(), Constants.isOtpRelated(line: currentPassword) {
            let alert = UIAlertController(title: "Overwrite?".localize(), message: "OverwriteOtpConfiguration?".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(
                UIAlertAction(title: "Yes".localize(), style: UIAlertAction.Style.destructive) { _ in
                    self.generateAndCopyPasswordNoOtpCheck()
                }
            )
            alert.addAction(UIAlertAction.cancel())
            present(alert, animated: true, completion: nil)
        } else {
            generateAndCopyPasswordNoOtpCheck()
        }
    }

    func showHidePasswordSettings() {
        toggleGenerator()
    }
}

// MARK: - PasswordSettingSliderTableViewCellDelegate

extension PasswordEditorTableViewController: PasswordSettingSliderTableViewCellDelegate {}

// MARK: - QRScannerControllerDelegate

extension PasswordEditorTableViewController: QRScannerControllerDelegate {
    func checkScannedOutput(line: String) -> (accepted: Bool, message: String) {
        if let url = URL(string: line), Token(url: url) != nil {
            return (true, "ValidTokenUrl".localize())
        }
        return (false, "InvalidTokenUrl".localize())
    }

    func handleScannedOutput(line: String) {
        insertScannedOTPFields(line)
    }
}

// MARK: - SFSafariViewControllerDelegate

extension PasswordEditorTableViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_: SFSafariViewController) {
        let copiedLinesSplit = UIPasteboard.general.string?.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter { !$0.isEmpty }
        if copiedLinesSplit?.count ?? 0 > 0 {
            let generatedPassword = copiedLinesSplit![0]
            let alert = UIAlertController(title: "WannaUseIt?".localize(), message: "", preferredStyle: UIAlertController.Style.alert)
            let message = NSMutableAttributedString(string: "\("SeemsLikeYouHaveCopiedSomething.".localize()) \("FirstStringIs:".localize())\n")
            message.append(Utils.attributedPassword(plainPassword: generatedPassword))
            alert.setValue(message, forKey: "attributedMessage")
            alert.addAction(
                UIAlertAction(title: "Yes", style: UIAlertAction.Style.default) { [unowned self] _ in
                    // update tableData so to make sure reloadData() works correctly
                    tableData[passwordSection][0][PasswordEditorCellKey.content] = generatedPassword
                    // update cell manually, no need to call reloadData()
                    fillPasswordCell?.setContent(content: generatedPassword)
                }
            )
            alert.addAction(UIAlertAction.cancel())
            present(alert, animated: true, completion: nil)
        }
    }
}

// MARK: - UITextFieldDelegate

extension PasswordEditorTableViewController: UITextFieldDelegate {
    // update tableData so to make sure reloadData() works correctly
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == nameCell?.contentTextField {
            showSuggestions()
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == nameCell?.contentTextField {
            hideSuggestions()
            tableData[nameSection][0][PasswordEditorCellKey.content] = nameCell?.getContent()
        } else if textField == fillPasswordCell?.contentTextField {
            if let plainPassword = fillPasswordCell?.getContent() {
                tableData[passwordSection][0][PasswordEditorCellKey.content] = plainPassword
            }
        }
    }
}

// MARK: - UITextViewDelegate

extension PasswordEditorTableViewController: UITextViewDelegate {
    // update tableData so to make sure reloadData() works correctly
    func textViewDidChange(_ textView: UITextView) {
        guard textView == additionsCell?.contentTextView else {
            return
        }
        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == additionsCell?.contentTextView {
            tableData[additionsSection][0][PasswordEditorCellKey.content] = additionsCell?.getContent()
        }
    }
}

// MARK: - Hardware keyboard shortcuts

extension PasswordEditorTableViewController {
    override var canBecomeFirstResponder: Bool {
        true
    }

    override var keyCommands: [UIKeyCommand]? {
        // In the name field, the suggestions take ↓ ↑, Return/Tab (with one picked) and Esc.
        var suggestionCommands = [UIKeyCommand]()
        if suggestionsAreShown, nameCell?.contentTextField.isFirstResponder == true {
            suggestionCommands = [
                .shortcut(UIKeyCommand.inputDownArrow, action: #selector(nextSuggestion)),
                .shortcut(UIKeyCommand.inputUpArrow, action: #selector(previousSuggestion)),
            ]
            if suggestionIndex >= 0 {
                suggestionCommands += [
                    .shortcut("\r", action: #selector(applySelectedSuggestion)),
                    .shortcut("\t", action: #selector(applySelectedSuggestion)),
                ]
            }
        }
        return suggestionCommands + [
            .shortcut(UIKeyCommand.inputEscape, action: #selector(cancelFromKeyboard), title: "Cancel"),
            .shortcut("\r", action: #selector(saveFromKeyboard), modifiers: .command, title: "Save"),
            .shortcut("r", action: #selector(generateFromKeyboard), modifiers: .command, title: "Generate Password"),
        ]
    }

    // The bar buttons are storyboard unwind segues; triggering them keeps their validation and save logic.
    private func trigger(_ item: UIBarButtonItem?) {
        guard let item, let action = item.action else {
            return
        }
        UIApplication.shared.sendAction(action, to: item.target, from: item, for: nil)
    }

    @objc
    private func cancelFromKeyboard() {
        if suggestionsAreShown {
            hideSuggestions()
            return
        }
        trigger(navigationItem.leftBarButtonItem)
    }

    @objc
    private func saveFromKeyboard() {
        view.endEditing(true)
        trigger(navigationItem.rightBarButtonItem)
    }

    @objc
    private func generateFromKeyboard() {
        generateAndCopyPassword()
    }
}
