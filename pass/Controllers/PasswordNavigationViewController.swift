//
//  PasswordNavigationViewController.swift
//  pass
//
//  Created by Mingshen Sun on 17/1/2021.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import passKit
import SVProgressHUD
import UIKit
import UserNotifications

extension UIStoryboard {
    static var passwordNavigationViewController: PasswordNavigationViewController {
        UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "passwordNavigation") as! PasswordNavigationViewController
    }
}

class PasswordNavigationViewController: UIViewController {
    @IBOutlet var tableView: UITableView!

    var dataSource: PasswordNavigationDataSource?
    var parentPasswordEntity: PasswordEntity? {
        didSet {
            parentPath = parentPasswordEntity?.path
        }
    }

    // preserve parent path so it can be reloaded even if the parentPasswordEntity is deleted during the update process
    private var parentPath: String?

    // Folders expanded in the tree; kept across reloads so a sync doesn't collapse everything.
    private var expandedPaths = Set<String>()

    // Set when ⌘E opens an entry, so its detail screen goes straight to the editor.
    private var editorIntentOnShow: EditPasswordTableViewController.Intent?

    /// Folder for the next new password; unset means the folder on screen.
    private var newPasswordFolderOverride: String??

    /// Entry open beside the list, highlighted in the tree.
    var openEntryPath: String? {
        didSet {
            dataSource?.openPath = openEntryPath
            // Reloading drops the selection, which is the keyboard focus.
            let focused = tableView?.indexPathForSelectedRow
            tableView?.reloadData()
            tableView?.selectRow(at: focused, animated: false, scrollPosition: .none)
        }
    }

    /// Pass Picker marks the focused row only while the tree has the keyboard.
    var showsFocus = true {
        didSet {
            tableView.visibleCells.forEach(updateFocusHighlight)
        }
    }

    private func updateFocusHighlight(_ cell: UITableViewCell) {
        cell.selectedBackgroundView?.backgroundColor = showsFocus ? Theme.Palette.treeFocused : cell.backgroundColor
    }

    private var browser: PasswordBrowserViewController? {
        parent as? PasswordBrowserViewController
    }

    var viewingUnsyncedPasswords = false
    var tapTabBarTime: TimeInterval = 0
    var searchText: String?

    lazy var passwordManager = PasswordManager(viewController: self)

    lazy var searchController: UISearchController = {
        let uiSearchController = UISearchController(searchResultsController: nil)
        uiSearchController.searchBar.isTranslucent = true
        uiSearchController.obscuresBackgroundDuringPresentation = false
        uiSearchController.searchBar.sizeToFit()
        uiSearchController.searchBar.returnKeyType = .done
        uiSearchController.searchBar.searchTextField.clearButtonMode = .whileEditing
        return uiSearchController
    }()

    lazy var searchBar: UISearchBar = self.searchController.searchBar

    /// Whether the search field is the two-pane browser's own, rather than the search controller's.
    private var usesEmbeddedSearchBar: Bool {
        browser != nil
    }

    private var isSearching: Bool {
        usesEmbeddedSearchBar ? dataSource?.isSearchActive == true : searchController.isActive
    }

    private func beginSearch() {
        if !usesEmbeddedSearchBar {
            searchController.isActive = true
        }
    }

    /// After picking a result: the browser keeps its results listed beside the entry.
    private func leaveSearch() {
        if usesEmbeddedSearchBar {
            searchBar.resignFirstResponder()
        } else {
            searchController.isActive = false
        }
    }

