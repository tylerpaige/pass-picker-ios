//
//  PasswordDetailTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 2/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Gopenpgp
import passAutoFillExtension
import passKit
import SVProgressHUD
import UIKit
import YubiKit

class PasswordDetailTableViewController: UITableViewController, AlertPresenting {
    var passwordEntity: PasswordEntity? {
        didSet {
            passwordPath = passwordEntity?.path
        }
    }

    var password: Password?
    /// Opens the editor as soon as the password is decrypted (⌘E, R or G from the password list).
    var opensEditorWhenReady: EditPasswordTableViewController.Intent?
    private var editorIntent = EditPasswordTableViewController.Intent.edit
    private var oneTimePasswordIndexPath: IndexPath?
    private var shouldPopCurrentView = false
    private let passwordStore = PasswordStore.shared

    // preserve path so it can be reloaded even if the passwordEntity is deleted during the update process
    private var passwordPath: String?

    private lazy var editUIBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(pressEdit))

    private struct TableSection {
        var type: PasswordDetailTableViewControllerSectionType
        var header: String?
        var item: [AdditionField] = []

        init(type: PasswordDetailTableViewControllerSectionType, header: String? = nil) {
            self.type = type
            self.header = header
        }
    }

    private var tableData = [TableSection]()

    private enum PasswordDetailTableViewControllerSectionType {
        case name, main, addition
    }

    private var passwordYubiKeyDecryptor = PasswordYubiKeyDecryptor()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "LabelTableViewCell", bundle: nil), forCellReuseIdentifier: "labelCell")
        tableView.register(UINib(nibName: "PasswordDetailTitleTableViewCell", bundle: nil), forCellReuseIdentifier: "passwordDetailTitleTableViewCell")

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.backgroundColor = Theme.Palette.surface
        if #available(iOS 15.0, *) {
            // The table's own keyboard focus would take ↑/↓ before the field shortcuts.
            tableView.allowsFocus = false
        }
        tableView.separatorStyle = .none
        let navigationBar = Theme.navigationBarAppearance(background: Theme.Palette.chromeAlt, text: Theme.Palette.chromeText)
        navigationItem.standardAppearance = navigationBar
        navigationItem.compactAppearance = navigationBar
        navigationItem.scrollEdgeAppearance = navigationBar
        if browser == nil {
            let adjustForTabbarInsets = UIEdgeInsets(top: 0, left: 0, bottom: tabBarController?.tabBar.frame.height ?? 0, right: 0)
            tableView.contentInset = adjustForTabbarInsets
            tableView.scrollIndicatorInsets = adjustForTabbarInsets
        }

        editUIBarButtonItem.isEnabled = false
        navigationItem.rightBarButtonItem = editUIBarButtonItem
        navigationItem.largeTitleDisplayMode = .never

        decryptThenShowPassword()
        setupOneTimePasswordAutoRefresh()

        // pop the current view because this password might be "discarded"
        NotificationCenter.default.addObserver(self, selector: #selector(setShouldPopCurrentView), name: .passwordStoreChangeDiscarded, object: nil)

        // reset the data table if the disaply settings have been changed
        NotificationCenter.default.addObserver(self, selector: #selector(decryptThenShowPasswordSelector), name: .passwordDetailDisplaySettingChanged, object: nil)

        // A Siri shortcut can change the state of the app in the background. Hence, reload when opening the app.
        NotificationCenter.default.addObserver(self, selector: #selector(actOnPossiblePasswordStoreUpdate), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Receive hardware keyboard shortcuts.
        becomeFirstResponder()
        if shouldPopCurrentView {
            let alert = UIAlertController(title: "Notice".localize(), message: "PreviousChangesDiscarded.".localize(), preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction.okAndPopView(controller: self))
            present(alert, animated: true, completion: nil)
        }
    }

    @objc
    private func decryptThenShowPasswordSelector(_: Any) {
        decryptThenShowPassword()
    }

    private func decryptThenShowPassword() {
        if Defaults.isYubiKeyEnabled, YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            decryptThenShowPasswordYubiKey()
        } else {
            decryptThenShowPasswordLocalKey()
        }
    }

    private func decryptThenShowPasswordLocalKey(keyID: String? = nil) {
        guard let passwordEntity else {
            Utils.alert(title: "CannotShowPassword".localize(), message: "PasswordDoesNotExist".localize(), controller: self, completion: {
                self.close()
            })
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            // decrypt password
            do {
                let requestPGPKeyPassphrase = Utils.createRequestPGPKeyPassphraseHandler(controller: self)
                self.password = try self.passwordStore.decrypt(passwordEntity: passwordEntity, keyID: keyID, requestPGPKeyPassphrase: requestPGPKeyPassphrase)
                self.showPassword()
            } catch let AppError.pgpPrivateKeyNotFound(keyID: key) {
                DispatchQueue.main.async {
                    // alert: cancel or try again
                    let alert = UIAlertController(title: "CannotShowPassword".localize(), message: AppError.pgpPrivateKeyNotFound(keyID: key).localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction.cancelAndPopView(controller: self))
                    let selectKey = UIAlertAction.selectKey(controller: self) { action in
                        self.decryptThenShowPasswordLocalKey(keyID: action.title)
                    }
                    alert.addAction(selectKey)

                    self.present(alert, animated: true, completion: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    // alert: cancel or try again
                    let alert = UIAlertController(title: "CannotShowPassword".localize(), message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction.cancelAndPopView(controller: self))
                    alert.addAction(
                        UIAlertAction(title: "TryAgain".localize(), style: .default) { _ in
                            self.decryptThenShowPasswordLocalKey()
                        }
                    )
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    private func showPassword() {
        DispatchQueue.main.async { [weak self] in
            self?.setTableData()
            self?.tableView.reloadData()
            self?.editUIBarButtonItem.isEnabled = true
            if let intent = self?.opensEditorWhenReady {
                self?.opensEditorWhenReady = nil
                self?.openEditor(intent)
            }
        }
    }

    private func setupOneTimePasswordAutoRefresh() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            // bail out of the timer code if the object has been freed
            guard let strongSelf = self,
                  let otpType = strongSelf.password?.otpType,
                  otpType != .none,
                  let indexPath = strongSelf.oneTimePasswordIndexPath,
                  let cell = strongSelf.tableView.cellForRow(at: indexPath) as? LabelTableViewCell else {
                return
            }
            switch otpType {
            case .totp:
                if let (title, otp) = strongSelf.password?.getOtpStrings() {
                    strongSelf.tableData[indexPath.section].item[indexPath.row] = title => otp
                    cell.cellData?.title = title
                    cell.cellData?.content = otp
                }
            default:
                break
            }
        }
    }

    @objc
    private func pressEdit(_: Any?) {
        openEditor(.edit)
    }

    func openEditor(_ intent: EditPasswordTableViewController.Intent) {
        guard editUIBarButtonItem.isEnabled else {
            // Not decrypted yet: open once it is.
            opensEditorWhenReady = intent
            return
        }
        editorIntent = intent
        performSegue(withIdentifier: "editPasswordSegue", sender: self)
    }

    @objc
    private func setShouldPopCurrentView() {
        shouldPopCurrentView = true
    }

    @IBAction
    private func cancelEditPassword(segue _: UIStoryboardSegue) {}

    @IBAction
    private func saveEditPassword(segue _: UIStoryboardSegue) {
        if password!.changed != 0 {
            saveEditPassword(password: password!)
        }
    }

    private func saveEditPassword(password: Password, keyID: String? = nil) {
        SVProgressHUD.show(withStatus: "Saving".localize())
        do {
            passwordEntity = try passwordStore.edit(passwordEntity: passwordEntity!, password: password, keyID: keyID)
            setTableData()
            tableView.reloadData()
            SVProgressHUD.showSuccess(withStatus: "Success".localize())
            SVProgressHUD.dismiss(withDelay: 1)
        } catch let AppError.pgpPublicKeyNotFound(keyID: key) {
            DispatchQueue.main.async {
                // alert: cancel or select keys
                SVProgressHUD.dismiss()
                let alert = UIAlertController(title: "Cannot Edit Password", message: AppError.pgpPublicKeyNotFound(keyID: key).localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction.cancelAndPopView(controller: self))
                let selectKey = UIAlertAction.selectKey(controller: self) { action in
                    self.saveEditPassword(password: password, keyID: action.title)
                }
                alert.addAction(selectKey)

                self.present(alert, animated: true, completion: nil)
            }
            return
        } catch {
            DispatchQueue.main.async {
                Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
            }
        }
    }

    @IBAction
    private func deletePassword(segue _: UIStoryboardSegue) {
        deleteCurrentPassword()
    }

    private func deleteCurrentPassword() {
        do {
            try passwordStore.delete(passwordEntity: passwordEntity!)
        } catch {
            Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
        }
        close()
    }

    /// The two-pane browser this entry is shown in, if it isn't pushed on its own.
    private var browser: PasswordBrowserViewController? {
        parent as? PasswordBrowserViewController
    }

    // Leaves the entry: clears the browser's entry pane, or pops when pushed on its own.
    private func close() {
        if let browser {
            browser.closeDetail()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    private func setTableData() {
        tableData = [TableSection]()

        // name section
        var section = TableSection(type: .name)
        section.item.append(AdditionField())
        tableData.append(section)

        // main section
        section = TableSection(type: .main)
        let password = password!
        // The password comes first.
        section.item.append(Constants.PASSWORD_KEYWORD => password.password)
        if let username = password.username {
            section.item.append(Constants.USERNAME_KEYWORD => username)
        }
        if let user = password.user {
            section.item.append(Constants.USER_KEYWORD => user)
        }
        if let login = password.login {
            section.item.append(Constants.LOGIN_KEYWORD => login)
        }
        tableData.append(section)

        // addition section

        // show one time password
        if password.otpType != .none {
            if let (title, otp) = self.password?.getOtpStrings() {
                section = TableSection(type: .addition, header: "OneTimePassword".localize())
                section.item.append(title => otp)
                tableData.append(section)
                oneTimePasswordIndexPath = IndexPath(row: 0, section: tableData.count - 1)
            }
        }

        // show additional information
        let filteredAdditionKeys = password.getFilteredAdditions()
        if !filteredAdditionKeys.isEmpty {
            section = TableSection(type: .addition, header: "Additions".localize())
            section.item.append(contentsOf: filteredAdditionKeys)
            tableData.append(section)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "editPasswordSegue" {
            if let controller = segue.destination as? UINavigationController {
                if let editController = controller.viewControllers.first as? EditPasswordTableViewController {
                    editController.password = password
                    editController.intent = editorIntent
                    editorIntent = .edit
                }
            }
        } else if segue.identifier == "showRawPasswordSegue" {
            if let controller = segue.destination as? UINavigationController {
                if let controller = controller.viewControllers.first as? RawPasswordViewController {
                    controller.password = password
                }
            }
        }
    }

    @IBAction
    private func back(segue _: UIStoryboardSegue) {}

    func getNextHOTP() {
        guard password != nil, passwordEntity != nil, password?.otpType == .hotp else {
            DispatchQueue.main.async {
                Utils.alert(title: "Error".localize(), message: "GetNextPasswordOfNonHotp.".localize(), controller: self, completion: nil)
            }
            return
        }

        // copy HOTP to pasteboard (will update counter)
        if let plainPassword = password!.getNextHotp() {
            SecurePasteboard.shared.copy(textToCopy: plainPassword)
        }

        // commit the change of HOTP counter
        if password!.changed != 0 {
            do {
                passwordEntity = try passwordStore.edit(passwordEntity: passwordEntity!, password: password!)
                Toast.show("PasswordCopied".localize() | "CounterUpdated".localize())
            } catch {
                SVProgressHUD.showSuccess(withStatus: error.localizedDescription)
                SVProgressHUD.dismiss(withDelay: 1)
            }
        }
    }

    func openLink(to address: String?) {
        guard address != nil, let url = URL(string: formActualWebAddress(from: address!)) else {
            DispatchQueue.main.async {
                Utils.alert(title: "Error".localize(), message: "CannotFindValidUrl".localize(), controller: self, completion: nil)
            }
            return
        }
        SecurePasteboard.shared.copy(textToCopy: password?.password)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func formActualWebAddress(from: String) -> String {
        let lowercased = from.lowercased()
        if !(lowercased.starts(with: "https://") || lowercased.starts(with: "http://")) {
            return "https://\(from)"
        }
        return from
    }

    override func numberOfSections(in _: UITableView) -> Int {
        tableData.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableData[section].item.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionIndex = indexPath.section
        let rowIndex = indexPath.row
        let tableDataItem = tableData[sectionIndex].item[rowIndex]
        switch tableData[sectionIndex].type {
        case .name:
            let cell = tableView.dequeueReusableCell(withIdentifier: "passwordDetailTitleTableViewCell", for: indexPath) as! PasswordDetailTitleTableViewCell
            let unsynced = passwordEntity!.isSynced ? "" : " ↻"
            cell.nameLabel.text = Theme.pathTree(passwordEntity!.nameWithDir, suffix: unsynced)
            cell.nameLabel.numberOfLines = 0
            cell.nameLabel.font = Theme.mono(20, relativeTo: .title3)
            cell.nameLabel.textColor = Theme.Palette.entryTitle
            cell.categoryLabel.text = nil
            cell.backgroundColor = Theme.Palette.surface
            cell.selectionStyle = .none
            return cell
        case .addition, .main:
            let cell = tableView.dequeueReusableCell(withIdentifier: "labelCell", for: indexPath) as! LabelTableViewCell
            let titleData = tableDataItem.title
            let contentData = tableDataItem.content
            cell.delegatePasswordTableView = self
            // The first field sits directly under the title; every later one gets a rule above it.
            cell.showsRuleAbove = !(tableData[sectionIndex].type == .main && rowIndex == 0)
            cell.cellData = LabelTableViewCellData(title: titleData, content: contentData)
            // Selection shows hardware keyboard focus.
            cell.selectionStyle = .default
            return cell
        }
    }

    private var hiddenFieldInformation: String? {
        guard let password else {
            return nil
        }
        var numberOfHiddenFields = 0
        numberOfHiddenFields += Defaults.isHideUnknownOn ? password.numberOfUnknowns : 0
        numberOfHiddenFields += Defaults.isHideOTPOn ? password.numberOfOtpRelated : 0
        return numberOfHiddenFields > 0 ? "HiddenFields(%d)".localize(numberOfHiddenFields) : nil
    }

    // Fields are self-labelled blocks separated by rules, so sections carry no headers.
    override func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        .leastNonzeroMagnitude
    }

    override func tableView(_: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        UIView()
    }

    override func tableView(_: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == tableData.count - 1 ? 110 : .leastNonzeroMagnitude
    }

    // A plain "Show raw" link sits right above "Last updated", flush with it.
    override func tableView(_: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard section == tableData.count - 1, let password else {
            return UIView()
        }
        let showRaw = UIButton(type: .system)
        showRaw.setTitle("ShowRaw".localize(), for: .normal)
        showRaw.titleLabel?.font = Theme.mono(12, relativeTo: .footnote)
        showRaw.setTitleColor(Theme.Palette.surfaceText, for: .normal)
        showRaw.contentHorizontalAlignment = .leading
        showRaw.addTarget(self, action: #selector(showRawPassword), for: .touchUpInside)

        let footerLabel = UILabel()
        footerLabel.numberOfLines = 0
        footerLabel.font = Theme.mono(12, relativeTo: .footnote)
        footerLabel.textColor = Theme.Palette.surfaceMuted
        let dateString = passwordStore.getLatestUpdateInfo(path: password.path)
        footerLabel.text = ["LastUpdated".localize(dateString), hiddenFieldInformation].compactMap(\.self).joined(separator: "\n")

        let stack = UIStackView(arrangedSubviews: [showRaw, footerLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        let view = UIView()
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 15),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -15),
        ])
        return view
    }

    @objc
    private func showRawPassword() {
        performSegue(withIdentifier: "showRawPasswordSegue", sender: self)
    }

    // Long-pressing a field shows what else it can do.
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point _: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = tableView.cellForRow(at: indexPath) as? LabelTableViewCell else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: cell.menuActions)
        }
    }

    // Tapping a field selects it and copies it.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        becomeFirstResponder()
        let section = tableData[indexPath.section]
        switch section.type {
        case .addition, .main:
            copyField(at: indexPath)
        case .name:
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }

    private func copyField(at indexPath: IndexPath) {
        tableView.focusRow(at: indexPath)
        SecurePasteboard.shared.copy(textToCopy: tableData[indexPath.section].item[indexPath.row].content)
        Toast.show("copied")
    }
}

extension PasswordDetailTableViewController {
    @objc
    func actOnPossiblePasswordStoreUpdate() {
        DispatchQueue.main.async {
            if let path = self.passwordPath {
                // reload PasswordEntity because all PasswordEntities are re-created on PasswordStore update
                self.passwordEntity = PasswordStore.shared.fetchPasswordEntity(with: path)

                // dismiss if the PasswordEntity does not exist anymore
                if self.passwordEntity == nil {
                    self.close()
                } else {
                    self.decryptThenShowPassword()
                }
            }
        }
    }

    private func requestYubiKeyPIN(completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: "YubiKey PIN", message: "Verify YubiKey OpenPGP PIN.", preferredStyle: .alert)
        alert.addAction(
            UIAlertAction.cancel { _ in
                self.close()
            }
        )
        alert.addAction(
            UIAlertAction.ok { _ in
                let pin = alert.textFields?.first?.text ?? ""
                completion(pin)
            }
        )
        alert.addTextField { textField in
            textField.isSecureTextEntry = true
        }
        present(alert, animated: true)
    }

    private func handleError(error: AppError) {
        DispatchQueue.main.async {
            self.presentFailureAlert(message: error.localizedDescription) { _ in
                self.close()
            }
        }
    }

    private func decryptThenShowPasswordYubiKey() {
        guard let passwordEntity else {
            handleError(error: AppError.other(message: "PasswordDoesNotExist"))
            return
        }
        let encryptedDataPath = passwordEntity.fileURL(in: PasswordStore.shared.storeURL)

        guard let encryptedData = try? Data(contentsOf: encryptedDataPath) else {
            handleError(error: AppError.other(message: "PasswordDoesNotExist"))
            return
        }
        requestYubiKeyPIN { [self] pin in
            Task {
                do {
                    let decryptedData = try await passwordYubiKeyDecryptor.yubiKeyDecrypt(encryptedData: encryptedData, pin: pin)
                    guard let decryptedDataString = String(data: decryptedData, encoding: .utf8) else {
                        throw AppError.yubiKey(.decipher(message: "Failed to convert plaintext to string."))
                    }
                    password = Password(name: passwordEntity.name, path: passwordEntity.path, plainText: decryptedDataString)
                    self.password = password
                    self.showPassword()
                } catch let error as AppError {
                    handleError(error: error)
                } catch {
                    handleError(error: AppError.yubiKey(.other(message: error.localizedDescription)))
                }
            }
        }
    }
}

// MARK: - Hardware keyboard shortcuts

extension PasswordDetailTableViewController {
    override var canBecomeFirstResponder: Bool {
        true
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            browser?.paneDidTakeFocus(self)
        }
        return didBecome
    }

    // Pass Picker's entry keys.
    override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = [
            .shortcut(UIKeyCommand.inputDownArrow, action: #selector(focusNextField)),
            .shortcut(UIKeyCommand.inputUpArrow, action: #selector(focusPreviousField)),
            .shortcut("j", action: #selector(focusNextField)),
            .shortcut("k", action: #selector(focusPreviousField)),
            .shortcut("\r", action: #selector(copyFocusedField), title: "Copy"),
            .shortcut("c", action: #selector(copyFocusedField)),
            .shortcut("r", action: #selector(revealFocusedField), title: "Reveal"),
            .shortcut("g", action: #selector(generatePassword), title: "Generate Password"),
            .shortcut("e", action: #selector(editFromKeyboard), title: "Edit Password"),
            .shortcut("e", action: #selector(editFromKeyboard), modifiers: .command),
            .shortcut("d", action: #selector(confirmDelete), modifiers: .command, title: "Delete Password"),
            .shortcut("n", action: #selector(newPassword), modifiers: .command, title: "New Password"),
        ]
        // Pushed on its own (outside the two-pane browser), Esc goes back.
        if browser == nil {
            commands.append(.shortcut(UIKeyCommand.inputEscape, action: #selector(goBack)))
        }
        return commands
    }

    // G: a new password for this entry, generated in the editor.
    @objc
    private func generatePassword() {
        openEditor(.regenerate)
    }

    private var fieldIndexPaths: [IndexPath] {
        tableData.indices.flatMap { section -> [IndexPath] in
            guard tableData[section].type == .main || tableData[section].type == .addition else {
                return []
            }
            return tableData[section].item.indices.map { IndexPath(row: $0, section: section) }
        }
    }

    private var focusedFieldCell: LabelTableViewCell? {
        tableView.indexPathForSelectedRow.flatMap { tableView.cellForRow(at: $0) as? LabelTableViewCell }
    }

    private func moveFieldFocus(by offset: Int) {
        let fields = fieldIndexPaths
        guard !fields.isEmpty else {
            return
        }
        let current = tableView.indexPathForSelectedRow.flatMap(fields.firstIndex(of:))
        let next = current.map { min(max($0 + offset, 0), fields.count - 1) } ?? 0
        tableView.focusRow(at: fields[next])
    }

    @objc
    private func focusNextField() {
        moveFieldFocus(by: 1)
    }

    @objc
    private func focusPreviousField() {
        moveFieldFocus(by: -1)
    }

    @objc
    private func copyFocusedField() {
        if let indexPath = tableView.indexPathForSelectedRow ?? fieldIndexPaths.first {
            copyField(at: indexPath)
        }
    }

    // Reveals the focused secret field, falling back to the password, like Pass Picker.
    @objc
    private func revealFocusedField() {
        if let cell = focusedFieldCell, cell.isSecret {
            cell.reversePasswordDisplay(nil)
            return
        }
        let passwordField = fieldIndexPaths.first { tableData[$0.section].item[$0.row].title.caseInsensitiveCompare(Constants.PASSWORD_KEYWORD) == .orderedSame }
        if let passwordField, let cell = tableView.cellForRow(at: passwordField) as? LabelTableViewCell {
            cell.reversePasswordDisplay(nil)
        }
    }

    @objc
    func editFromKeyboard() {
        openEditor(.edit)
    }

    @objc
    func confirmDelete() {
        guard let passwordEntity else {
            return
        }
        present(DeleteConfirmViewController(path: passwordEntity.nameWithDir) { [weak self] in
            self?.deleteCurrentPassword()
        }, animated: true)
    }

    @objc
    private func newPassword() {
        let list = browser?.listViewController ?? navigationController?.viewControllers.first as? PasswordNavigationViewController
        list?.addPasswordAction(nil)
    }

    @objc
    private func goBack() {
        navigationController?.popViewController(animated: true)
    }
}
