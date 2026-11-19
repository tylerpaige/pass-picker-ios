//
//  DefaultsKeys.swift
//  passKit
//
//  Created by Mingshen Sun on 21/1/2017.
//  Copyright © 2017 Bob Sun. All rights reserved.
//

import Foundation
import SwiftyUserDefaults

// Workaround for Xcode 13: https://github.com/sunshinejr/SwiftyUserDefaults/issues/285

public extension DefaultsSerializable where Self: Codable {
    typealias Bridge = DefaultsCodableBridge<Self>
    typealias ArrayBridge = DefaultsCodableBridge<[Self]>
}

public extension DefaultsSerializable where Self: RawRepresentable {
    typealias Bridge = DefaultsRawRepresentableBridge<Self>
    typealias ArrayBridge = DefaultsRawRepresentableArrayBridge<[Self]>
}

public var Defaults = DefaultsAdapter(defaults: UserDefaults(suiteName: Globals.groupIdentifier)!, keyStore: DefaultsKeys())

public enum KeySource: String, DefaultsSerializable {
    case url, armor, file, itunes
}

public enum GitAuthenticationMethod: String, DefaultsSerializable {
    case password, key
}

extension SearchBarScope: DefaultsSerializable {}
extension PasswordGenerator: DefaultsSerializable {}

public extension DefaultsKeys {
    var pgpKeySource: DefaultsKey<KeySource?> { DefaultsKey("pgpKeySource") }
    var pgpPublicKeyURL: DefaultsKey<URL?> { DefaultsKey("pgpPublicKeyURL") }
    var pgpPrivateKeyURL: DefaultsKey<URL?> { DefaultsKey("pgpPrivateKeyURL") }
    var isYubiKeyEnabled: DefaultsKey<Bool> { DefaultsKey("isYubiKeyEnabled", defaultValue: false) }

    // Keep them for legacy reasons.
    var pgpPublicKeyArmor: DefaultsKey<String?> { DefaultsKey("pgpPublicKeyArmor") }
    var pgpPrivateKeyArmor: DefaultsKey<String?> { DefaultsKey("pgpPrivateKeyArmor") }
    var gitSSHPrivateKeyArmor: DefaultsKey<String?> { DefaultsKey("gitSSHPrivateKeyArmor") }
    var passcodeKey: DefaultsKey<String?> { DefaultsKey("passcodeKey") }

    var gitURL: DefaultsKey<URL> { DefaultsKey("gitURL", defaultValue: URL(string: "https://")!) }
    var gitAuthenticationMethod: DefaultsKey<GitAuthenticationMethod> { DefaultsKey("gitAuthenticationMethod", defaultValue: GitAuthenticationMethod.password) }
    var gitUsername: DefaultsKey<String> { DefaultsKey("gitUsername", defaultValue: "git") }
    var gitBranchName: DefaultsKey<String> { DefaultsKey("gitBranchName", defaultValue: "master") }
    var gitSSHPrivateKeyURL: DefaultsKey<URL?> { DefaultsKey("gitSSHPrivateKeyURL") }
    var gitSSHKeySource: DefaultsKey<KeySource?> { DefaultsKey("gitSSHKeySource") }
    var gitSignatureName: DefaultsKey<String?> { DefaultsKey("gitSignatureName") }
    var gitSignatureEmail: DefaultsKey<String?> { DefaultsKey("gitSignatureEmail") }

    var lastSyncedTime: DefaultsKey<Date?> { DefaultsKey("lastSyncedTime") }

    var isHideUnknownOn: DefaultsKey<Bool> { DefaultsKey("isHideUnknownOn", defaultValue: false) }
    var isHideOTPOn: DefaultsKey<Bool> { DefaultsKey("isHideOTPOn", defaultValue: false) }
    var isRememberPGPPassphraseOn: DefaultsKey<Bool> { DefaultsKey("isRememberPGPPassphraseOn", defaultValue: false) }
    var pgpPassphraseDuration: DefaultsKey<Int> { DefaultsKey("pgpPassphraseDuration", defaultValue: 10 * 60) }
    var isBiometricPGPUnlockOn: DefaultsKey<Bool> { DefaultsKey("isBiometricPGPUnlockOn", defaultValue: false) }
    var isAutoResizePanesOn: DefaultsKey<Bool> { DefaultsKey("isAutoResizePanesOn", defaultValue: false) }
    // The editor's generator, as in Pass Picker.
    var passwordGeneratorLength: DefaultsKey<Int> { DefaultsKey("passwordGeneratorLength", defaultValue: 12) }
    var passwordGeneratorSpecialCharacters: DefaultsKey<String> { DefaultsKey("passwordGeneratorSpecialCharacters", defaultValue: "!@#$%^&*()_") }
    var pgpPassphraseLastUsed: DefaultsKey<Date?> { DefaultsKey("pgpPassphraseLastUsed") }
    var isRememberGitCredentialPassphraseOn: DefaultsKey<Bool> { DefaultsKey("isRememberGitCredentialPassphraseOn", defaultValue: false) }
    var isEnableGPGIDOn: DefaultsKey<Bool> { DefaultsKey("isEnableGPGIDOn", defaultValue: false) }
    var searchDefault: DefaultsKey<SearchBarScope?> { DefaultsKey("searchDefault", defaultValue: .all) }
    var passwordGenerator: DefaultsKey<PasswordGenerator> { DefaultsKey("passwordGenerator", defaultValue: PasswordGenerator()) }

    var encryptInArmored: DefaultsKey<Bool> { DefaultsKey("encryptInArmored", defaultValue: false) }

    var autoCopyOTP: DefaultsKey<Bool> { DefaultsKey("autoCopyOTP", defaultValue: false) }
}
