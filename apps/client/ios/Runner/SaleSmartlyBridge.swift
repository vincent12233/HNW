import Flutter
import SalesmartlyChat
import UIKit

final class SaleSmartlyBridge: NSObject, FlutterPlugin {
  private static var initializedScriptURL: String?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "india_trading/salesmartly",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(SaleSmartlyBridge(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "openChat":
      guard
        let arguments = call.arguments as? [String: Any],
        let scriptURL = arguments["scriptUrl"] as? String,
        !scriptURL.isEmpty
      else {
        result(FlutterError(
          code: "missing_configuration",
          message: "SALESMARTLY_SCRIPT_URL is required",
          details: nil
        ))
        return
      }

      Task { @MainActor in
        do {
          if Self.initializedScriptURL != scriptURL {
            let context = SalesmartlyNativeBootstrapContext(
              sourceURL: "india-trading://support",
              userAgent: "India Trading iOS",
              navigatorLanguage: "en",
              beforeSourceURL: "",
              guestUserId: arguments["userId"] as? String ?? UUID().uuidString
            )
            try await SalesmartlyChat.initialize(
              scriptURL: scriptURL,
              nativeBootstrapContext: context
            )
            Self.initializedScriptURL = scriptURL
          }

          SalesmartlyChat.setLoginInfo(
            LoginInfo(
              userId: arguments["userId"] as? String ?? "",
              userName: arguments["userName"] as? String ?? "",
              language: "en",
              phone: arguments["phone"] as? String ?? "",
              email: "",
              description: "India Trading customer",
              labelNames: ["hnw", "ios"],
              customFieldsExt: [
                "source": "india-trading-ios",
              ]
            )
          )

          guard let presenter = Self.topViewController() else {
            result(FlutterError(
              code: "presentation_failed",
              message: "Unable to find the active app window",
              details: nil
            ))
            return
          }

          SalesmartlyChat.openChat()
          let chat = SalesmartlyChatViewController(runtime: SalesmartlyChat.runtime())
          chat.modalPresentationStyle = .overFullScreen
          presenter.present(chat, animated: true) {
            if let message = arguments["initialMessage"] as? String,
               !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              SalesmartlyChat.sendTextMessage(message)
            }
            result(nil)
          }
        } catch {
          result(FlutterError(
            code: "initialization_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }

    case "clearUser":
      SalesmartlyChat.clearUser()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @MainActor
  private static func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }?
      .rootViewController
    return topViewController(from: root)
  }

  @MainActor
  private static func topViewController(from viewController: UIViewController?) -> UIViewController? {
    if let presented = viewController?.presentedViewController {
      return topViewController(from: presented)
    }
    if let navigation = viewController as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tabs = viewController as? UITabBarController {
      return topViewController(from: tabs.selectedViewController)
    }
    return viewController
  }
}
