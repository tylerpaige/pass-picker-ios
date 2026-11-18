//
//  PasswordsViewController.swift
//  passAutoFillExtension
//
//  Created by Sun, Mingshen on 12/31/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import AuthenticationServices
import passKit
import UIKit

class PasswordsViewController: UIViewController {
    @IBOutlet var tableView: UITableView!

    var dataSource: PasswordsTableDataSource!
    weak var selectionDelegate: PasswordSelectionDelegate?

    lazy var searchController: UISearchController = {
        let uiSearchController = UISearchController(searchResultsController: nil)
        uiSearchController.searchBar.isTranslucent = true
        uiSearchController.obscuresBackgroundDuringPresentation = false
        uiSearchController.searchBar.sizeToFit()
        uiSearchController.searchBar.searchTextField.clearButtonMode = .whileEditing
        return uiSearchController
    }()

    lazy var searchBar: UISearchBar = self.searchController.searchBar

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        searchBar.delegate = self

        tableView.delegate = self
        tableView.dataSource = dataSource

        view.backgroundColor = Theme.Palette.chrome
        tableView.backgroundColor = Theme.Palette.chrome
        tableView.separatorStyle = .none
    }

    func showPasswordsWithSuggestion(matching text: String) {
        dataSource.showTableEntriesWithSuggestion(matching: text)
        tableView.reloadData()
    }
}

extension PasswordsViewController: UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange searchText: String) {
        dataSource.showTableEntries(matching: searchText)
        tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_: UISearchBar) {
        dataSource.showTableEntries(matching: "")
        tableView.reloadData()
    }
}

extension PasswordsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else {
            return
        }
        var content = header.defaultContentConfiguration()
        content.text = dataSource.tableView(tableView, titleForHeaderInSection: section)
        content.textProperties.font = Theme.mono(13, relativeTo: .footnote)
        content.textProperties.color = Theme.Palette.chromeText
        header.contentConfiguration = content
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = dataSource.tableEntry(at: indexPath)
        if entry.isDir {
            if dataSource.isTreeSection(indexPath.section) {
                dataSource.tree.toggle(at: indexPath.row)
                UIView.transition(with: tableView, duration: 0.15, options: .transitionCrossDissolve) {
                    tableView.reloadData()
                }
            }
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        selectionDelegate?.selected(password: entry)
    }
}
