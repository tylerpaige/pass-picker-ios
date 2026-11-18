//
//  EncryptionSettingsTableViewController.swift
//  pass
//
//  Settings › Encryption: the PGP key, with its import options listed in place while no key is
//  set and an "Unset PGP Key" button once one is; how the key is unlocked; how passwords are written.
//

import passKit
import SVProgressHUD
import UIKit
import YubiKit

class EncryptionSettingsTableViewController: UITableViewController {
    private enum Row {
        case key, importFromURL, importArmor, importFile, importFileSharing, unset, yubiKey
        case biometricUnlock, rememberPassphrase, asciiArmor
    }

    private let keychain = AppKeychain.shared

    private lazy var yubiKeySwitch = makeSwitch(action: #selector(toggleYubiKey))
    private lazy var biometricUnlockSwitch = makeSwitch(action: #selector(toggleBiometricUnlock))
    private lazy var asciiArmorSwitch = makeSwitch(action: #selector(toggleASCIIArmor))

    // A pull-down of durations, like a <select>.
    private lazy var rememberPassphraseButton: UIButton = {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true
        button.tintColor = Theme.Palette.surfaceText
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.menu = UIMenu(children: PGPPassphraseMemory.choices.map { duration in
            UIAction(title: PGPPassphraseMemory.label(for: duration), state: duration == PGPPassphraseMemory.duration ? .on : .off) { _ in
                PGPPassphraseMemory.duration = duration
            }
        })
        return button
    }()

    private func makeSwitch(action: Selector) -> UISwitch {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Theme.Palette.datumBackground
        uiSwitch.addTarget(self, action: action, for: .valueChanged)
        return uiSwitch
    }

    init() {
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The main Settings row's detail: the key ID, or "Not Set".
    static var keySummary: String {
        var label = "NotSet".localize()
        let keyID = (try? PGPAgent.shared.getShortKeyID()) ?? []
        if keyID.count == 1 {
            label = keyID.first ?? ""
        } else if keyID.count > 1 {
            label = "Multiple"
        }
        if Defaults.isYubiKeyEnabled {
            label += "+YubiKey"
        }
        return label
    }

    // Keys may outlive their source: it is forgotten on reinstall while the keychain keeps them.
    private var hasStoredPGPKeys: Bool {
        Defaults.pgpKeySource != nil
            || keychain.contains(key: PGPKey.PUBLIC.getKeychainKey())
            || keychain.contains(key: PGPKey.PRIVATE.getKeychainKey())
    }

    private var sections: [[Row]] {
        var keyRows = [Row.key]
        keyRows += hasStoredPGPKeys ? [.unset] : [.importFromURL, .importArmor, .importFile, .importFileSharing]
        var unlockRows = [Row]()
        if PGPPassphraseBiometrics.biometryName != nil {
            unlockRows.append(.biometricUnlock)
        }
        unlockRows.append(.rememberPassphrase)
        var sections = [keyRows, unlockRows, [.asciiArmor]]
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            sections.append([.yubiKey])
        }
        return sections
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Encryption"
        navigationItem.largeTitleDisplayMode = .never
    }

    override func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].count
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section].first {
        case .key:
            return "PGP Key"
        case .biometricUnlock, .rememberPassphrase:
            return "Passphrase"
        case .asciiArmor:
            return "New Passwords"
        default:
            return nil
        }
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        switch sections[section].first {
        case .biometricUnlock:
            let name = PGPPassphraseBiometrics.biometryName ?? ""
            return "\(name) unlocks your PGP key instead of its passphrase. The passphrase is saved for \(name) the next time you type it."
        case .rememberPassphrase:
            return "Keep the passphrase this long after it was last used."
        default:
            return nil
        }
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.textColor = Theme.Palette.surfaceText
        cell.detailTextLabel?.textColor = Theme.Palette.surfaceMuted
        switch sections[indexPath.section][indexPath.row] {
        case .key:
            cell.textLabel?.text = "PGP Key"
            cell.detailTextLabel?.text = Self.keySummary
            cell.selectionStyle = .none
        case .importFromURL:
            configureImportCell(cell, title: PGPKeyURLImportTableViewController.label)
        case .importArmor:
            configureImportCell(cell, title: PGPKeyArmorImportTableViewController.label)
        case .importFile:
            configureImportCell(cell, title: PGPKeyFileImportTableViewController.label)
        case .importFileSharing:
            let action = isReadyToUse() ? "Import" : "Tips"
            configureImportCell(cell, title: "\(Self.label) (\(action.localize()))")
        case .unset:
            cell.textLabel?.text = "Unset PGP Key"
            cell.textLabel?.textColor = Theme.Palette.danger
        case .yubiKey:
            cell.textLabel?.text = "YubiKey"
            yubiKeySwitch.isOn = Defaults.isYubiKeyEnabled
            cell.accessoryView = yubiKeySwitch
            cell.selectionStyle = .none
        case .biometricUnlock:
            cell.textLabel?.text = "Unlock with \(PGPPassphraseBiometrics.biometryName ?? "")"
            biometricUnlockSwitch.isOn = PGPPassphraseBiometrics.isEnabled
            cell.accessoryView = biometricUnlockSwitch
            cell.selectionStyle = .none
        case .rememberPassphrase:
            cell.textLabel?.text = "Remember Passphrase"
            rememberPassphraseButton.sizeToFit()
            cell.accessoryView = rememberPassphraseButton
            cell.selectionStyle = .none
        case .asciiArmor:
            cell.textLabel?.text = "Encrypt in ASCII-Armored"
            asciiArmorSwitch.isOn = Defaults.encryptInArmored
            cell.accessoryView = asciiArmorSwitch
            cell.selectionStyle = .none
        }
        return cell
    }