    /// Clears the search and shows the whole tree again.
    func endSearch() {
        if usesEmbeddedSearchBar {
            searchBar.text = nil
            searchBar.resignFirstResponder()
            browser?.searchTextDidChange()
        } else {
            searchController.isActive = false
        }
        cancelSearch()
    }

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
        return refreshControl
    }()

    lazy var addPasswordUIBarButtonItem = UIBarButtonItem(title: "New", style: .plain, target: self, action: #selector(addPasswordAction))

    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self
        configureAppearance()
        configureTableView(in: parentPasswordEntity)
        configureNotification()
        configureSearchBar()
        configureNavigationBar()
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        // Ask for permission to receive notifications
        let notificationCenter = UNUserNotificationCenter.current()
        let permissionOptions = UNAuthorizationOptions(arrayLiteral: .alert)
        notificationCenter.requestAuthorization(options: permissionOptions) { _, _ in }

        // Register notification action
        let copyAction = UNNotificationAction(
            identifier: Globals.otpNotificationCopyAction,
            title: "CopyToPasteboard".localize(),
            options: UNNotificationActionOptions(rawValue: 0)
        )
        let otpCategory = UNNotificationCategory(
            identifier: Globals.otpNotificationCategory,
            actions: [copyAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            options: []
        )
        notificationCenter.setNotificationCategories([otpCategory])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.delegate = self
        configureNavigationItem()
        configureTabBarItem()
        configureNavigationBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Receive hardware keyboard shortcuts.
        if !isSearching {
            becomeFirstResponder()
        }
        if let text = searchText, !text.isEmpty {
            DispatchQueue.main.async {
                self.searchBar.text = text
                self.beginSearch()
                self.searchBar.becomeFirstResponder()
            }
        }
    }

    private func configureAppearance() {
        // In the browser the tree sits on its own rounded card.
        let background = browser == nil ? Theme.Palette.chrome : .clear
        view.backgroundColor = background
        tableView.backgroundColor = background
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
            // The table's own keyboard focus would take ↑/↓ before the tree's shortcuts.
            tableView.allowsFocus = false
        }
        tableView.separatorStyle = .none
        tableView.sectionIndexColor = Theme.Palette.sidebarText
        tableView.sectionIndexBackgroundColor = .clear

        // The browser styles its own search field.
        guard !usesEmbeddedSearchBar else {
            return
        }
        let searchField = searchBar.searchTextField
        searchField.font = Theme.mono(16)
        searchField.textColor = Theme.Palette.chromeText
        searchField.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        searchField.leftView?.tintColor = Theme.Palette.chromeText.withAlphaComponent(0.6)
        searchField.attributedPlaceholder = NSAttributedString(
            string: "search",
            attributes: [.foregroundColor: Theme.Palette.chromeText.withAlphaComponent(0.6), .font: Theme.mono(16)]
        )
        searchBar.tintColor = Theme.Palette.chromeText
    }

    private func configureSearchBar() {
        if !usesEmbeddedSearchBar {
            searchBar.scopeButtonTitles = SearchBarScope.allCases.map(\.localizedName)
        } else {
            searchBar.scopeButtonTitles = nil
        }
    }

    private func configureTableView(in dir: PasswordEntity?) {
        configureTableViewDataSource(in: dir, isShowFolder: true, asTree: true)
        tableView.delegate = self
        tableView.layoutIfNeeded()
        tableView.contentInset.top = 8
        let atribbutedTitle = "LastSynced".localize() + ": \(PasswordStore.shared.lastSyncedTimeString)"
        refreshControl.attributedTitle = NSAttributedString(
            string: atribbutedTitle,
            attributes: [.foregroundColor: Theme.Palette.chromeText, .font: Theme.mono(12, relativeTo: .footnote)]
        )
        tableView.refreshControl = refreshControl
    }

    private func configureTableViewDataSource(in dir: PasswordEntity?, isShowFolder: Bool, asTree: Bool = false) {
        if isShowFolder, asTree {
            dataSource = PasswordTreeDataSource(parent: dir, expandedPaths: expandedPaths)
            dataSource?.openPath = openEntryPath
            tableView.dataSource = dataSource
            return
        }
        var passwordTableEntries: [PasswordTableEntry]
        if isShowFolder {
            passwordTableEntries = PasswordStore.shared.fetchPasswordEntityCoreData(parent: dir).compactMap { PasswordTableEntry($0) }
        } else {
            passwordTableEntries = PasswordStore.shared.fetchPasswordEntityCoreData(withDir: false).compactMap { PasswordTableEntry($0) }
        }
        dataSource = PasswordNavigationDataSource(entries: passwordTableEntries)
        dataSource?.openPath = openEntryPath
        tableView.dataSource = dataSource
    }

    private func configureTabBarItem() {
        guard let tabBarItem = navigationController?.tabBarItem else {
            return
        }
        if #available(iOS 15.0, *) {
            tabBarItem.scrollEdgeAppearance = tabBarItem.standardAppearance
        }

        let numberOfLocalCommits = PasswordStore.shared.numberOfLocalCommits
        if numberOfLocalCommits != 0 {
            tabBarItem.badgeValue = "\(numberOfLocalCommits)"
        } else {
            tabBarItem.badgeValue = nil
        }
    }

    private func configureNavigationItem() {
        if isRootViewController() {
            // The two-pane browser needs the height a large title would take.
            navigationItem.largeTitleDisplayMode = browser == nil ? .automatic : .never
            navigationItem.title = "PasswordStore".localize()
        } else {
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.title = parentPasswordEntity?.name
        }
        if viewingUnsyncedPasswords {
            navigationItem.title = "Unsynced"
        }

        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.rightBarButtonItem = addPasswordUIBarButtonItem
        navigationItem.searchController = usesEmbeddedSearchBar ? nil : searchController
    }

    private func configureNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }

        guard PasswordStore.shared.numberOfLocalCommits != 0 else {
            return
        }

        let tapNavigationBarGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapNavigationBar))
        tapNavigationBarGestureRecognizer.cancelsTouchesInView = false
        navigationBar.addGestureRecognizer(tapNavigationBarGestureRecognizer)
    }

    private func isRootViewController() -> Bool {
        navigationController?.viewControllers.count == 1
    }

    private func configureNotification() {
        let notificationCenter = NotificationCenter.default
        // Reset the data table if some password (maybe another one) has been updated.
        notificationCenter.addObserver(self, selector: #selector(actOnPossiblePasswordStoreUpdate), name: .passwordStoreUpdated, object: nil)
        // Reset the data table if the disaply settings have been changed.
        // Search entrypoint for home screen quick action.
        notificationCenter.addObserver(self, selector: #selector(actOnSearchNotification), name: .passwordSearch, object: nil)
        // A Siri shortcut can change the state of the app in the background. Hence, reload when opening the app.
        notificationCenter.addObserver(self, selector: #selector(actOnPossiblePasswordStoreUpdate), name: UIApplication.willEnterForegroundNotification, object: nil)
        // Sync with remote done.
        notificationCenter.addObserver(self, selector: #selector(actOnPasswordStoreSyncSucceeded), name: .passwordStoreSyncSucceeded, object: nil)
    }

    @objc
    func addPasswordAction(_: Any?) {
        if shouldPerformSegue(withIdentifier: "addPasswordSegue", sender: self) {
            performSegue(withIdentifier: "addPasswordSegue", sender: self)
        }
    }

    @objc
    func didTapNavigationBar(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: navigationController?.navigationBar)
        let hitView = navigationController?.navigationBar.hitTest(location, with: nil)
        guard String(describing: hitView).contains("UINavigationBarContentView") else {
            return
        }
        showSyncFilterMenu()
    }

    /// Switches between all passwords and those with changes not yet synced.
    func showSyncFilterMenu() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let allAction = UIAlertAction(title: "All Passwords", style: .default) { _ in
            self.configureTableView(in: self.parentPasswordEntity)
            self.tableView.reloadData()
            self.viewingUnsyncedPasswords = false
            self.configureNavigationItem()
            self.browser?.updateHeader()
        }
        let unsyncedAction = UIAlertAction(title: "Unsynced Passwords", style: .default) { _ in
            // The tree only holds what is expanded, so list unsynced passwords flat.
            self.configureTableViewDataSource(in: self.parentPasswordEntity, isShowFolder: false)
            self.dataSource?.showUnsyncedTableEntries()
            self.tableView.reloadData()
            self.viewingUnsyncedPasswords = true
            self.configureNavigationItem()
            self.browser?.updateHeader()
        }
        let cancelAction = UIAlertAction.cancel()

        alertController.addAction(allAction)
        alertController.addAction(unsyncedAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true)
    }

    @objc
    func actOnSearchNotification() {
        searchBar.becomeFirstResponder()
    }

    @objc
    func handleRefreshControl() {
        syncPasswords()
        DispatchQueue.main.async {
            self.refreshControl.endRefreshing()
        }
    }
}

extension PasswordNavigationViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if browser == nil {
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            // As in Pass Picker, the tapped row keeps the tree's focus.
            becomeFirstResponder()
        }
        guard let dataSource else {
            return
        }
        let entry = dataSource.getPasswordTableEntry(at: indexPath)
        if entry.isDir, let treeDataSource = dataSource as? PasswordTreeDataSource {
            updateTree(treeDataSource) { $0.toggle(at: indexPath.row) }
            return
        }
        if entry.isDir {
            showDir(in: entry)
        } else {
            showPasswordDetail(at: entry)
        }
        leaveSearch()
    }

    /// Applies a change to the folder tree and redraws it, keeping keyboard focus on the same entry.
    private func updateTree(_ treeDataSource: PasswordTreeDataSource, change: (PasswordTree) -> Void) {
        let focusedPath = tableView.indexPathForSelectedRow.map { treeDataSource.tree.rows[$0.row].entry.passwordEntity.path }
        change(treeDataSource.tree)
        // Folders opened by a search stay out of the tree you go back to.
        if !isSearching {
            expandedPaths = treeDataSource.expandedPaths
        }
        UIView.transition(with: tableView, duration: 0.15, options: .transitionCrossDissolve) {
            self.tableView.reloadData()
        }
        if let focusedPath, let row = treeDataSource.tree.index(ofPath: focusedPath) {
            tableView.focusRow(at: IndexPath(row: row, section: 0))
        }
    }

    func showDir(in entry: PasswordTableEntry) {
        let passwordNavigationViewController = UIStoryboard.passwordNavigationViewController
        passwordNavigationViewController.parentPasswordEntity = entry.passwordEntity
        navigationController?.pushViewController(passwordNavigationViewController, animated: true)
    }

    func showPasswordDetail(at entry: PasswordTableEntry) {
        if let browser, shouldPerformSegue(withIdentifier: "showPasswordDetail", sender: nil) {
            browser.showDetail(for: entry.passwordEntity, editorIntent: editorIntentOnShow)
            editorIntentOnShow = nil
            return
        }
        let segueIdentifier = "showPasswordDetail"
        let sender = entry.passwordEntity
        if shouldPerformSegue(withIdentifier: segueIdentifier, sender: sender) {
            performSegue(withIdentifier: segueIdentifier, sender: sender)
        }
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt _: IndexPath) {
        updateFocusHighlight(cell)
    }

    // Tree rows are one line, tighter than the system's 44pt minimum; search results wrap their paths.
    private static let treeRowHeight: CGFloat = 36

    func tableView(_: UITableView, estimatedHeightForRowAt _: IndexPath) -> CGFloat {
        dataSource is PasswordTreeDataSource ? Self.treeRowHeight : UITableView.automaticDimension
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        dataSource is PasswordTreeDataSource ? Self.treeRowHeight : UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // The tree and the search results have no section titles.
        dataSource?.tableView(tableView, titleForHeaderInSection: section) == nil ? 0 : UITableView.automaticDimension
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        0
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        self.tableView(tableView, heightForHeaderInSection: section)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else {
            return
        }
        var content = header.defaultContentConfiguration()
        content.text = dataSource?.tableView(tableView, titleForHeaderInSection: section)
        content.textProperties.font = Theme.mono(13, relativeTo: .footnote)
        content.textProperties.color = Theme.Palette.chromeText
        header.contentConfiguration = content
        var background = UIBackgroundConfiguration.listPlainHeaderFooter()
        background.backgroundColor = .clear
        header.backgroundConfiguration = background
    }
}

