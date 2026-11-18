//
//  PGPAgent.swift
//  passKit
//
//  Created by Yishi Lin on 2019/7/17.
//  Copyright © 2019 Bob Sun. All rights reserved.
//

public class PGPAgent {
    public static let shared = PGPAgent()

    private let keyStore: KeyStore
    private var pgpInterface: PGPInterface?
    private var latestDecryptStatus = true

    public init(keyStore: KeyStore = AppKeychain.shared) {
        self.keyStore = keyStore
    }

    public func initKeys() throws {
        guard let publicKey: String = keyStore.get(for: PGPKey.PUBLIC.getKeychainKey()),
              let privateKey: String = keyStore.get(for: PGPKey.PRIVATE.getKeychainKey()) else {
            pgpInterface = nil
            throw AppError.keyImport
        }
        do {
            pgpInterface = try GopenPGPInterface(publicArmoredKey: publicKey, privateArmoredKey: privateKey)
        } catch {
            pgpInterface = try ObjectivePGPInterface(publicArmoredKey: publicKey, privateArmoredKey: privateKey)
        }
    }

    public func uninitKeys() {
        pgpInterface = nil
    }

    public var isInitialized: Bool {
        pgpInterface != nil
    }

    public func getKeyID() throws -> [String] {
        try checkAndInit()
        return pgpInterface?.keyID ?? []
    }

    public func getShortKeyID() throws -> [String] {
        try checkAndInit()
        return pgpInterface?.shortKeyID.sorted() ?? []
    }

    public func decrypt(encryptedData: Data, keyID: String, requestPGPKeyPassphrase: @escaping (String) -> String) throws -> Data? {
        // Init keys.
        try checkAndInit()
        guard let pgpInterface else {
            throw AppError.decryption
        }

        var keyID = keyID
        if !pgpInterface.containsPrivateKey(with: keyID) {
            if pgpInterface.keyID.count == 1 {
                keyID = pgpInterface.keyID.first!
            } else {
                throw AppError.pgpPrivateKeyNotFound(keyID: keyID)
            }
        }

        // Remember the previous status and set the current status
        let previousDecryptStatus = latestDecryptStatus
        latestDecryptStatus = false

        let (passphrase, source) = passphrase(for: keyID, afterFailure: !previousDecryptStatus, request: requestPGPKeyPassphrase)
        let result = try decrypting(with: source, keyID: keyID) {
            try pgpInterface.decrypt(encryptedData: encryptedData, keyID: keyID, passphrase: passphrase)
        }
        guard let result else {
            return nil
        }
        // The decryption step has succeed.
        latestDecryptStatus = true
        PGPPassphraseMemory.didUse()
        if source == .typed {
            PGPPassphraseBiometrics.save(passphrase, for: keyID)
        }
        return result
    }

    private enum PassphraseSource {
        case memory, biometrics, typed
    }

    /// The remembered passphrase, else the one saved for Face ID / Touch ID, else a typed one.
    /// After a failed attempt the passphrase is always typed.
    private func passphrase(for keyID: String, afterFailure: Bool, request: (String) -> String) -> (String, PassphraseSource) {
        if !afterFailure {
            if let passphrase = PGPPassphraseMemory.passphrase(for: keyID, in: keyStore) {
                return (passphrase, .memory)
            }
            if let passphrase = PGPPassphraseBiometrics.passphrase(for: keyID) {
                return (passphrase, .biometrics)
            }
        }
        return (request(keyID), .typed)
    }

    // A saved passphrase that no longer decrypts (the key changed) is dropped, so the next attempt asks for it.
    private func decrypting(with source: PassphraseSource, keyID: String, _ decrypt: () throws -> Data?) throws -> Data? {
        do {
            let result = try decrypt()
            if result == nil, source == .biometrics {
                PGPPassphraseBiometrics.forget(keyID: keyID)
            }
            return result
        } catch {
            if source == .biometrics {
                PGPPassphraseBiometrics.forget(keyID: keyID)
            }
            throw error
        }
    }

    public func encrypt(plainData: Data, keyID: String) throws -> Data {
        try checkAndInit()
        guard let pgpInterface else {
            throw AppError.encryption
        }
        var keyID = keyID
        if !pgpInterface.containsPublicKey(with: keyID) {
            if pgpInterface.keyID.count == 1 {
                keyID = pgpInterface.keyID.first!
            } else {
                throw AppError.pgpPublicKeyNotFound(keyID: keyID)
            }
        }
        return try pgpInterface.encrypt(plainData: plainData, keyID: keyID)
    }

    public func decrypt(encryptedData: Data, requestPGPKeyPassphrase: (String) -> String) throws -> Data? {
        // Remember the previous status and set the current status
        let previousDecryptStatus = latestDecryptStatus
        latestDecryptStatus = false
        // Init keys.
        try checkAndInit()
        let (passphrase, source) = passphrase(for: "", afterFailure: !previousDecryptStatus, request: requestPGPKeyPassphrase)
        let result = try decrypting(with: source, keyID: "") {
            try pgpInterface!.decrypt(encryptedData: encryptedData, keyID: nil, passphrase: passphrase)
        }
        guard let result else {
            return nil
        }
        // The decryption step has succeed.
        latestDecryptStatus = true
        PGPPassphraseMemory.didUse()
        if source == .typed {
            PGPPassphraseBiometrics.save(passphrase, for: "")
        }
        return result
    }

    public func encrypt(plainData: Data) throws -> Data {
        try checkAndInit()
        guard let pgpInterface else {
            throw AppError.encryption
        }
        return try pgpInterface.encrypt(plainData: plainData, keyID: nil)
    }

    public var isPrepared: Bool {
        keyStore.contains(key: PGPKey.PUBLIC.getKeychainKey())
            && keyStore.contains(key: PGPKey.PRIVATE.getKeychainKey())
    }

    private func checkAndInit() throws {
        if pgpInterface == nil || !keyStore.contains(key: Globals.pgpKeyPassphrase) {
            try initKeys()
        }
    }
}
