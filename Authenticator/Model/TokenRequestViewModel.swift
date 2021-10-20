//
//  TokenRequestViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-25.
//  Copyright © 2021 Yubico. All rights reserved.
//

@available(iOS 14.0, *)
extension Error {
    var tokenError: TokenRequestViewModel.TokenError {
        let code = YKFPIVFErrorCode(rawValue: UInt((self as NSError).code))
        switch code {
        case .pinLocked:
            return .passwordLocked(TokenRequestViewModel.ErrorMessage(title: "PIN entry locked", text: "Use your PUK code to reset PIN attempts."))
        case .invalidPin:
            return .wrongPassword(TokenRequestViewModel.ErrorMessage(title: "Wrong PIN code", text: nil))
        default:
            return .notHandled(TokenRequestViewModel.ErrorMessage(title: self.localizedDescription, text: nil))
        }
    }
}

@available(iOS 14.0, *)
class TokenRequestViewModel: NSObject {
    
    enum TokenError: Error {
        case wrongPassword(ErrorMessage)
        case passwordLocked(ErrorMessage)
        case notHandled(ErrorMessage)
        case alreadyHandled
        
        var message: ErrorMessage {
            switch self {
            case .wrongPassword(let message):
                return message
            case .passwordLocked(let message):
                return message
            case .notHandled(let message):
                return message
            case .alreadyHandled:
                return ErrorMessage(title: "Already handled", text: nil)
            }
        }
    }
    
    struct ErrorMessage {
        var title: String
        var text: String?
    }
    
    private var connection = Connection()
    
    override init() {
        super.init()
    }
    
    var isAccessoryKeyConnectedHandler: ((Bool) -> Void)?
    
    func isAccessoryKeyConnected(handler: @escaping (Bool) -> Void) {
        isAccessoryKeyConnectedHandler = handler
        connection.accessoryConnection { [weak self] connection in
            DispatchQueue.main.async {
                self?.isAccessoryKeyConnectedHandler?(connection != nil)
            }
        }
    }

    func handleTokenRequest(_ userInfo: [AnyHashable: Any], password: String, completion: @escaping (TokenError?) -> Void) {
        connection.startConnection { connection in
            connection.pivSession { session, error in
                guard let session = session else { print("No session: \(error!)"); return }
                session.verifyPin(password) { result, error in
                    guard error == nil else {
                        let tokenError = error!.tokenError
                        switch tokenError {
                        case .wrongPassword(let message):
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: message.title)
                            if connection as? YKFNFCConnection != nil { completion(.alreadyHandled) }
                            else { completion(tokenError) }
                            return
                        default:
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: tokenError.message.title)
                            completion(error!.tokenError)
                            return
                        }
                    }
                    guard let type = userInfo.keyType(),
                          let algorithm = userInfo.algorithm(),
                          let message = userInfo.data() else { print("No data to sign"); return }
                    session.signWithKey(in: .authentication, type: type, algorithm: algorithm, message: message) { data, error in
                        YubiKitManager.shared.stopNFCConnection()
                        guard let data = data else { completion(error!.tokenError); return }
                        if let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator") {
                            print("Save data to userDefaults...")
                            userDefaults.setValue(data, forKey: "signedData")
                            completion(nil)
                        }
                    }
                }
            }
        }
    }
}

private extension Dictionary where Key == AnyHashable, Value: Any {
    func data() -> Data? {
        return self["data"] as? Data
    }
    
    func keyType() -> YKFPIVKeyType? {
        guard let rawValue = self["keyType"] as? UInt, let keyType = YKFPIVKeyType(rawValue: rawValue) else { return nil }
        return keyType
    }
    
    func algorithm() -> SecKeyAlgorithm? {
        guard let rawValue = self["algorithm"] as? String else { return nil }
        return SecKeyAlgorithm(rawValue: rawValue as CFString)
    }
}

extension String: Error {}