extension PasswordNavigationViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPasswordDetail" {
            if let viewController = segue.destination as? PasswordDetailTableViewController {
                viewController.passwordEntity = sender as? PasswordEntity
                viewController.opensEditorWhenReady = editorIntentOnShow
                editorIntentOnShow = nil
            }
        } else if segue.identifier == "addPasswordSegue" {
            if let navController = segue.destination as? UINavigationController,
               let viewController = navController.topViewController as? AddPasswordTableViewController,
               let path = newPasswordFolderOverride ?? parentPasswordEntity?.path {
                viewController.defaultDirPrefix = "\(path)/"
            }
            newPasswordFolderOverride = nil
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender _: Any?) -> Bool {
        if identifier == "showPasswordDetail" {
            guard Defaults.isYubiKeyEnabled || PGPAgent.shared.isPrepared else {
                Utils.alert(title: "CannotShowPassword".localize(), message: "PgpKeyNotSet.".localize(), controller: self)
                return false
            }
        } else if identifier == "addPasswordSegue" {
            guard PGPAgent.shared.isPrepared, PasswordStore.shared.gitRepository != nil else {
                Utils.alert(title: "CannotAddPassword".localize(), message: "MakeSurePgpAndGitProperlySet.".localize(), controller: self)
                return false
            }
        }
        return true
    }

    @IBAction
    private func cancelAddPassword(segue _: UIStoryboardSegue) {}

    @IBAction
    private func cancelEditPassword(segue _: UIStoryboardSegue) {}

    @IBAction
    private func saveEditPassword(segue _: UIStoryboardSegue) {}

    @IBAction
    private func saveAddPassword(segue: UIStoryboardSegue) {
        if let controller = segue.source as? AddPasswordTableViewController {
            passwordManager.addPassword(with: controller.password!)
        }
    }
}

