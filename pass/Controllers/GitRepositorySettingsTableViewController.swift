//
//  GitRepositorySettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import passKit
import SVProgressHUD
import UIKit

class GitRepositorySettingsTableViewController: UITableViewController, PasswordAlertPresenter {
    // MARK: - View Outlet

    @IBOutlet var gitURLTextField: UITextField!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var branchNameTextField: UITextField!
    @IBOutlet var authSSHKeyCell: UITableViewCell!
    @IBOutlet var authPasswordCell: UITableViewCell!
    @IBOutlet var gitURLCell: UITableViewCell!

    // MARK: - Properties

    /// Rows revealed under "SSH Key": import options while no key is set, else a button to unset it.
    private enum SSHKeyRow {
        case importFromURL, importArmor, importFile, importFileSharing, unset
    }

    /// Rows added below the storyboard's sections: what was in General and Advanced about the repository.
    private enum RepositoryRow {
        case about, gitSignature, rememberCredentials, discardChanges
    }

    private let repositorySections: [(title: String?, rows: [RepositoryRow])] = [
        (nil, [.about, .gitSignature, .rememberCredentials]),
        (nil, [.discardChanges]),
    ]

    private lazy var rememberCredentialsSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Theme.Palette.datumBackground
        uiSwitch.addTarget(self, action: #selector(toggleRememberCredentials), for: .valueChanged)
        return uiSwitch
    }()

    private var showsSSHKeyOptions = false
    /// The SSH key rows the table currently shows; `sshKeyRows` is what it should show.
    private var displayedSSHKeyRows = [SSHKeyRow]()
    private var authenticationSection: Int?
    private var sshKeyRowIndex = 0
    private let passwordStore = PasswordStore.shared
    private let keychain = AppKeychain.shared
    private var gitCredential: GitCredential {
        GitCredential.from(
            authenticationMethod: Defaults.gitAuthenticationMethod,
            userName: Defaults.gitUsername,
            keyStore: keychain
        )
    }

    private var gitAuthenticationMethod: GitAuthenticationMethod {
        get { Defaults.gitAuthenticationMethod }
        set {
            Defaults.gitAuthenticationMethod = newValue
            updateAuthenticationMethodCheckView(for: newValue)
        }
    }

    private var gitURL: URL {
        get { Defaults.gitURL }
        set { Defaults.gitURL = newValue }
    }

    private var gitBranchName: String {
        get { Defaults.gitBranchName }
        set { Defaults.gitBranchName = newValue }
    }

    private var gitUsername: String {
        get { Defaults.gitUsername }
        set { Defaults.gitUsername = newValue }
    }

