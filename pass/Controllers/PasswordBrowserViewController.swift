//
//  PasswordBrowserViewController.swift
//  pass
//
//  Pass Picker's two-pane layout: the folder tree beside the open entry on wide screens,
//  above it on narrow ones, with a draggable divider between them. The pane without keyboard
//  focus is dimmed, and ⌥⌘← / ⌥⌘→ move the focus, as in Pass Picker.
//

import passKit
import UIKit

class PasswordBrowserViewController: UIViewController {
    private enum Layout {
        case sideBySide, stacked
    }

    /// Which pane the keyboard drives, like Pass Picker's focus zone.
    private enum FocusZone {
        case list, entry
    }

    // Pane sizes and spacing, after Pass Picker.
    private static let sideBySideMinWidth: CGFloat = 640
    private static let minListWidth: CGFloat = 200
    private static let maxListWidth: CGFloat = 560
    private static let minDetailWidth: CGFloat = 260
    private static let minListHeight: CGFloat = 160
    private static let minDetailHeight: CGFloat = 180
    private static let paneMargin: CGFloat = 12
    private static let dividerThickness: CGFloat = 2
    private static let gapBeforeDivider: CGFloat = 8
    private static let gapAfterDivider: CGFloat = 4
    private static let barHeight: CGFloat = 32
    private static let dimmedAlpha: CGFloat = 0.3

    let listViewController: PasswordNavigationViewController
    private(set) var detailViewController: PasswordDetailTableViewController?
    private var settingsViewController: UIViewController?

    private let listPane = UIView()
    private let detailBackdrop = UIView()
    private let detailPane = UIView()
    private let placeholderLabel = UILabel()
    private let divider = PaneDivider()
    // Over the pane without the keyboard: a tap there only moves the focus, as in Pass Picker.
    private let listShield = UIView()
    private let detailShield = UIView()

    private let titleButton = PaneTextButton(title: "Pass Picker", color: Theme.Palette.sidebarControls)
    private let pickerButton = PaneTextButton(title: "Picker", color: Theme.Palette.chromeText)
    private let settingsButton = PaneTextButton(title: "Settings", color: Theme.Palette.chromeText)
    private let searchBar = UISearchBar()
    private let clearSearchButton = PaneTextButton(title: "Clear", color: Theme.Palette.sidebarControls)
    private let deleteButton = PaneTextButton(title: "Delete (cmd+d)", color: Theme.Palette.chromeText)
    private let editButton = PaneTextButton(title: "Edit (cmd+e)", color: Theme.Palette.chromeText)
    private let newButton = PaneTextButton(title: "New (cmd+n)", color: Theme.Palette.chromeText)

    // Share of the width (side by side) or height (stacked) given to the list.
    private var sideBySideFraction: CGFloat = 0.5
    private var stackedFraction: CGFloat = 0.45
    private var layout = Layout.stacked
    private var dragStartFraction: CGFloat = 0
    private var focusZone = FocusZone.list {
        didSet {
            updateDimming()
            if focusZone != oldValue {
                resizePanesForFocus()
            }
        }
    }

    /// Makes the browser the app's root, replacing the storyboard's Passwords/Settings tab bar.
    /// Settings opens as a sheet from the header instead.
    static func install(in window: UIWindow?) {
        guard let tabBarController = window?.rootViewController as? UITabBarController,
              let navigationController = tabBarController.viewControllers?.first as? UINavigationController,
              let list = navigationController.viewControllers.first as? PasswordNavigationViewController else {
            return
        }
        let settings = tabBarController.viewControllers?.dropFirst().first
        tabBarController.viewControllers = []

        let browser = PasswordBrowserViewController(list: list)
        browser.settingsViewController = settings
        navigationController.setViewControllers([browser], animated: false)
        window?.rootViewController = navigationController
    }