extension PasswordNavigationViewController {
    @objc
    func actOnPossiblePasswordStoreUpdate() {
        DispatchQueue.main.async {
            if let path = self.parentPath {
                // reload parent because all PasswordEntities are re-created on PasswordStore update
                self.parentPasswordEntity = PasswordStore.shared.fetchPasswordEntity(with: path)

                // pop to the root controller if the parent does not exist anymore
                if self.parentPasswordEntity == nil {
                    self.navigationController?.popToRootViewController(animated: true)
                }
            }

            self.resetViews()
        }
    }

    @objc
    func actOnPasswordStoreSyncSucceeded() {
        DispatchQueue.main.async {
            self.configureTabBarItem()
        }
    }

    func resetViews() {
        configureTableView(in: parentPasswordEntity)
        tableView.layoutIfNeeded()
        tableView.reloadData()
        configureNavigationItem()
        configureTabBarItem()
        configureNavigationBar()
        configureSearchBar()
    }
}

extension PasswordNavigationViewController: UISearchBarDelegate {
    func search(matching text: String) {
        searchText = text
        if let treeDataSource = dataSource as? PasswordTreeDataSource {
            treeDataSource.tree.filter(matching: text)
        } else {
            dataSource?.showTableEntries(matching: text)
        }
        tableView.reloadData()
    }

