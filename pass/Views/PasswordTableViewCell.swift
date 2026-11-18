//
//  PasswordTableViewCell.swift
//  pass
//
//  Created by Sun, Mingshen on 12/31/20.
//  Copyright © 2020 Bob Sun. All rights reserved.
//

import passKit

class PasswordTableViewCell: UITableViewCell {
    // Tree geometry, after Pass Picker's sidebar.
    private static let indentStep: CGFloat = 22
    private static let rowPadLeft: CGFloat = 16
    private static let caretWidth: CGFloat = 18
    private static let hierarchyWidth: CGFloat = 10

    private var depth = 0
    private var showsFullPath = false
    private var hierarchyBars = [UIView]()

    /// `showsFullPath` renders the entry's whole path, wrapped, in place of its name and category (search results).
    /// `isOpen` marks the entry shown in the browser's entry pane.
    func configure(with entry: PasswordTableEntry, depth: Int = 0, isExpanded: Bool = false, isAlternate: Bool = false, showsDetail: Bool = true, showsFullPath: Bool = false, isOpen: Bool = false) {
        self.depth = depth
        self.showsFullPath = showsFullPath
        if isOpen {
            backgroundColor = Theme.Palette.treeSelected
        } else {
            backgroundColor = isAlternate ? Theme.Palette.treeB : Theme.Palette.treeA
        }
        selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = Theme.Palette.treeFocused
            return view
        }()
        accessoryType = .none

        let caret = entry.isDir ? (isExpanded ? "▾ " : "▸ ") : ""
        let unsynced = entry.passwordEntity.isSynced ? "" : "↻ "
        let font = Theme.mono(16)
        let text = NSMutableAttributedString(
            string: caret,
            // Pass Picker draws the folder caret at 70%.
            attributes: [.font: font, .foregroundColor: Theme.Palette.sidebarText.withAlphaComponent(0.7)]
        )
        text.append(NSAttributedString(
            string: unsynced + (showsFullPath ? entry.passwordEntity.nameWithDir : entry.title),
            attributes: [.font: font, .foregroundColor: Theme.Palette.sidebarText]
        ))
        textLabel?.attributedText = text
        textLabel?.numberOfLines = showsFullPath ? 0 : 1
        textLabel?.adjustsFontForContentSizeCategory = true

        detailTextLabel?.font = Theme.mono(13, relativeTo: .footnote)
        detailTextLabel?.textColor = Theme.Palette.sidebarMuted
        detailTextLabel?.adjustsFontForContentSizeCategory = true
        if showsDetail, !showsFullPath {
            detailTextLabel?.text = entry.isDir ? "\(entry.passwordEntity.children.count)" : entry.categoryText
        } else {
            // The tree itself shows where an entry lives.
            detailTextLabel?.text = nil
        }

        updateHierarchyBars()
        setNeedsLayout()
    }

    private func updateHierarchyBars() {
        while hierarchyBars.count < depth {
            let bar = UIView()
            bar.backgroundColor = Theme.Palette.hierarchy
            contentView.insertSubview(bar, at: 0)
            hierarchyBars.append(bar)
        }
        for (level, bar) in hierarchyBars.enumerated() {
            bar.isHidden = level >= depth
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = contentView.bounds.height
        for (level, bar) in hierarchyBars.enumerated() where level < depth {
            // Centered under the ancestor folder's caret
            let barX = CGFloat(level) * Self.indentStep + Self.rowPadLeft + (Self.caretWidth - Self.hierarchyWidth) / 2
            bar.frame = CGRect(x: barX, y: 0, width: Self.hierarchyWidth, height: height)
        }

        // Wrapped full paths keep the system layout so their height matches the label.
        guard let textLabel, !showsFullPath else {
            return
        }
        let leading = CGFloat(depth) * Self.indentStep + Self.rowPadLeft
        let trailing = detailTextLabel.map { $0.text?.isEmpty == false ? $0.frame.minX - 8 : contentView.bounds.width - 16 } ?? contentView.bounds.width - 16
        textLabel.frame = CGRect(x: leading, y: textLabel.frame.minY, width: max(0, trailing - leading), height: textLabel.frame.height)
    }

    // Keep the hierarchy bars visible while the row is highlighted or keyboard-focused.
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        hierarchyBars.forEach { $0.backgroundColor = Theme.Palette.hierarchy }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        hierarchyBars.forEach { $0.backgroundColor = Theme.Palette.hierarchy }
    }
}
