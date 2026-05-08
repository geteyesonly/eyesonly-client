import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
	private let privacyShieldTag = 87_221

	override func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		super.scene(scene, willConnectTo: session, options: connectionOptions)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleScreenCaptureChanged),
			name: UIScreen.capturedDidChangeNotification,
			object: nil
		)

		updatePrivacyShield()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	override func sceneWillResignActive(_ scene: UIScene) {
		super.sceneWillResignActive(scene)
		showPrivacyShield()
	}

	override func sceneDidEnterBackground(_ scene: UIScene) {
		super.sceneDidEnterBackground(scene)
		showPrivacyShield()
	}

	override func sceneWillEnterForeground(_ scene: UIScene) {
		super.sceneWillEnterForeground(scene)
		updatePrivacyShield()
	}

	override func sceneDidBecomeActive(_ scene: UIScene) {
		super.sceneDidBecomeActive(scene)
		updatePrivacyShield()
	}

	@objc private func handleScreenCaptureChanged() {
		updatePrivacyShield()
	}

	private func updatePrivacyShield() {
		if UIScreen.main.isCaptured {
			showPrivacyShield()
		} else {
			hidePrivacyShield()
		}
	}

	private func showPrivacyShield() {
		guard let window else {
			return
		}
		if window.viewWithTag(privacyShieldTag) != nil {
			return
		}

		let shieldView = UIView(frame: window.bounds)
		shieldView.tag = privacyShieldTag
		shieldView.backgroundColor = .black
		shieldView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

		let iconView = UIImageView(image: UIImage(systemName: "lock.fill"))
		iconView.tintColor = .white
		iconView.contentMode = .scaleAspectFit
		iconView.translatesAutoresizingMaskIntoConstraints = false

		let titleLabel = UILabel()
		titleLabel.text = "Screen capture is disabled"
		titleLabel.textColor = .white
		titleLabel.font = .preferredFont(forTextStyle: .headline)
		titleLabel.textAlignment = .center
		titleLabel.translatesAutoresizingMaskIntoConstraints = false

		let messageLabel = UILabel()
		messageLabel.text = "Sensitive content is hidden while the app is inactive or being captured."
		messageLabel.textColor = .white.withAlphaComponent(0.8)
		messageLabel.font = .preferredFont(forTextStyle: .subheadline)
		messageLabel.textAlignment = .center
		messageLabel.numberOfLines = 0
		messageLabel.translatesAutoresizingMaskIntoConstraints = false

		shieldView.addSubview(iconView)
		shieldView.addSubview(titleLabel)
		shieldView.addSubview(messageLabel)
		window.addSubview(shieldView)

		NSLayoutConstraint.activate([
			iconView.centerXAnchor.constraint(equalTo: shieldView.centerXAnchor),
			iconView.centerYAnchor.constraint(equalTo: shieldView.centerYAnchor, constant: -36),
			iconView.heightAnchor.constraint(equalToConstant: 36),
			iconView.widthAnchor.constraint(equalToConstant: 36),

			titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
			titleLabel.leadingAnchor.constraint(equalTo: shieldView.leadingAnchor, constant: 24),
			titleLabel.trailingAnchor.constraint(equalTo: shieldView.trailingAnchor, constant: -24),

			messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
			messageLabel.leadingAnchor.constraint(equalTo: shieldView.leadingAnchor, constant: 24),
			messageLabel.trailingAnchor.constraint(equalTo: shieldView.trailingAnchor, constant: -24),
		])
	}

	private func hidePrivacyShield() {
		window?.viewWithTag(privacyShieldTag)?.removeFromSuperview()
	}

}