    func activateSearch(_ selectedScope: Int?) {
        // The browser searches within its tree, as Pass Picker does.
        if usesEmbeddedSearchBar {
            configureTableViewDataSource(in: parentPasswordEntity, isShowFolder: true, asTree: true)
        } else if selectedScope == SearchBarScope.all.rawValue {
            configureTableViewDataSource(in: nil, isShowFolder: false)
        } else {
            configureTableViewDataSource(in: parentPasswordEntity, isShowFolder: true)
        }
        dataSource?.isSearchActive = true
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        activateSearch(selectedScope)
        search(matching: searchBar.text ?? "")
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        browser?.paneDidTakeFocus(self)
        if Defaults.searchDefault == .all {
            searchBar.selectedScopeButtonIndex = SearchBarScope.all.rawValue
        } else {
            searchBar.selectedScopeButtonIndex = SearchBarScope.current.rawValue
        }
        activateSearch(searchBar.selectedScopeButtonIndex)
        search(matching: searchBar.text ?? "")
    }

    func searchBar(_: UISearchBar, textDidChange searchText: String) {
        search(matching: searchText)
        browser?.searchTextDidChange()
    }

    // Return in the search field moves keyboard focus to the first result.
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        becomeFirstResponder()
        if !revealExactPath(searchBar.text ?? "") {
            focusFirstRow()
        }
    }

    /// ↓ in the search field: the first result takes the focus.
    func focusFirstRow() {
        searchBar.resignFirstResponder()
        becomeFirstResponder()
        tableView.focusRow(at: tableView.indexPath(after: nil))
    }

    // Leaving the browser's search field empty goes back to the tree, as in Pass Picker.
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if usesEmbeddedSearchBar, searchBar.text?.isEmpty ?? true, dataSource?.isSearchActive == true {
            cancelSearch()
        }
    }

    func searchBarCancelButtonClicked(_: UISearchBar) {
        cancelSearch()
    }

    func cancelSearch() {
        configureTableView(in: parentPasswordEntity)
        dataSource?.isSearchActive = false
        searchText = nil
        tableView.reloadData()
        becomeFirstResponder()
    }
}

extension PasswordNavigationViewController: UITabBarControllerDelegate {
    func tabBarController(_: UITabBarController, didSelect viewController: UIViewController) {
        if viewController == navigationController {
            let currentTime = Date().timeIntervalSince1970
            let duration = currentTime - tapTabBarTime
            tapTabBarTime = currentTime
            if duration < 0.35, tableView.numberOfSections > 0 {
                let topIndexPath = IndexPath(row: 0, section: 0)
                tableView.scrollToRow(at: topIndexPath, at: .bottom, animated: true)
                tapTabBarTime = 0
            }
        }
    }
}

