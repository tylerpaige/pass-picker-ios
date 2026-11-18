//
//  PGPPassphraseMemory.swift
//  passKit
//
//  How long a typed PGP key passphrase is remembered, like gpg-agent's cache TTL:
//  the timer restarts every time the passphrase is used. The passphrase lives in the
//  shared keychain, so the AutoFill extension can use it too.
//

import Foundation

public enum PGPPassphraseMemory {
    /// Never remember the passphrase.
    public static let off = 0
    /// Remember it until the setting is changed.
    public static let always = -1

    /// Offered durations, in seconds.
    public static let choices = [off, 60, 5 * 60, 10 * 60, 30 * 60, 60 * 60, 4 * 60 * 60, 8 * 60 * 60, always]

    /// Seconds a passphrase is kept after its last use, `off`, or `always`.
    public static var duration: Int {
        get {
            // Before durations existed, the passphrase was either kept for good or not at all.
            if !Defaults.hasKey(\.pgpPassphraseDuration), Defaults.isRememberPGPPassphraseOn {
                return always
            }
            return Defaults.pgpPassphraseDuration
        }
        set {
            Defaults.pgpPassphraseDuration = newValue
            Defaults.isRememberPGPPassphraseOn = newValue != off
            forget()
        }
    }

    public static func label(for duration: Int) -> String {
        switch duration {
        case off:
            return "Off"
        case always:
            return "Always"
        case ..<3600:
            return "\(duration / 60) min"
        default:
            let hours = duration / 3600
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
    }

    public static var hasExpired: Bool {
        switch duration {
        case off:
            return true
        case always:
            return false
        default:
            guard let lastUsed = Defaults.pgpPassphraseLastUsed else {
                return true
            }
            return Date().timeIntervalSince(lastUsed) > TimeInterval(duration)
        }
    }

    /// The remembered passphrase for `keyID`, unless it has expired (then it is forgotten).
    public static func passphrase(for keyID: String, in keyStore: KeyStore = AppKeychain.shared) -> String? {
        if hasExpired {
            forget()
            return nil
        }
        return keyStore.get(for: AppKeychain.getPGPKeyPassphraseKey(keyID: keyID))
    }

    public static func remember(_ passphrase: String, for keyID: String, in keyStore: KeyStore = AppKeychain.shared) {
        guard duration != off else {
            return
        }
        keyStore.add(string: passphrase, for: AppKeychain.getPGPKeyPassphraseKey(keyID: keyID))
        didUse()
    }

    /// Restarts the timer after the passphrase decrypted something.
    public static func didUse() {
        Defaults.pgpPassphraseLastUsed = Date()
    }

    public static func forget() {
        AppKeychain.shared.removeAllContent(withPrefix: Globals.pgpKeyPassphrase)
        Defaults.pgpPassphraseLastUsed = nil
    }
}