    // MARK: - View Controller Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        gitURLTextField.text = gitURL.absoluteString
        usernameTextField.text = gitUsername
        branchNameTextField.text = gitBranchName
        authSSHKeyCell.accessoryType = .none
        locateSSHKeyCell()
        displayedSSHKeyRows = sshKeyRows
    }

    // The static table's "SSH Key" cell; its options are inserted right after it.
    private func locateSSHKeyCell() {
        for section in 0 ..< super.numberOfSections(in: tableView) {
            for row in 0 ..< super.tableView(tableView, numberOfRowsInSection: section)
                where super.tableView(tableView, cellForRowAt: IndexPath(row: row, section: section)) === authSSHKeyCell {
                authenticationSection = section
                sshKeyRowIndex = row
            }
        }
    }

    private var hasSSHKey: Bool {
        keychain.contains(key: SSHKey.PRIVATE.getKeychainKey())
    }

    private var sshKeyRows: [SSHKeyRow] {
        guard showsSSHKeyOptions || gitAuthenticationMethod == .key else {
            return []
        }
        return hasSSHKey ? [.unset] : [.importFromURL, .importArmor, .importFile, .importFileSharing]
    }

    private func sshKeyRow(at indexPath: IndexPath) -> SSHKeyRow? {
        guard indexPath.section == authenticationSection else {
            return nil
        }
        let offset = indexPath.row - sshKeyRowIndex - 1
        return displayedSSHKeyRows.indices.contains(offset) ? displayedSSHKeyRows[offset] : nil
    }

    // Swaps the rows under "SSH Key". Reloading the section would drop the storyboard's static cells.
    private func reloadAuthenticationSection() {
        updateAuthenticationMethodCheckView(for: gitAuthenticationMethod)
        guard let authenticationSection, displayedSSHKeyRows != sshKeyRows else {
            return
        }
        let indexPaths = { (rows: [SSHKeyRow]) in
            rows.indices.map { IndexPath(row: self.sshKeyRowIndex + 1 + $0, section: authenticationSection) }
        }
        let removed = indexPaths(displayedSSHKeyRows)
        displayedSSHKeyRows = sshKeyRows
        tableView.performBatchUpdates {
            tableView.deleteRows(at: removed, with: .fade)
            tableView.insertRows(at: indexPaths(displayedSSHKeyRows), with: .fade)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAuthenticationMethodCheckView(for: gitAuthenticationMethod)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    // MARK: - Repository rows

    private var storyboardSectionCount: Int {
        super.numberOfSections(in: tableView)
    }

    private func repositoryRow(at indexPath: IndexPath) -> RepositoryRow? {
        let section = indexPath.section - storyboardSectionCount
        return repositorySections.indices.contains(section) ? repositorySections[section].rows[indexPath.row] : nil
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        super.numberOfSections(in: tableView) + repositorySections.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section < storyboardSectionCount ? super.tableView(tableView, titleForHeaderInSection: section) : repositorySections[section - storyboardSectionCount].title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section < storyboardSectionCount ? super.tableView(tableView, titleForFooterInSection: section) : nil
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        section < storyboardSectionCount ? super.tableView(tableView, viewForHeaderInSection: section) : nil
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        section < storyboardSectionCount ? super.tableView(tableView, viewForFooterInSection: section) : nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section < storyboardSectionCount ? super.tableView(tableView, heightForHeaderInSection: section) : UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section < storyboardSectionCount ? super.tableView(tableView, heightForFooterInSection: section) : UITableView.automaticDimension
    }

    private func repositoryCell(for row: RepositoryRow) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.textColor = Theme.Palette.surfaceText
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.textColor = Theme.Palette.surfaceMuted
        switch row {
        case .about:
            cell.textLabel?.text = "About"
            cell.accessoryType = .disclosureIndicator
        case .gitSignature:
            cell.textLabel?.text = "Git Signature"
            cell.detailTextLabel?.text = gitSignatureSummary
            cell.accessoryType = .disclosureIndicator
        case .rememberCredentials:
            cell.textLabel?.text = "RememberGitCredentialPassphrase".localize()
            cell.textLabel?.numberOfLines = 0
            rememberCredentialsSwitch.isOn = Defaults.isRememberGitCredentialPassphraseOn
            cell.accessoryView = rememberCredentialsSwitch
            cell.selectionStyle = .none
        case .discardChanges:
            cell.textLabel?.text = "DiscardAllLocalChanges".localize()
            cell.textLabel?.textColor = Theme.Palette.danger
        }
        return cell
    }

    private var gitSignatureSummary: String {
        guard Defaults.gitSignatureName != nil || Defaults.gitSignatureEmail != nil else {
            return "NotSet".localize()
        }
        let signature = passwordStore.gitSignatureForNow
        return "\(signature?.name ?? "") <\(signature?.email ?? "")>"
    }

    private func didSelect(_ row: RepositoryRow) {
        switch row {
        case .about:
            let about = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "aboutRepository")
            about.navigationItem.title = "About"
            navigationController?.pushViewController(about, animated: true)
        case .gitSignature:
            let signature = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "gitSignature")
            navigationController?.pushViewController(signature, animated: true)
        case .rememberCredentials:
            break
        case .discardChanges:
            confirmDiscardChanges()
        }
    }

    private func confirmDiscardChanges() {
        let alert = UIAlertController(title: "DiscardAllLocalChanges?".localize(), message: "DiscardExplanation.".localize(), preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: "DiscardAllLocalChanges".localize(), style: .destructive) { [unowned self] _ in
                SVProgressHUD.show(withStatus: "Resetting...".localize())
                do {
                    let numberDiscarded = try passwordStore.reset()
                    SVProgressHUD.showSuccess(withStatus: "DiscardedCommits(%d)".localize(numberDiscarded))
                    SVProgressHUD.dismiss(withDelay: 1)
                } catch {
                    SVProgressHUD.dismiss()
                    Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
                }
            }
        )
        alert.addAction(UIAlertAction.dismiss())
        present(alert, animated: true)
    }

    @objc
    private func toggleRememberCredentials() {
        Defaults.isRememberGitCredentialPassphraseOn = rememberCredentialsSwitch.isOn
        if !rememberCredentialsSwitch.isOn {
            passwordStore.gitSSHPrivateKeyPassphrase = nil
            passwordStore.gitPassword = nil
        }
    }

    // The Git Signature screen unwinds here when saved.
    @IBAction
    private func saveGitConfigSetting(segue: UIStoryboardSegue) {
        guard let controller = segue.source as? GitConfigSettingsTableViewController,
              let name = controller.nameTextField.text, let email = controller.emailTextField.text else {
            return
        }
        Defaults.gitSignatureName = name.isEmpty ? nil : name
        Defaults.gitSignatureEmail = email.isEmpty ? nil : email
        // Only this row: reloading the storyboard's sections would blank their cells.
        tableView.reloadRows(at: [IndexPath(row: 1, section: storyboardSectionCount)], with: .none)
    }

    // MARK: - UITableViewController Override

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath) == gitURLCell {
            showGitURLFormatHelp()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < storyboardSectionCount else {
            return repositorySections[section - storyboardSectionCount].rows.count
        }
        return super.tableView(tableView, numberOfRowsInSection: section) + (section == authenticationSection ? displayedSSHKeyRows.count : 0)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let row = repositoryRow(at: indexPath) {
            return repositoryCell(for: row)
        }
        guard let row = sshKeyRow(at: indexPath) else {
            return super.tableView(tableView, cellForRowAt: staticIndexPath(for: indexPath))
        }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.textColor = Theme.Palette.surfaceText
        cell.indentationLevel = 1
        cell.indentationWidth = 16
        cell.accessoryType = .disclosureIndicator
        switch row {
        case .importFromURL:
            cell.textLabel?.text = SSHKeyURLImportTableViewController.label
        case .importArmor:
            cell.textLabel?.text = SSHKeyArmorImportTableViewController.label
        case .importFile:
            cell.textLabel?.text = SSHKeyFileImportTableViewController.label
        case .importFileSharing:
            cell.textLabel?.text = "\(Self.label) (\((isReadyToUse() ? "Import" : "Tips").localize()))"
        case .unset:
            cell.textLabel?.text = "Unset SSH Key"
            cell.textLabel?.textColor = Theme.Palette.danger
            cell.accessoryType = .none
        }
        return cell
    }

    // Rows after the inserted SSH key options map back to the storyboard's static rows.
    private func staticIndexPath(for indexPath: IndexPath) -> IndexPath {
        guard indexPath.section == authenticationSection, indexPath.row > sshKeyRowIndex else {
            return indexPath
        }
        return IndexPath(row: indexPath.row - displayedSSHKeyRows.count, section: indexPath.section)
    }

    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        if repositoryRow(at: indexPath) != nil {
            return 0
        }
        return sshKeyRow(at: indexPath) == nil ? super.tableView(tableView, indentationLevelForRowAt: staticIndexPath(for: indexPath)) : 1
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let row = repositoryRow(at: indexPath) {
            didSelect(row)
            return
        }
        if let row = sshKeyRow(at: indexPath) {
            didSelect(row)
            return
        }
        let cell = tableView.cellForRow(at: indexPath)
        if cell == authPasswordCell {
            showsSSHKeyOptions = false
            gitAuthenticationMethod = .password
            reloadAuthenticationSection()
        } else if cell == authSSHKeyCell {
            // Choosing SSH Key reveals its options; it becomes the method once a key is set.
            showsSSHKeyOptions = true
            if hasSSHKey {
                gitAuthenticationMethod = .key
            }
            reloadAuthenticationSection()
        }
    }

    private func didSelect(_ row: SSHKeyRow) {
        switch row {
        case .importFromURL:
            performSegue(withIdentifier: "setGitSSHKeyByURLSegue", sender: self)
        case .importArmor:
            performSegue(withIdentifier: "setGitSSHKeyByArmorSegue", sender: self)
        case .importFile:
            performSegue(withIdentifier: "setGitSSHKeyByFileSegue", sender: self)
        case .importFileSharing:
            if isReadyToUse() {
                importSSHKey(using: self)
            } else {
                Utils.alert(title: "Tips".localize(), message: "SshCopyPrivateKeyToPass.".localize(), controller: self)
            }
        case .unset:
            let alert = UIAlertController.removeConfirmationAlert(title: "Unset SSH Key", message: "") { _ in
                self.passwordStore.removeGitSSHKeys()
                Defaults.gitSSHKeySource = nil
                self.gitAuthenticationMethod = .password
                self.showsSSHKeyOptions = true
                self.reloadAuthenticationSection()
            }
            present(alert, animated: true)
        }
    }

    override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    override func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    // MARK: - Segue Handlers

    @IBAction
    private func save(_: Any) {
        guard let gitURLTextFieldText = gitURLTextField.text, let gitURL = URL(string: gitURLTextFieldText.trimmed) else {
            Utils.alert(title: "CannotSave".localize(), message: "SetGitRepositoryUrl".localize(), controller: self)
            return
        }

        guard let branchName = branchNameTextField.text?.trimmed, !branchName.isEmpty else {
            Utils.alert(title: "CannotSave".localize(), message: "SpecifyBranchName.".localize(), controller: self)
            return
        }

        if let scheme = gitURL.scheme {
            switch scheme {
            case "http", "https", "ssh":
                if gitURL.user == nil, usernameTextField.text == nil {
                    Utils.alert(title: "CannotSave".localize(), message: "CannotFindUsername.".localize(), controller: self)
                    return
                }
                if let urlUsername = gitURL.user, let textFieldUsername = usernameTextField.text, urlUsername != textFieldUsername.trimmed {
                    Utils.alert(title: "CannotSave".localize(), message: "CheckEnteredUsername.".localize(), controller: self)
                    return
                }
            case "file":
                break
            default:
                Utils.alert(title: "CannotSave".localize(), message: "Protocol is not supported", controller: self)
                return
            }
        }

        let username = (gitURL.user ?? usernameTextField.text ?? "git").trimmed

        if passwordStore.repositoryExists() {
            let overwriteAlert: UIAlertController = {
                let alert = UIAlertController(title: "Overwrite?".localize(), message: "OperationWillOverwriteData.".localize(), preferredStyle: .alert)
                alert.addAction(
                    UIAlertAction(title: "Overwrite".localize(), style: .destructive) { _ in
                        self.cloneAndSegueIfSuccess(url: gitURL, branch: branchName, username: username)
                    }
                )
                alert.addAction(UIAlertAction.cancel())
                return alert
            }()
            present(overwriteAlert, animated: true)
        } else {
            cloneAndSegueIfSuccess(url: gitURL, branch: branchName, username: username)
        }
    }

    private func cloneAndSegueIfSuccess(url: URL, branch: String, username: String) {
        gitURL = url
        gitBranchName = branch
        gitUsername = username

        // Remember git credential password/passphrase temporarily, ask whether users want this after a successful clone.
        Defaults.isRememberGitCredentialPassphraseOn = true
        // swiftlint:disable:next closure_body_length
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let transferProgressBlock: (UnsafePointer<git_transfer_progress>, UnsafeMutablePointer<ObjCBool>) -> Void = { git_transfer_progress, _ in
                    let gitTransferProgress = git_transfer_progress.pointee
                    let progress = Float(gitTransferProgress.received_objects) / Float(gitTransferProgress.total_objects)
                    SVProgressHUD.showProgress(progress, status: "Cloning Remote Repository")
                }

                let checkoutProgressBlock: (String, UInt, UInt) -> Void = { _, completedSteps, totalSteps in
                    let progress = Float(completedSteps) / Float(totalSteps)
                    SVProgressHUD.showProgress(progress, status: "CheckingOutBranch".localize(self.gitBranchName))
                }

                let options = self.gitCredential.getCredentialOptions(passwordProvider: self.present)

                try self.passwordStore.cloneRepository(
                    remoteRepoURL: self.gitURL,
                    branchName: self.gitBranchName,
                    options: options,
                    transferProgressBlock: transferProgressBlock,
                    checkoutProgressBlock: checkoutProgressBlock
                )

                let gpgIDFile = self.passwordStore.storeURL.appendingPathComponent(".gpg-id").path
                guard FileManager.default.fileExists(atPath: gpgIDFile) else {
                    self.passwordStore.eraseStoreData()
                    SVProgressHUD.dismiss {
                        DispatchQueue.main.async {
                            Utils.alert(title: "Error".localize(), message: "NoProperPassRepo.".localize(), controller: self)
                        }
                    }
                    return
                }

                SVProgressHUD.dismiss {
                    self.savePassphraseAndSegue()
                }
            } catch {
                SVProgressHUD.dismiss {
                    self.passwordStore.eraseStoreData()
                    let error = error as NSError
                    var message = error.localizedDescription
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        message = "\(message)\n\("UnderlyingError".localize(underlyingError.localizedDescription))"
                    }
                    DispatchQueue.main.async {
                        Utils.alert(title: "Error".localize(), message: message, controller: self)
                    }
                }
            }
        }
    }

    private func savePassphraseAndSegue() {
        let savePassphraseAlert = UIAlertController(
            title: "Done".localize(),
            message: "WantToSaveGitCredential?".localize(),
            preferredStyle: .alert
        )
        savePassphraseAlert.addAction(
            UIAlertAction(title: "No".localize(), style: .default) { _ in
                Defaults.isRememberGitCredentialPassphraseOn = false
                self.passwordStore.gitPassword = nil
                self.passwordStore.gitSSHPrivateKeyPassphrase = nil
                self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
            }
        )
        savePassphraseAlert.addAction(
            UIAlertAction(title: "Yes".localize(), style: .destructive) { _ in
                Defaults.isRememberGitCredentialPassphraseOn = true
                self.performSegue(withIdentifier: "saveGitServerSettingSegue", sender: self)
            }
        )
        DispatchQueue.main.async {
            self.present(savePassphraseAlert, animated: true)
        }
    }

    @IBAction
    private func importSSHKey(segue: UIStoryboardSegue) {
        guard let sourceController = segue.source as? KeyImporter, sourceController.isReadyToUse() else {
            return
        }
        importSSHKey(using: sourceController)
    }

    private func importSSHKey(using keyImporter: KeyImporter) {
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                try keyImporter.importKeys()
                DispatchQueue.main.async {
                    SVProgressHUD.showSuccess(withStatus: "Imported".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                    Defaults.gitSSHKeySource = type(of: keyImporter).keySource
                    self.gitAuthenticationMethod = .key
                    self.reloadAuthenticationSection()
                }
            } catch {
                DispatchQueue.main.async {
                    Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self)
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func updateAuthenticationMethodCheckView(for method: GitAuthenticationMethod) {
        let passwordCheckView = authPasswordCell.viewWithTag(1001) as? UILabel
        let sshKeyCheckView = authSSHKeyCell.viewWithTag(1001) as? UILabel
        passwordCheckView?.textColor = Theme.Palette.surfaceText
        sshKeyCheckView?.textColor = Theme.Palette.surfaceText

        // Choosing SSH Key checks it while its key is still being set up.
        switch showsSSHKeyOptions ? .key : method {
        case .password:
            passwordCheckView?.isHidden = false
            sshKeyCheckView?.isHidden = true
        case .key:
            passwordCheckView?.isHidden = true
            sshKeyCheckView?.isHidden = false
        }
    }

    private func showGitURLFormatHelp() {
        let message = """
        https://example.com[:port]/project.git
        ssh://[user@]server[:port]/project.git
        [user@]server:project.git (no scheme)
        """
        Utils.alert(title: "Git URL Format", message: message, controller: self)
    }
}

extension GitRepositorySettingsTableViewController: KeyImporter {
    static let keySource = KeySource.itunes
    static let label = "ITunesFileSharing".localize()

    func isReadyToUse() -> Bool {
        KeyFileManager.PrivateSSH.doesKeyFileExist()
    }

    func importKeys() throws {
        try KeyFileManager.PrivateSSH.importKeyFromFileSharing()
    }
}
