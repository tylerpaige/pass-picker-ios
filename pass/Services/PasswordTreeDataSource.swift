//
//  PasswordTreeDataSource.swift
//  pass
//
//  Table data source for the collapsible folder tree on the password list.
//

import passKit
import UIKit

class PasswordTreeDataSource: PasswordNavigationDataSource {
    let tree: PasswordTree

    var expandedPaths: Set<String> {
        tree.expandedPaths
    }

    init(parent: PasswordEntity?, expandedPaths: Set<String>) {
        self.tree = PasswordTree(parent: parent, expandedPaths: expandedPaths)
        super.init()
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        tree.rows.count
    }

    override func numberOfSections(in _: UITableView) -> Int {
        1
    }

    override func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        nil
    }

    override func sectionIndexTitles(for _: UITableView) -> [String]? {
        nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "passwordTableViewCell", for: indexPath) as! PasswordTableViewCell
        let row = tree.rows[indexPath.row]
        cell.configure(treeRow: row, in: tree, isAlternate: indexPath.row.isMultiple(of: 2) == false, isOpen: row.entry.passwordEntity.path == openPath)
        return cell
    }

    override func getPasswordTableEntry(at indexPath: IndexPath) -> PasswordTableEntry {
        tree.rows[indexPath.row].entry
    }
}
