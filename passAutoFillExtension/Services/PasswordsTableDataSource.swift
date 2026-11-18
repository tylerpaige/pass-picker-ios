//
//  PasswordsTableDataSource.swift
//  passAutoFillExtension
//
//  Created by Sun, Mingshen on 12/31/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit
import UIKit

class PasswordsTableDataSource: NSObject, UITableViewDataSource {
    var passwordTableEntries: [PasswordTableEntry]
    var filteredPasswordsTableEntries: [PasswordTableEntry]
    var suggestedPasswordsTableEntries: [PasswordTableEntry]

    /// Every password as a collapsible folder tree, for browsing when no suggestion fits.
    let tree = PasswordTree(parent: nil)

    var isSearching = false

    init(entries: [PasswordTableEntry] = []) {
        self.passwordTableEntries = entries
        self.filteredPasswordsTableEntries = passwordTableEntries
        self.suggestedPasswordsTableEntries = []
    }

    private var showsSuggestions: Bool {
        !isSearching && !suggestedPasswordsTableEntries.isEmpty
    }

    func isTreeSection(_ section: Int) -> Bool {
        !isSearching && section == (showsSuggestions ? 1 : 0)
    }

    func numberOfSections(in _: UITableView) -> Int {
        showsSuggestions ? 2 : 1
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        isTreeSection(section) ? tree.rows.count : flatEntries.count
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard showsSuggestions else {
            return nil
        }
        return section == 0 ? "Suggested Passwords" : "All Passwords"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath) as! PasswordTableViewCell
        let isAlternate = indexPath.row.isMultiple(of: 2) == false
        if isTreeSection(indexPath.section) {
            cell.configure(treeRow: tree.rows[indexPath.row], in: tree, isAlternate: isAlternate)
        } else {
            cell.configure(with: flatEntries[indexPath.row], isAlternate: isAlternate, showsFullPath: true)
        }
        return cell
    }

    // Suggestions or search results, listed by full path.
    private var flatEntries: [PasswordTableEntry] {
        isSearching ? filteredPasswordsTableEntries : suggestedPasswordsTableEntries
    }

    func showTableEntries(matching text: String) {
        isSearching = !text.isEmpty
        filteredPasswordsTableEntries = passwordTableEntries
            .filter { $0.matches(text) }
            .sorted { $0.passwordEntity.nameWithDir.localizedStandardCompare($1.passwordEntity.nameWithDir) == .orderedAscending }
    }

    func showTableEntriesWithSuggestion(matching text: String) {
        guard !text.isEmpty, suggestedPasswordsTableEntries.isEmpty else {
            return
        }
        suggestedPasswordsTableEntries = passwordTableEntries.filter { $0.matches(text) }
    }

    func tableEntry(at indexPath: IndexPath) -> PasswordTableEntry {
        isTreeSection(indexPath.section) ? tree.rows[indexPath.row].entry : flatEntries[indexPath.row]
    }
}