extension PasswordNavigationViewController: PasswordAlertPresenter {
    private func syncPasswords() {
        guard PasswordStore.shared.repositoryExists() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
                Utils.alert(title: "Error".localize(), message: "NoPasswordStore.".localize(), controller: self, completion: nil)
            }
            return
        }
        SVProgressHUD.setDefaultMaskType(.black)
        SVProgressHUD.setDefaultStyle(.light)
        SVProgressHUD.show(withStatus: "SyncingPasswordStore".localize())
        let keychain = AppKeychain.shared
        var gitCredential: GitCredential {
            GitCredential.from(
                authenticationMethod: Defaults.gitAuthenticationMethod,
                userName: Defaults.gitUsername,
                keyStore: keychain
            )
        }
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                let pullOptions = gitCredential.getCredentialOptions(passwordProvider: present)
                try PasswordStore.shared.pullRepository(options: pullOptions) { git_transfer_progress, _ in
                    DispatchQueue.main.async {
                        SVProgressHUD.showProgress(Float(git_transfer_progress.pointee.received_objects) / Float(git_transfer_progress.pointee.total_objects), status: "PullingFromRemoteRepository".localize())
                    }
                }
                if PasswordStore.shared.numberOfLocalCommits > 0 {
                    let pushOptions = gitCredential.getCredentialOptions(passwordProvider: present)
                    try PasswordStore.shared.pushRepository(options: pushOptions) { current, total, _, _ in
                        DispatchQueue.main.async {
                            SVProgressHUD.showProgress(Float(current) / Float(total), status: "PushingToRemoteRepository".localize())
                        }
                    }
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .passwordStoreSyncSucceeded, object: nil)
                    SVProgressHUD.showSuccess(withStatus: "Done".localize())
                    SVProgressHUD.dismiss(withDelay: 1)
                }
            } catch let error as NSError {
                gitCredential.delete()
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    var message = error.localizedDescription
                    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                        message = message | "UnderlyingError".localize(underlyingError.localizedDescription)
                        if underlyingError.localizedDescription.contains("WrongPassphrase".localize()) {
                            message = message | "RecoverySuggestion.".localize()
                        }
                    }
                    if let mergeConflictFiles = error.userInfo[GTPullMergeConflictedFiles] as? NSArray {
                        let mergeConflictFilesString = mergeConflictFiles.componentsJoined(by: ", ")
                        message = message | "MergeConflictError".localize(mergeConflictFilesString)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
                        Utils.alert(title: "Error".localize(), message: message, controller: self, completion: nil)
                    }
                }
            }
        }
    }
}

// MARK: - Hardware keyboard shortcuts

extension PasswordNavigationViewController {
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

