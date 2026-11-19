//
//  GeneralSettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 9/2/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import AuthenticationServices
import passKit
import SVProgressHUD
import UIKit

class GeneralSettingsTableViewController: BasicStaticTableViewController {
    private lazy var hideUnknownSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Theme.Palette.datumBackground
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(hideUnknownSwitchAction), for: UIControl.Event.valueChanged)
        return uiSwitch
    }()

    private lazy var hideOTPSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Theme.Palette.datumBackground
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(hideOTPSwitchAction), for: UIControl.Event.valueChanged)
        return uiSwitch
    }()

    private lazy var autoCopyOTPSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Theme.Palette.datumBackground
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(autoCopyOTPSwitchAction), for: UIControl.Event.valueChanged)
        return uiSwitch
    }()

    private lazy var enableGPGIDSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Theme.Palette.datumBackground
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(enableGPGIDSwitchAction), for: UIControl.Event.valueChanged)
        uiSwitch.isOn = Defaults.isEnableGPGIDOn
        return uiSwitch
    }()

    private lazy var autoResizePanesSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.onTintColor = Theme.Palette.datumBackground
        uiSwitch.sizeToFit()
        uiSwitch.addTarget(self, action: #selector(autoResizePanesSwitchAction), for: UIControl.Event.valueChanged)
        uiSwitch.isOn = Defaults.isAutoResizePanesOn
        return uiSwitch
    }()

    private let autoResizePanesTitle = "Resize Panes on Focus"
    private let suggestionsSection = 2

    override func viewDidLoad() {
        // The repository and passphrase settings live in Password Repository and Encryption.
        tableData = [
            [
                [.title: "EnableGPGID".localize(), .action: "none"],
                [.title: "HideUnknownFields".localize(), .action: "none"],
                [.title: "HideOtpFields".localize(), .action: "none"],
                [.title: "AutoCopyOTP".localize(), .action: "none"],
            ],
            [
                [.title: autoResizePanesTitle, .action: "none"],
            ],
            [
                [.title: "Clear Saved Suggestions", .action: "none", .accessoryType: UITableViewCell.AccessoryType.none],
            ],
        ]
        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.accessoryType = .none
        cell.selectionStyle = .none
        switch cell.textLabel!.text! {
        case "HideUnknownFields".localize():
            hideUnknownSwitch.isOn = Defaults.isHideUnknownOn
            addDetailButton(to: cell, for: hideUnknownSwitch, with: #selector(tapHideUnknownSwitchDetailButton))
        case "HideOtpFields".localize():
            hideOTPSwitch.isOn = Defaults.isHideOTPOn
            addDetailButton(to: cell, for: hideOTPSwitch, with: #selector(tapHideOTPSwitchDetailButton))
        case "EnableGPGID".localize():
            cell.accessoryView = enableGPGIDSwitch
        case autoResizePanesTitle:
            cell.accessoryView = autoResizePanesSwitch
        case "Clear Saved Suggestions":
            cell.selectionStyle = .default
        case "AutoCopyOTP".localize():
            autoCopyOTPSwitch.isOn = Defaults.autoCopyOTP
            addDetailButton(to: cell, for: autoCopyOTPSwitch, with: #selector(tapAutoCopyOTPSwitchDetailButton))
        default:
            break
        }
        return cell
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            return "Switching between the file explorer and the entry makes the one you switch to as large as it can be, "
                + "and the other as small."
        }
        guard section == suggestionsSection else {
            return nil
        }
        return "When you fill a password with AutoFill, Pass Picker remembers it for that app or website "
            + "and suggests it above the keyboard next time. Clearing removes these suggestions; your passwords stay as they are."
    }

    override func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        UITableView.automaticDimension
    }

    override func tableView(_: UITableView, estimatedHeightForFooterInSection _: Int) -> CGFloat {
        60
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard tableView.cellForRow(at: indexPath)?.textLabel?.text == "Clear Saved Suggestions" else {
            return
        }
        ASCredentialIdentityStore.shared.removeAllCredentialIdentities { _, error in
            if let error {
                SVProgressHUD.showError(withStatus: "FailedToClearQuickTypeSuggestions".localize(error))
            } else {
                SVProgressHUD.showSuccess(withStatus: "Done".localize())
            }
            SVProgressHUD.dismiss(withDelay: 1)
        }
    }

    private func addDetailButton(to cell: UITableViewCell, for uiSwitch: UISwitch, with action: Selector) {
        let detailButton = UIButton(type: .detailDisclosure)
        uiSwitch.frame = CGRect(
            x: detailButton.bounds.width + 10,
            y: 0,
            width: uiSwitch.bounds.width,
            height: uiSwitch.bounds.height
        )
        detailButton.frame = CGRect(
            x: 0,
            y: 5,
            width: detailButton.bounds.width,
            height: detailButton.bounds.height
        )
        detailButton.addTarget(self, action: action, for: UIControl.Event.touchDown)
        let accessoryViewFrame = CGRect(
            x: 0,
            y: 0,
            width: detailButton.bounds.width + uiSwitch.bounds.width + 10,
            height: cell.contentView.bounds.height
        )
        let accessoryView = UIView(frame: accessoryViewFrame)
        accessoryView.addSubview(detailButton)
        accessoryView.addSubview(uiSwitch)
        uiSwitch.center.y = accessoryView.center.y
        detailButton.center.y = accessoryView.center.y
        cell.accessoryView = accessoryView
    }

    @objc
    func tapHideUnknownSwitchDetailButton(_: Any?) {
        let alertMessage = "HideUnknownFieldsExplanation.".localize()
        let alertTitle = "HideUnknownFields".localize()
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }

    @objc
    func tapHideOTPSwitchDetailButton(_: Any?) {
        let keywordsString = Constants.OTP_KEYWORDS.joined(separator: ", ")
        let alertMessage = "HideOtpFieldsExplanation.".localize(keywordsString)
        let alertTitle = "HideOtpFields".localize()
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }

    @objc
    func tapAutoCopyOTPSwitchDetailButton(_: Any?) {
        let alertMessage = "AutoCopyOTPExplanation.".localize()
        let alertTitle = "AutoCopyOTP".localize()
        Utils.alert(title: alertTitle, message: alertMessage, controller: self, completion: nil)
    }

    @objc
    func hideUnknownSwitchAction(_: Any?) {
        Defaults.isHideUnknownOn = hideUnknownSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }

    @objc
    func hideOTPSwitchAction(_: Any?) {
        Defaults.isHideOTPOn = hideOTPSwitch.isOn
        NotificationCenter.default.post(name: .passwordDetailDisplaySettingChanged, object: nil)
    }

    @objc
    func autoCopyOTPSwitchAction(_: Any?) {
        Defaults.autoCopyOTP = autoCopyOTPSwitch.isOn
    }

    @objc
    func autoResizePanesSwitchAction(_: Any?) {
        Defaults.isAutoResizePanesOn = autoResizePanesSwitch.isOn
    }

    @objc
    func enableGPGIDSwitchAction(_: Any?) {
        Defaults.isEnableGPGIDOn = enableGPGIDSwitch.isOn
    }
}