    init(list: PasswordNavigationViewController) {
        self.listViewController = list
        super.init(nibName: nil, bundle: nil)
        // The list drives this field as its search bar.
        list.searchBar = searchBar
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Palette.chrome
        detailBackdrop.backgroundColor = Theme.Palette.chromeAlt
        for pane in [listPane, detailPane] {
            pane.layer.cornerRadius = 16
            pane.clipsToBounds = true
        }
        listPane.backgroundColor = Theme.Palette.treeA
        detailPane.backgroundColor = Theme.Palette.surface

        placeholderLabel.text = "Select an entry to view"
        placeholderLabel.font = Theme.mono(14, relativeTo: .footnote)
        placeholderLabel.textColor = Theme.Palette.surfaceMuted
        placeholderLabel.textAlignment = .center
        detailPane.addSubview(placeholderLabel)

        configureSearchBar()
        titleButton.contentHorizontalAlignment = .leading
        pickerButton.contentHorizontalAlignment = .leading
        settingsButton.contentHorizontalAlignment = .trailing
        titleButton.addTarget(self, action: #selector(showSyncFilter), for: .touchUpInside)
        pickerButton.addTarget(self, action: #selector(showSyncFilter), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteEntry), for: .touchUpInside)
        editButton.addTarget(self, action: #selector(editEntry), for: .touchUpInside)
        newButton.addTarget(self, action: #selector(newEntry), for: .touchUpInside)

        let subviews = [
            detailBackdrop, listPane, detailPane, listShield, detailShield, divider,
            titleButton, pickerButton, settingsButton, searchBar, clearSearchButton, deleteButton, editButton, newButton,
        ]
        for subview in subviews {
            view.addSubview(subview)
        }
        divider.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragDivider)))
        listShield.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focusList)))
        detailShield.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focusDetail)))

        addChild(listViewController)
        listViewController.view.frame = listPane.bounds
        listViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        listPane.addSubview(listViewController.view)
        listViewController.didMove(toParent: self)

        updateFooter()
        updateDimming()
        // The app opens on the file explorer, so with the setting on it opens large.
        resizePanesForFocus(animated: false)
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(updateHeader), name: .passwordStoreUpdated, object: nil)
        notificationCenter.addObserver(self, selector: #selector(updateHeader), name: .passwordStoreSyncSucceeded, object: nil)
    }

    // Pass Picker's search field: bare light-green text on the chrome, no capsule or magnifier.
    private func configureSearchBar() {
        let color = Theme.Palette.sidebarControls
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.setSearchFieldBackgroundImage(UIImage(), for: .normal)
        searchBar.returnKeyType = .done
        searchBar.tintColor = color

        let field = searchBar.searchTextField
        field.leftView = nil
        field.leftViewMode = .never
        field.clearButtonMode = .never
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.font = PaneTextButton.font
        field.textColor = color
        // Typed text keeps the color too, rather than the system's black.
        field.defaultTextAttributes = [.foregroundColor: color, .font: PaneTextButton.font]
        field.typingAttributes = field.defaultTextAttributes
        field.attributedPlaceholder = NSAttributedString(
            string: "search (cmd+f)",
            attributes: [.foregroundColor: color.withAlphaComponent(0.8), .font: PaneTextButton.font]
        )
        clearSearchButton.titleLabel?.font = Theme.mono(11, relativeTo: .caption2)
        clearSearchButton.addTarget(self, action: #selector(cancelSearch), for: .touchUpInside)
        searchTextDidChange()
    }

    /// "Clear" shows at the right end of the search field while it has text.
    func searchTextDidChange() {
        clearSearchButton.isHidden = searchBar.text?.isEmpty ?? true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        updateHeader()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Screens pushed from here (folders outside the tree) keep their own bar.
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let area = view.bounds.inset(by: view.safeAreaInsets)
        layout = area.width >= Self.sideBySideMinWidth ? .sideBySide : .stacked
        divider.isVertical = layout == .sideBySide
        pickerButton.isHidden = layout == .stacked
        updateHeader()

        switch layout {
        case .sideBySide:
            layoutSideBySide(in: area)
        case .stacked:
            layoutStacked(in: area)
        }
        let settingsWidth = settingsButton.intrinsicContentSize.width
        settingsButton.frame = CGRect(x: area.maxX - Self.paneMargin - settingsWidth, y: area.minY, width: settingsWidth, height: Self.barHeight)
        placeholderLabel.frame = detailPane.bounds
        listShield.frame = listPane.frame
        detailShield.frame = detailPane.frame
    }

    /// Bottom of the footer row: clear of the home indicator without doubling its inset.
    private func footerY(in area: CGRect) -> CGFloat {
        min(area.maxY, view.bounds.maxY - 8) - Self.barHeight
    }

    // Tree above the entry; title and search over the tree, footer under the entry.
    private func layoutStacked(in area: CGRect) {
        let margin = Self.paneMargin
        let bar = Self.barHeight
        let width = area.width - 2 * margin
        titleButton.frame = CGRect(x: area.minX + margin, y: area.minY, width: width - settingsButton.intrinsicContentSize.width - 12, height: bar)
        searchBar.frame = CGRect(x: area.minX + margin, y: titleButton.frame.maxY, width: width, height: bar)
        alignSearchText(to: titleButton.frame.minX)
        layoutClearSearchButton(rightEdge: settingsButton.frame.maxX)

        let listTop = searchBar.frame.maxY + 4
        let footerY = footerY(in: area)
        let gaps = Self.gapBeforeDivider + Self.dividerThickness + Self.gapAfterDivider
        let panesHeight = footerY - listTop - gaps
        let listHeight = clamp(panesHeight * stackedFraction, Self.minListHeight, panesHeight - Self.minDetailHeight)
        listPane.frame = CGRect(x: area.minX + margin, y: listTop, width: width, height: listHeight)
        divider.frame = CGRect(x: area.minX, y: listPane.frame.maxY + Self.gapBeforeDivider, width: area.width, height: Self.dividerThickness)
        detailBackdrop.frame = CGRect(x: 0, y: divider.frame.midY, width: view.bounds.width, height: view.bounds.maxY - divider.frame.midY)
        let detailTop = divider.frame.maxY + Self.gapAfterDivider
        detailPane.frame = CGRect(x: area.minX + margin, y: detailTop, width: width, height: footerY - detailTop)
        layoutFooter(in: CGRect(x: detailPane.frame.minX, y: footerY, width: width, height: bar))
    }

    // Tree beside the entry, with "Pass" | "Picker" over the two panes and search under the tree.
    private func layoutSideBySide(in area: CGRect) {
        let margin = Self.paneMargin
        let bar = Self.barHeight
        let maxWidth = min(Self.maxListWidth, area.width - Self.minDetailWidth)
        let dividerX = area.minX + clamp(area.width * sideBySideFraction, Self.minListWidth, maxWidth)
        let top = area.minY + bar
        let footerY = footerY(in: area)

        listPane.frame = CGRect(x: area.minX + margin, y: top + 4, width: dividerX - 2 - area.minX - margin, height: footerY - top - 4)
        divider.frame = CGRect(x: dividerX, y: top, width: Self.dividerThickness, height: footerY - top)
        detailBackdrop.frame = CGRect(x: divider.frame.midX, y: 0, width: view.bounds.maxX - divider.frame.midX, height: view.bounds.height)
        let detailX = divider.frame.maxX + 2
        detailPane.frame = CGRect(x: detailX, y: top + 4, width: area.maxX - margin - detailX, height: footerY - top - 4)

        let titleWidth = titleButton.intrinsicContentSize.width
        titleButton.frame = CGRect(x: dividerX - 6 - titleWidth, y: area.minY, width: titleWidth, height: bar)
        pickerButton.frame = CGRect(x: detailX, y: area.minY, width: detailPane.frame.width - settingsButton.intrinsicContentSize.width - 12, height: bar)
        searchBar.frame = CGRect(x: listPane.frame.minX, y: footerY, width: listPane.frame.width, height: bar)
        alignSearchText(to: listPane.frame.minX + 4)
        layoutClearSearchButton(rightEdge: listPane.frame.maxX - 4)
        layoutFooter(in: CGRect(x: detailX, y: footerY, width: detailPane.frame.width, height: bar))
    }

    private func layoutClearSearchButton(rightEdge: CGFloat) {
        let size = clearSearchButton.sizeThatFits(searchBar.frame.size)
        clearSearchButton.frame = CGRect(x: rightEdge - size.width, y: searchBar.frame.midY - size.height / 2, width: size.width, height: size.height)
    }

    // Lines the search text up with the text above it, past the search bar's built-in padding.
    private func alignSearchText(to targetX: CGFloat) {
        let field = searchBar.searchTextField
        field.layoutIfNeeded()
        let current = searchBar.searchTextPositionAdjustment.horizontal
        let textX = field.convert(field.textRect(forBounds: field.bounds), to: view).minX - current
        searchBar.searchTextPositionAdjustment = UIOffset(horizontal: targetX - textX, vertical: 0)
    }

    // Delete on the left; Edit and New on the right, as in Pass Picker.
    private func layoutFooter(in frame: CGRect) {
        let deleteWidth = deleteButton.intrinsicContentSize.width
        let editWidth = editButton.intrinsicContentSize.width
        let newWidth = newButton.intrinsicContentSize.width
        deleteButton.frame = CGRect(x: frame.minX, y: frame.minY, width: deleteWidth, height: frame.height)
        newButton.frame = CGRect(x: frame.maxX - newWidth, y: frame.minY, width: newWidth, height: frame.height)
        editButton.frame = CGRect(x: newButton.frame.minX - 12 - editWidth, y: frame.minY, width: editWidth, height: frame.height)
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }

    /// With "Resize Panes on Focus" on, the focused pane grows as far as it can and the other shrinks.
    private func resizePanesForFocus(animated: Bool = true) {
        guard Defaults.isAutoResizePanesOn else {
            return
        }
        // Past the ends; the layout clamps each pane to its minimum size.
        let fraction: CGFloat = focusZone == .list ? 1 : 0
        sideBySideFraction = fraction
        stackedFraction = fraction
        view.setNeedsLayout()
        guard animated else {
            return
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            self.view.layoutIfNeeded()
        }
    }

    @objc
    private func dragDivider(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            // Start from where the divider is, not a fraction the layout clamped.
            let area = view.bounds.inset(by: view.safeAreaInsets)
            if layout == .sideBySide {
                sideBySideFraction = (divider.frame.minX - area.minX) / max(area.width, 1)
            } else {
                stackedFraction = listPane.frame.height / max(listPane.frame.height + detailPane.frame.height, 1)
            }
            dragStartFraction = layout == .sideBySide ? sideBySideFraction : stackedFraction
        }
        let translation = gesture.translation(in: view)
        switch layout {
        case .sideBySide:
            sideBySideFraction = dragStartFraction + translation.x / max(view.bounds.width, 1)
        case .stacked:
            stackedFraction = dragStartFraction + translation.y / max(listPane.frame.height + detailPane.frame.height, 1)
        }
        view.setNeedsLayout()
    }

    // MARK: - Header and footer

    /// Shows how many local changes are waiting to sync; tapping the title filters to them.
    @objc
    func updateHeader() {
        let unsynced = PasswordStore.shared.numberOfLocalCommits
        var status = ""
        if listViewController.viewingUnsyncedPasswords {
            status = " · unsynced"
        } else if unsynced > 0 {
            status = " · \(unsynced) unsynced"
        }
        if layout == .sideBySide {
            titleButton.setTitle("Pass", for: .normal)
            pickerButton.setTitle("Picker" + status, for: .normal)
        } else {
            titleButton.setTitle("Pass Picker" + status, for: .normal)
        }
    }

    private func updateFooter() {
        let hasEntry = detailViewController != nil
        deleteButton.isEnabled = hasEntry
        editButton.isEnabled = hasEntry
    }

    // The pane without the keyboard fades back, as in Pass Picker; the search field stays bright.
    private func updateDimming() {
        listViewController.showsFocus = focusZone == .list
        listShield.isHidden = focusZone == .list
        detailShield.isHidden = focusZone == .entry
        UIView.animate(withDuration: 0.15) { [self] in
            listPane.alpha = focusZone == .list ? 1 : Self.dimmedAlpha
            detailPane.alpha = focusZone == .entry ? 1 : Self.dimmedAlpha
        }
    }

    @objc
    private func showSyncFilter() {
        guard listViewController.viewingUnsyncedPasswords || PasswordStore.shared.numberOfLocalCommits > 0 else {
            return
        }
        listViewController.showSyncFilterMenu()
    }

    @objc
    func showSettings() {
        guard let settings = settingsViewController, settings.presentingViewController == nil else {
            return
        }
        let settingsNavigation = (settings as? UISplitViewController)?.viewControllers.first as? UINavigationController
        let doneItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissSettings))
        settingsNavigation?.viewControllers.first?.navigationItem.leftBarButtonItem = doneItem
        settings.modalPresentationStyle = .pageSheet
        present(settings, animated: true)
    }

    @objc
    private func dismissSettings() {
        dismiss(animated: true) {
            self.updateHeader()
            self.listViewController.becomeFirstResponder()
        }
    }

    @objc
    private func deleteEntry() {
        detailViewController?.confirmDelete()
    }

    @objc
    private func editEntry() {
        detailViewController?.openEditor(.edit)
    }

    @objc
    private func newEntry() {
        listViewController.addPasswordAction(nil)
    }

    // MARK: - Detail pane

    func showDetail(for passwordEntity: PasswordEntity, editorIntent: EditPasswordTableViewController.Intent?) {
        if let current = detailViewController, current.passwordEntity == passwordEntity {
            current.becomeFirstResponder()
            if let editorIntent {
                current.openEditor(editorIntent)
            }
            return
        }
        removeDetail()

        let detail = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "passwordDetail") as! PasswordDetailTableViewController
        detail.passwordEntity = passwordEntity
        detail.opensEditorWhenReady = editorIntent
        addChild(detail)
        detail.view.frame = detailPane.bounds
        detail.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        detailPane.addSubview(detail.view)
        detail.didMove(toParent: self)
        detailViewController = detail
        placeholderLabel.isHidden = true
        listViewController.openEntryPath = passwordEntity.path
        updateFooter()
    }

    func closeDetail() {
        removeDetail()
        listViewController.becomeFirstResponder()
    }

    private func removeDetail() {
        guard let detail = detailViewController else {
            return
        }
        detail.willMove(toParent: nil)
        detail.view.removeFromSuperview()
        detail.removeFromParent()
        detailViewController = nil
        placeholderLabel.isHidden = false
        listViewController.openEntryPath = nil
        updateFooter()
    }

    // Edit, save and delete unwind to the detail pane; everything else to the list.
    override func allowedChildrenForUnwinding(from source: UIStoryboardUnwindSegueSource) -> [UIViewController] {
        if let detail = detailViewController, detail.responds(to: source.unwindAction) {
            return [detail]
        }
        return [listViewController]
    }

    // MARK: - Keyboard focus

    /// Called by the list and the entry when they take the keyboard.
    func paneDidTakeFocus(_ pane: UIViewController) {
        focusZone = pane === listViewController ? .list : .entry
    }

    // With no entry open, the empty entry pane can still hold the focus, as in Pass Picker.
    override var canBecomeFirstResponder: Bool {
        true
    }

    override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = [
            .shortcut(UIKeyCommand.inputLeftArrow, action: #selector(focusList), modifiers: [.command, .alternate], title: "Focus Password List"),
            .shortcut(UIKeyCommand.inputRightArrow, action: #selector(focusDetail), modifiers: [.command, .alternate], title: "Focus Entry"),
            .shortcut("n", action: #selector(newEntry), modifiers: .command, title: "New Password"),
            .shortcut(",", action: #selector(showSettings), modifiers: .command, title: "Settings"),
            .shortcut("f", action: #selector(focusSearch), modifiers: .command, title: "Search"),
            .shortcut("l", action: #selector(toggleFocus), modifiers: .command, title: "Switch Pane"),
        ]
        // In the search field, as in Pass Picker: Esc clears it, ↓ moves to the first result.
        if searchBar.searchTextField.isFirstResponder {
            commands += [
                .shortcut(UIKeyCommand.inputEscape, action: #selector(cancelSearch)),
                .shortcut(UIKeyCommand.inputDownArrow, action: #selector(leaveSearchField)),
            ]
        }
        return commands
    }

    @objc
    func focusList() {
        listViewController.becomeFirstResponder()
    }

    @objc
    private func focusDetail() {
        if let detail = detailViewController {
            detail.becomeFirstResponder()
        } else if becomeFirstResponder() {
            focusZone = .entry
        }
    }

    // ⌘L: the other pane takes the keyboard.
    @objc
    private func toggleFocus() {
        if focusZone == .list {
            focusDetail()
        } else {
            focusList()
        }
    }

    @objc
    private func focusSearch() {
        listViewController.focusSearch()
    }

    @objc
    private func cancelSearch() {
        listViewController.endSearch()
    }

    @objc
    private func leaveSearchField() {
        listViewController.focusFirstRow()
    }
}

/// Plain monospaced text in the header and footer, like Pass Picker's footer links (12px at 80%).
private class PaneTextButton: UIButton {
    static let font = Theme.mono(13, relativeTo: .footnote)

    convenience init(title: String, color: UIColor) {
        self.init(type: .system)
        setTitle(title, for: .normal)
        titleLabel?.font = Self.font
        setTitleColor(color.withAlphaComponent(0.8), for: .normal)
        setTitleColor(color.withAlphaComponent(0.8 * 0.35), for: .disabled)
    }
}

/// The 2pt divider between the panes, with Pass Picker's accent grip and a finger-sized drag area.
private class PaneDivider: UIView {
    private let handle = UIView()

    var isVertical = false {
        didSet {
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        handle.backgroundColor = Theme.Palette.accent
        handle.layer.cornerRadius = 1
        addSubview(handle)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = isVertical ? CGSize(width: 3, height: 18) : CGSize(width: 18, height: 3)
        handle.frame = CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        bounds.insetBy(dx: isVertical ? -8 : 0, dy: isVertical ? 0 : -8).contains(point)
    }
}
