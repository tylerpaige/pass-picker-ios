//
//  PGPPassphraseBiometrics.swift
//  passKit
//
//  Unlocks the PGP key with Face ID or Touch ID instead of typing its passphrase.
//  The passphrase is saved once it has decrypted something, in a keychain item that
//  only opens after a biometric check, and that is shared with the AutoFill extension.
//

import Foundation
import KeychainAccess
import LocalAuthentication

public enum PGPPassphraseBiometrics {
    private static let keychain = Keychain(service: Globals.bundleIdentifier + ".biometric", accessGroup: Globals.groupIdentifier)
        .synchronizable(false)

    private static func key(for keyID: String) -> String {
        AppKeychain.getPGPKeyPassphraseKey(keyID: keyID)
    }

    /// "Face ID", "Touch ID" or "Optic ID"; nil when the device has no biometrics set up.
    public static var biometryName: String? {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return nil
        }
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            if #available(iOS 17.0, *), context.biometryType == .opticID {
                return "Optic ID"
            }
            return nil
        }
    }

    public static var isEnabled: Bool {
        get {
            Defaults.isBiometricPGPUnlockOn && biometryName != nil
        }
        set {
            Defaults.isBiometricPGPUnlockOn = newValue
            if !newValue {
                forget()
            }
        }
    }

    /// Asks for Face ID or Touch ID, then returns the saved passphrase. Nil if none is saved or the check fails.
    /// Blocks while the system prompt is up, so call it off the main thread.
    public static func passphrase(for keyID: String) -> String? {
        guard isEnabled, (try? keychain.contains(key(for: keyID), withoutAuthenticationUI: true)) == true else {
            return nil
        }
        return try? keychain.authenticationPrompt("Unlock your PGP key").getString(key(for: keyID))
    }

    /// Saves a passphrase that just decrypted something, if biometric unlock is on and it isn't saved yet.
    public static func save(_ passphrase: String, for keyID: String) {
        guard isEnabled, (try? keychain.contains(key(for: keyID), withoutAuthenticationUI: true)) != true else {
            return
        }
        try? keychain
            .accessibility(.whenPasscodeSetThisDeviceOnly, authenticationPolicy: .biometryCurrentSet)
            .set(passphrase, key: key(for: keyID))
    }

    /// Drops the saved passphrase for `keyID`, e.g. after it failed to decrypt.
    public static func forget(keyID: String) {
        try? keychain.remove(key(for: keyID))
    }

    public static func forget() {
        try? keychain.removeAll()
    }
}
