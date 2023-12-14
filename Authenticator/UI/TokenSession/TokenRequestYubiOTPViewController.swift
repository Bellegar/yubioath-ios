//
//  TokenRequestYubiOTP.swift
//  Authenticator
//
//  Created by Jens Utbult on 2023-12-11.
//  Copyright © 2023 Yubico. All rights reserved.
//

import Foundation

@available(iOS 14.0, *)
class TokenRequestYubiOTPViewController: UIViewController {
    
    var viewModel: TokenRequestViewModel?

    @IBOutlet weak var optionsView: UIStackView!
    @IBOutlet weak var completedView: UIStackView!
    
    
    override func viewDidLoad() {
        self.viewModel?.waitForKeyRemoval { [weak self] in
            self?.dismiss(animated: true)
        }
    }
    
    @IBAction func disableOTP() {
        viewModel?.disableOTP { error in
            guard error == nil else {
                self.presentError(error)
                return
            }
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.5) {
                    self.optionsView.alpha = 0
                    self.completedView.alpha = 1
                }
            }
        }
    }
    
    @IBAction func ignoreThisKey() {
        viewModel?.ignoreThisKey { error in
            guard error == nil else {
                self.presentError(error)
                return
            }
            DispatchQueue.main.async {
                self.dismiss(animated: true)
            }
        }
    }
    
    private func presentError(_ error: Error?) {
        guard let error else { return }
        let alert = UIAlertController(title: "Error reading YubiKey", message: "\(error.localizedDescription)\n\nRemove and reinsert your YubiKey.") { self.dismiss(animated: true) }
        self.present(alert, animated: true, completion: nil)
    }
}
