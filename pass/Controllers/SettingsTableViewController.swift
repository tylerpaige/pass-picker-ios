//
//  SettingsTableViewController.swift
//  pass
//
//  Created by Mingshen Sun on 18/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import CoreData
import passKit
import SVProgressHUD
import UIKit

class SettingsTableViewController: UITableViewController, UITabBarControllerDelegate {
    @IBOutlet var pgpKeyTableViewCell: UITableViewCell!
    @IBOutlet var passwordRepositoryTableViewCell: UITableViewCell!
    @IBOutlet var eraseDataTableViewCell: UITableViewCell!

    func tabBarController(_: UITabBarController, didSelect _: UIViewController) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction
    private func saveGitServerSetting(segue _: UIStoryboardSegue) {
        passwordRepositoryTableViewCell.detailTextLabel?.text = Defaults.gitURL.host
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(actOnPasswordStoreErasedNotification), name: .passwordStoreErased, object: nil)
        passwordRepositoryTableViewCell.detailTextLabel?.text = Defaults.gitURL.host
        // The PGP key lives in the Encryption panel; this row opens it.
        pgpKeyTableViewCell.textLabel?.text = "Encryption"
        pgpKeyTableViewCell.accessoryType = .disclosureIndicator
        // Set here: the localized storyboard strings would still call this row "About".
        eraseDataTableViewCell.textLabel?.text = "Erase All Data"
        setPGPKeyTableViewCellDetailText()
    }

    override func viewWillAppear(_: Bool) {
        super.viewWillAppear(true)
        tabBarController?.delegate = self
        setPasswordRepositoryTableViewCellDetailText()
        setPGPKeyTableViewCellDetailText()
    }

    private func setPGPKeyTableViewCellDetailText() {
        pgpKeyTableViewCell.detailTextLabel?.text = EncryptionSettingsTableViewController.keySummary
    }

    private func setPasswordRepositoryTableViewCellDetailText() {
        let host: String? = {
            let gitURL = Defaults.gitURL
            if gitURL.scheme == nil {
                return URL(string: "scheme://" + gitURL.absoluteString)?.host
            }
            return gitURL.host
        }()
        passwordRepositoryTableViewCell.detailTextLabel?.text = host
    }

    @objc
    func actOnPasswordStoreErasedNotification() {
        setPGPKeyTableViewCellDetailText()
        setPasswordRepositoryTableViewCellDetailText()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        if cell == eraseDataTableViewCell {
            cell.textLabel?.textColor = Theme.Palette.danger
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)

        if cell == pgpKeyTableViewCell {
            navigationController?.pushViewController(EncryptionSettingsTableViewController(), animated: true)
        } else if cell == eraseDataTableViewCell {
            confirmEraseData()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    override func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    private func confirmEraseData() {
        let alert = UIAlertController(title: "ErasePasswordStoreData?".localize(), message: "EraseExplanation.".localize(), preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: "ErasePasswordStoreData".localize(), style: .destructive) { _ in
                SVProgressHUD.show(withStatus: "Erasing...".localize())
                PasswordStore.shared.erase()
                SVProgressHUD.showSuccess(withStatus: "Done".localize())
                SVProgressHUD.dismiss(withDelay: 1)
            }
        )
        alert.addAction(UIAlertAction.dismiss())
        present(alert, animated: true)
    }
}
