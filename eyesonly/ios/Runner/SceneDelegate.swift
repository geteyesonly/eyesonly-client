import Flutter
import ScreenProtectorKit
import UIKit

class SceneDelegate: FlutterSceneDelegate {
	private let screenProtector = ScreenProtectorKit(window: nil)

	override func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		super.scene(scene, willConnectTo: session, options: connectionOptions)
		configureScreenshotProtection()
	}

	override func sceneDidBecomeActive(_ scene: UIScene) {
		super.sceneDidBecomeActive(scene)
		configureScreenshotProtection()
	}

	private func configureScreenshotProtection() {
		guard let window else {
			return
		}

		screenProtector.window = window
		screenProtector.setRootViewResolver(FlutterRootViewResolver())
		ScreenProtectorKit.initial(with: window.rootViewController?.view)
		screenProtector.enabledPreventScreenshot(
			text: "Screen capture is disabled",
			image: nil
		)
	}
}

private final class FlutterRootViewResolver: ScreenProtectorRootViewResolving {
	func resolveRootView() -> UIView? {
		guard Thread.isMainThread else {
			return nil
		}

		guard let windowScene = UIApplication.shared.connectedScenes
			.compactMap({ $0 as? UIWindowScene })
			.first(where: { $0.activationState == .foregroundActive }) else {
			return nil
		}

		guard let flutterVC = windowScene.windows
			.first(where: { $0.isKeyWindow })?
			.rootViewController as? FlutterViewController else {
			return nil
		}

		return flutterVC.view
	}
}