    // Import options sit under the key row, indented like a submenu.
    private func configureImportCell(_ cell: UITableViewCell, title: String) {
        cell.textLabel?.text = title
        cell.indentationLevel = 1
        cell.indentationWidth = 16
        cell.accessoryType = .disclosureIndicator
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section][indexPath.row] {
        case .importFromURL:
            showImporter(withIdentifier: "pgpKeyURLImport")
        case .importArmor:
            showImporter(withIdentifier: "pgpKeyArmorImport")
        case .importFile:
            showImporter(withIdentifier: "pgpKeyFileImport")
        case .importFileSharing:
            if isReadyToUse() {
                saveImportedKeys()
            } else {
                Utils.alert(title: "Tips".localize(), message: "PgpCopyPublicAndPrivateKeyToPass.".localize(), controller: self)
            }
        case .unset:
            confirmUnsetKey()
        case .asciiArmor, .biometricUnlock, .key, .rememberPassphrase, .yubiKey:
            break
        }
    }

    private func showImporter(withIdentifier identifier: String) {
        let importer = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier)
        navigationController?.pushViewController(importer, animated: true)
    }

    private func confirmUnsetKey() {
        let alert = UIAlertController.removeConfirmationAlert(title: "Unset PGP Key", message: "") { _ in
            self.keychain.removeContent(for: PGPKey.PUBLIC.getKeychainKey())
            self.keychain.removeContent(for: PGPKey.PRIVATE.getKeychainKey())
            PGPPassphraseMemory.forget()
            PGPPassphraseBiometrics.forget()
            PGPAgent.shared.uninitKeys()
            Defaults.pgpKeySource = nil
            self.tableView.reloadData()
        }
        present(alert, animated: true)
    }

    @objc
    private func toggleBiometricUnlock() {
        PGPPassphraseBiometrics.isEnabled = biometricUnlockSwitch.isOn
    }

    @objc
    private func toggleASCIIArmor() {
        Defaults.encryptInArmored = asciiArmorSwitch.isOn
    }

    @objc
    private func toggleYubiKey() {
        Defaults.isYubiKeyEnabled = yubiKeySwitch.isOn
        tableView.reloadData()
    }

    // MARK: - Importing

    // The import screens unwind here when saved.
    @IBAction
    private func savePGPKey(segue: UIStoryboardSegue) {
        guard let sourceController = segue.source as? PGPKeyImporter, sourceController.isReadyToUse() else {
            return
        }
        savePGPKey(using: sourceController)
    }

    private func savePGPKey(using keyImporter: PGPKeyImporter) {
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "FetchingPgpKey".localize())
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            Defaults.pgpKeySource = type(of: keyImporter).keySource
            do {
                // Remove exiting passphrase
                PGPPassphraseMemory.forget()
                PGPPassphraseBiometrics.forget()
                try keyImporter.importKeys()
                try PGPAgent.shared.initKeys()
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    SVProgressHUD.showSuccess(withStatus: "Success".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                    keyImporter.doAfterImport()
                }
            } catch {
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
                }
            }
        }
    }
}

extension EncryptionSettingsTableViewController: PGPKeyImporter {
    static let keySource = KeySource.itunes
    static let label = "ITunesFileSharing".localize()

    func isReadyToUse() -> Bool {
        KeyFileManager.PublicPGP.doesKeyFileExist() && KeyFileManager.PrivatePGP.doesKeyFileExist()
    }

    func importKeys() throws {
        try KeyFileManager.PublicPGP.importKeyFromFileSharing()
        try KeyFileManager.PrivatePGP.importKeyFromFileSharing()
    }

    func saveImportedKeys() {
        savePGPKey(using: self)
    }
}
