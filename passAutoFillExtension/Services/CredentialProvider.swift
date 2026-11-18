//
//  CredentialProvider.swift
//  passAutoFillExtension
//
//  Created by Sun, Mingshen on 1/2/21.
//  Copyright © 2021 Bob Sun. All rights reserved.
//

import AuthenticationServices
import passKit

class CredentialProvider {
    private let viewController: UIViewController
    private let extensionContext: ASCredentialProviderExtensionContext
    private let afterDecryption: (Password) -> Void

    var identifier: ASCredentialServiceIdentifier?

    init(viewController: UIViewController, extensionContext: ASCredentialProviderExtensionContext, afterDecryption: @escaping (Password) -> Void) {
        self.viewController = viewController
        self.extensionContext = extensionContext
        self.afterDecryption = afterDecryption
    }

    func credentials(for identity: ASPasswordCredentialIdentity) {
        guard let recordIdentifier = identity.recordIdentifier else {
            return
        }

        decryptPassword(in: viewController, with: recordIdentifier) { password in
            self.extensionContext.completeRequest(withSelectedCredential: .from(password))
            self.afterDecryption(password)
        }
    }

    func persistAndProvideCredentials(with passwordPath: String) {
        decryptPassword(in: viewController, with: passwordPath) { password in
            if let identifier = self.identifier {
                ASCredentialIdentityStore.shared.getState { state in
                    guard state.isEnabled else {
                        return
                    }
                    // QuickType shows an identity's user as the suggestion label, so label it with the entry's path.
                    // The credential handed back still carries the real username.
                    let credentialIdentity = ASPasswordCredentialIdentity(
                        serviceIdentifier: identifier,
                        user: Self.suggestionLabel(for: passwordPath),
                        recordIdentifier: passwordPath
                    )
                    // Drop the identity saved by earlier versions, which was labelled with the username.
                    let legacyIdentity = ASPasswordCredentialIdentity(
                        serviceIdentifier: identifier,
                        user: password.getUsernameForCompletion(),
                        recordIdentifier: passwordPath
                    )
                    ASCredentialIdentityStore.shared.removeCredentialIdentities([legacyIdentity]) { _, _ in
                        ASCredentialIdentityStore.shared.saveCredentialIdentities([credentialIdentity])
                    }
                }
            }
            self.extensionContext.completeRequest(withSelectedCredential: .from(password))
            self.afterDecryption(password)
        }
    }
}

extension CredentialProvider {
    static let suggestionLabelMaxLength = 32

    /// The entry's path without extension, trimmed from the front with "..." so the entry name stays visible.
    static func suggestionLabel(for passwordPath: String) -> String {
        let path = (passwordPath as NSString).deletingPathExtension
        guard path.count > suggestionLabelMaxLength else {
            return path
        }
        return "..." + path.suffix(suggestionLabelMaxLength - 3)
    }
}

extension ASPasswordCredential {
    static func from(_ password: Password) -> ASPasswordCredential {
        ASPasswordCredential(user: password.getUsernameForCompletion(), password: password.password)
    }
}