    // Pass Picker's sidebar keys.
    override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = [
            .shortcut("n", action: #selector(addPasswordAction), modifiers: .command, title: "New Password"),
            .shortcut("+", action: #selector(addPasswordInFocusedFolder), title: "New Password Here"),
            .shortcut("=", action: #selector(addPasswordInFocusedFolder), modifiers: .shift),
            .shortcut("e", action: #selector(editFocusedEntry), modifiers: .command, title: "Edit Password"),
            .shortcut("r", action: #selector(renameFocusedEntry), modifiers: .command, title: "Rename"),
            .shortcut("r", action: #selector(renameFocusedEntry)),
            .shortcut("i", action: #selector(addPasswordInFocusedFolder), modifiers: .command, title: "New Item Here"),
            .shortcut("d", action: #selector(deleteFocusedEntry), modifiers: .command, title: "Delete Password"),
            .shortcut(UIKeyCommand.inputDownArrow, action: #selector(focusNextRow)),
            .shortcut(UIKeyCommand.inputUpArrow, action: #selector(focusPreviousRow)),
            .shortcut("j", action: #selector(focusNextRow)),
            .shortcut("k", action: #selector(focusPreviousRow)),
            // W/A/S/D act as the arrow keys.
            .shortcut("s", action: #selector(focusNextRow)),
            .shortcut("w", action: #selector(focusPreviousRow)),
            .shortcut("d", action: #selector(expandFocusedRow)),
            .shortcut("a", action: #selector(collapseFocusedRow)),
            .shortcut(UIKeyCommand.inputRightArrow, action: #selector(expandFocusedRow), title: "Expand Folder"),
            .shortcut(UIKeyCommand.inputLeftArrow, action: #selector(collapseFocusedRow), title: "Collapse Folder"),
            .shortcut(UIKeyCommand.inputRightArrow, action: #selector(expandFocusedLevel), modifiers: .shift, title: "Expand Level"),
            .shortcut(UIKeyCommand.inputLeftArrow, action: #selector(collapseFocusedLevel), modifiers: .shift, title: "Collapse Level"),
            .shortcut(UIKeyCommand.inputRightArrow, action: #selector(expandAllFolders), modifiers: [.command, .shift], title: "Expand All"),
            .shortcut(UIKeyCommand.inputLeftArrow, action: #selector(collapseAllFolders), modifiers: [.command, .shift], title: "Collapse All"),
            .shortcut("\r", action: #selector(openFocusedRow), title: "Open"),
        ]
        if browser == nil {
            // In the browser, ⌘F belongs to the browser so it works from either pane.
            commands.append(.shortcut("f", action: #selector(focusSearch), modifiers: .command, title: "Search"))
            commands.append(.shortcut(UIKeyCommand.inputEscape, action: #selector(escape)))
        }
        return commands
    }

    /// Folder a new password goes in: the focused folder, the focused entry's folder, or the folder on screen.
    private var newPasswordFolderPath: String? {
        guard let indexPath = tableView.indexPathForSelectedRow, let dataSource else {
            return parentPasswordEntity?.path
        }
        let entity = dataSource.getPasswordTableEntry(at: indexPath).passwordEntity
        return entity.isDir ? entity.path : entity.parent?.path
    }

    @objc
    func focusSearch() {
        beginSearch()
        DispatchQueue.main.async {
            self.searchBar.becomeFirstResponder()
        }
    }

    @objc
    private func focusNextRow() {
        tableView.focusRow(at: tableView.indexPath(after: tableView.indexPathForSelectedRow))
    }

    @objc
    private func focusPreviousRow() {
        tableView.focusRow(at: tableView.indexPath(before: tableView.indexPathForSelectedRow))
    }

    @objc
    private func openFocusedRow() {
        guard let indexPath = tableView.indexPathForSelectedRow else {
            return
        }
        let isFolderInTree = dataSource is PasswordTreeDataSource && dataSource?.getPasswordTableEntry(at: indexPath).isDir == true
        tableView(tableView, didSelectRowAt: indexPath)
        if isFolderInTree {
            // didSelectRow clears the selection; keep focus on the folder that was toggled.
            tableView.focusRow(at: indexPath)
        }
    }

    /// The focused row, when it is a password rather than a folder.
    private var focusedEntry: PasswordTableEntry? {
        guard let indexPath = tableView.indexPathForSelectedRow, let entry = dataSource?.getPasswordTableEntry(at: indexPath), !entry.isDir else {
            return nil
        }
        return entry
    }

    // ⌘E: the focused password, else the one open beside the list.
    @objc
    private func editFocusedEntry() {
        guard let entry = focusedEntry else {
            browser?.detailViewController?.openEditor(.edit)
            return
        }
        open(entry, editorIntent: .edit)
    }

    // ⌘R (or R): rename the focused folder or password.
    @objc
    private func renameFocusedEntry() {
        if let indexPath = tableView.indexPathForSelectedRow, let entry = dataSource?.getPasswordTableEntry(at: indexPath) {
            rename(entry)
        }
    }

    /// A password is renamed in the editor's name field; a folder, with everything in it, here.
    private func rename(_ entry: PasswordTableEntry) {
        guard entry.isDir else {
            open(entry, editorIntent: .rename)
            return
        }
        let oldPath = entry.passwordEntity.path
        let alert = UIAlertController(title: "Rename Folder", message: "Everything in it moves too.", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = oldPath
            field.font = Theme.mono(15)
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction.cancel())
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self, weak alert] _ in
            guard let self, let newPath = alert?.textFields?.first?.text else {
                return
            }
            do {
                try PasswordStore.shared.renameDirectory(at: oldPath, to: newPath)
            } catch {
                Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
            }
        })
        present(alert, animated: true)
    }

    /// A new password inside a folder, or beside a password.
    private func addPassword(near entry: PasswordTableEntry) {
        newPasswordFolderOverride = .some(entry.isDir ? entry.passwordEntity.path : entry.passwordEntity.parent?.path)
        addPasswordAction(nil)
    }

    private func confirmDelete(_ entry: PasswordTableEntry) {
        let entity = entry.passwordEntity
        present(DeleteConfirmViewController(path: entity.nameWithDir) { [weak self] in
            do {
                try PasswordStore.shared.delete(passwordEntity: entity)
            } catch {
                guard let self else {
                    return
                }
                Utils.alert(title: "Error".localize(), message: error.localizedDescription, controller: self, completion: nil)
            }
        }, animated: true)
    }

    private func open(_ entry: PasswordTableEntry, editorIntent: EditPasswordTableViewController.Intent) {
        editorIntentOnShow = editorIntent
        showPasswordDetail(at: entry)
        leaveSearch()
    }

    // +: a new password in the focused folder, or beside the focused password.
    @objc
    private func addPasswordInFocusedFolder() {
        newPasswordFolderOverride = .some(newPasswordFolderPath)
        addPasswordAction(nil)
    }

    // ⌘D: the focused password, else the one open beside the list. Folders aren't deleted.
    @objc
    private func deleteFocusedEntry() {
        if let indexPath = tableView.indexPathForSelectedRow, let entry = dataSource?.getPasswordTableEntry(at: indexPath) {
            if !entry.isDir {
                confirmDelete(entry)
            }
            return
        }
        browser?.detailViewController?.confirmDelete()
    }

    // Long-press: a folder can be renamed or given a new item; a password renamed, given a sibling, or deleted.
    func tableView(_: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point _: CGPoint) -> UIContextMenuConfiguration? {
        guard let entry = dataSource?.getPasswordTableEntry(at: indexPath) else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else {
                return nil
            }
            let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in self.rename(entry) }
            guard !entry.isDir else {
                let newItem = UIAction(title: "New Item", image: UIImage(systemName: "plus")) { _ in self.addPassword(near: entry) }
                return UIMenu(children: [rename, newItem])
            }
            let sibling = UIAction(title: "Add Sibling", image: UIImage(systemName: "plus")) { _ in self.addPassword(near: entry) }
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in self.confirmDelete(entry) }
            return UIMenu(children: [rename, sibling, delete])
        }
    }

    @objc
    private func expandFocusedLevel() {
        if let treeDataSource = dataSource as? PasswordTreeDataSource, let indexPath = tableView.indexPathForSelectedRow {
            updateTree(treeDataSource) { $0.expandLevel(at: indexPath.row) }
        }
    }

    @objc
    private func collapseFocusedLevel() {
        if let treeDataSource = dataSource as? PasswordTreeDataSource, let indexPath = tableView.indexPathForSelectedRow {
            updateTree(treeDataSource) { $0.collapseLevel(at: indexPath.row) }
        }
    }

    /// Search Return on an exact path (e.g. `finance/tax-portal`) shows that row in the tree, as in Pass Picker.
    func revealExactPath(_ query: String) -> Bool {
        let path = query.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")).replacingOccurrences(of: ".gpg", with: "")
        guard !path.isEmpty, let entity = PasswordStore.shared.fetchPasswordEntity(with: path) ?? PasswordStore.shared.fetchPasswordEntity(with: path + ".gpg") else {
            return false
        }
        endSearch()
        guard let treeDataSource = dataSource as? PasswordTreeDataSource else {
            return true
        }
        updateTree(treeDataSource) { $0.reveal(path: entity.path) }
        tableView.focusRow(at: treeDataSource.tree.index(ofPath: entity.path).map { IndexPath(row: $0, section: 0) })
        return true
    }

    // →: expand the focused folder, or step into it if already open.
    @objc
    private func expandFocusedRow() {
        guard let indexPath = tableView.indexPathForSelectedRow else {
            return
        }
        guard let treeDataSource = dataSource as? PasswordTreeDataSource else {
            if dataSource?.getPasswordTableEntry(at: indexPath).isDir == true {
                openFocusedRow()
            }
            return
        }
        let row = treeDataSource.tree.rows[indexPath.row]
        guard row.entry.isDir else {
            return
        }
        if !treeDataSource.tree.isExpanded(row) {
            updateTree(treeDataSource) { $0.toggle(at: indexPath.row) }
        } else if indexPath.row + 1 < treeDataSource.tree.rows.count, treeDataSource.tree.rows[indexPath.row + 1].depth > row.depth {
            tableView.focusRow(at: IndexPath(row: indexPath.row + 1, section: 0))
        }
    }

    // ←: collapse the focused folder, or move focus to its parent.
    @objc
    private func collapseFocusedRow() {
        guard let treeDataSource = dataSource as? PasswordTreeDataSource else {
            if !isRootViewController() {
                navigationController?.popViewController(animated: true)
            }
            return
        }
        guard let indexPath = tableView.indexPathForSelectedRow else {
            return
        }
        let row = treeDataSource.tree.rows[indexPath.row]
        if row.entry.isDir, treeDataSource.tree.isExpanded(row) {
            updateTree(treeDataSource) { $0.toggle(at: indexPath.row) }
        } else if let parentPath = row.parentPath, let parentRow = treeDataSource.tree.index(ofPath: parentPath) {
            tableView.focusRow(at: IndexPath(row: parentRow, section: 0))
        }
    }

    @objc
    private func expandAllFolders() {
        if let treeDataSource = dataSource as? PasswordTreeDataSource {
            updateTree(treeDataSource) { $0.expandAll() }
        }
    }

    @objc
    private func collapseAllFolders() {
        if let treeDataSource = dataSource as? PasswordTreeDataSource {
            updateTree(treeDataSource) { $0.collapseAll() }
        }
    }

    @objc
    private func escape() {
        if isSearching {
            endSearch()
        } else if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: false)
        } else if !isRootViewController() {
            navigationController?.popViewController(animated: true)
        }
    }
}
