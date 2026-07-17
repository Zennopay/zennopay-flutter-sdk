import Flutter
import UIKit
import Zennopay

/// Flutter plugin bridging Dart → the native Zennopay iOS PaymentSheet.
///
/// This is a THIN native bridge: it wraps `Zennopay.presentCheckout(...)` from
/// the native iOS SDK and resolves the Dart `present` call exactly once with a
/// map-encoded `PaymentResult`. It renders no UI itself — the native SDK owns
/// scan / amount / confirm / status (and the platform accessibility that comes
/// with it).
///
/// The host `refreshSession` hook is serviced by calling back into Dart over
/// the same channel (`refreshSession`) and awaiting the reply, so the native
/// SDK's async refresh never blocks the platform thread.
public final class ZennopayFlutterPlugin: NSObject, FlutterPlugin {

  private let channel: FlutterMethodChannel

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "zennopay_flutter",
      binaryMessenger: registrar.messenger()
    )
    let instance = ZennopayFlutterPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "present":
      present(call: call, result: result)
    case "presentReceipt":
      presentReceipt(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - present

  private func present(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let intentId = args["intentId"] as? String,
      let sessionJwt = args["sessionJwt"] as? String
    else {
      result(FlutterError(
        code: "invalid_jwt",
        message: "present requires intentId + sessionJwt.",
        details: nil
      ))
      return
    }

    let configMap = args["config"] as? [String: Any] ?? [:]
    let appearanceMap = args["appearance"] as? [String: Any] ?? [:]
    let config = ZennopayCodec.config(from: configMap)
    let appearance = ZennopayCodec.appearance(from: appearanceMap)

    Task { @MainActor in
      guard let presenter = ZennopayFlutterPlugin.topViewController() else {
        result(FlutterError(
          code: "network_error",
          message: "No UIViewController available to present the Zennopay sheet.",
          details: nil
        ))
        return
      }

      Zennopay.presentCheckout(
        from: presenter,
        intentID: intentId,
        sessionJWT: sessionJwt,
        refreshSession: { [weak self] intent in
          await self?.requestRefreshedSession(for: intent)
        },
        appearance: appearance,
        config: config
      ) { paymentResult in
        result(ZennopayCodec.map(from: paymentResult))
      }
    }
  }

  // MARK: - presentReceipt

  private func presentReceipt(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let intentId = args["intentId"] as? String,
      let receiptToken = args["receiptToken"] as? String
    else {
      result(FlutterError(
        code: "invalid_jwt",
        message: "presentReceipt requires intentId + receiptToken.",
        details: nil
      ))
      return
    }

    let configMap = args["config"] as? [String: Any] ?? [:]
    let appearanceMap = args["appearance"] as? [String: Any] ?? [:]
    let config = ZennopayCodec.config(from: configMap)
    let appearance = ZennopayCodec.appearance(from: appearanceMap)

    Task { @MainActor in
      guard let presenter = ZennopayFlutterPlugin.topViewController() else {
        result(FlutterError(
          code: "network_error",
          message: "No UIViewController available to present the Zennopay receipt.",
          details: nil
        ))
        return
      }

      Zennopay.presentReceipt(
        from: presenter,
        intentID: intentId,
        receiptToken: receiptToken,
        refreshReceiptToken: { [weak self] intent in
          await self?.requestRefreshedReceiptToken(for: intent)
        },
        config: config,
        appearance: appearance
      ) {
        // The receipt is a read-only surface: it resolves the Dart call with
        // no value once the user dismisses it.
        result(nil)
      }
    }
  }

  // MARK: - refreshSession round-trip (native → Dart)

  private func requestRefreshedSession(for intentId: String) async -> String? {
    await requestRefreshedToken(method: "refreshSession", intentId: intentId)
  }

  /// Fired by the native SDK on a 401 mid-poll on the receipt: ask Dart for a
  /// fresh receipt token.
  private func requestRefreshedReceiptToken(for intentId: String) async -> String? {
    await requestRefreshedToken(method: "refreshReceiptToken", intentId: intentId)
  }

  private func requestRefreshedToken(method: String, intentId: String) async -> String? {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        self.channel.invokeMethod(
          method,
          arguments: ["intentId": intentId]
        ) { reply in
          continuation.resume(returning: reply as? String)
        }
      }
    }
  }

  // MARK: - Top view controller

  @MainActor
  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let keyWindow = scenes
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
      ?? scenes.first?.windows.first
    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

/// Translates the channel maps to/from the native SDK's value types.
enum ZennopayCodec {

  // MARK: config

  static func config(from map: [String: Any]) -> ZennopayConfig {
    let base = (map["apiBaseUrl"] as? String)
      .flatMap(URL.init(string:)) ?? ZennopayConfig.staging.apiBaseURL
    let pollTimeout = (map["statusPollTimeoutSeconds"] as? NSNumber)?.doubleValue ?? 90
    let maxInterval = (map["maxPollIntervalSeconds"] as? NSNumber)?.doubleValue ?? 4
    let quoteTtl = (map["defaultQuoteTtlSeconds"] as? NSNumber)?.doubleValue ?? 30
    return ZennopayConfig(
      apiBaseURL: base,
      statusPollTimeout: pollTimeout,
      maxPollInterval: maxInterval,
      defaultQuoteTTL: quoteTtl
    )
  }

  // MARK: appearance

  static func appearance(from map: [String: Any]) -> ZennopayAppearance {
    let colorsMap = map["colors"] as? [String: Any] ?? [:]
    let darkMap = colorsMap["dark"] as? [String: Any] ?? [:]

    func color(_ key: String, _ fallback: UInt32) -> UIColor {
      let light = hex(colorsMap[key] as? String) ?? fallback
      let dark = hex(darkMap[key] as? String) ?? light
      return UIColor(zpLight: light, zpDark: dark)
    }

    let colors = ZennopayAppearance.Colors(
      primary: color("primary", 0x1B6B2F),
      background: color("background", 0xFAFAF8),
      surface: color("surface", 0xFFFFFF),
      textPrimary: color("textPrimary", 0x0A0F14),
      textSecondary: color("textSecondary", 0x5A6675),
      textTertiary: color("textTertiary", 0x687280),
      border: color("border", 0xE8E9EC),
      success: color("success", 0x15803D),
      pending: color("pending", 0x7C5E1A),
      failure: color("failure", 0xA53939)
    )

    let radiusMap = map["cornerRadius"] as? [String: Any] ?? [:]
    let cornerRadius = ZennopayAppearance.CornerRadius(
      input: cg(radiusMap["input"]) ?? 4,
      card: cg(radiusMap["card"]) ?? 8,
      slide: cg(radiusMap["slide"]) ?? 12
    )

    let fontMap = map["font"] as? [String: Any] ?? [:]
    let font = ZennopayAppearance.Font(
      family: fontMap["family"] as? String ?? "General Sans",
      scale: cg(fontMap["scale"]) ?? 1
    )

    let buttonMap = map["primaryButton"] as? [String: Any] ?? [:]
    let primaryButton = ZennopayAppearance.PrimaryButton(
      background: UIColor(zpRGB: hex(buttonMap["background"] as? String) ?? 0x1B6B2F),
      textColor: UIColor(zpRGB: hex(buttonMap["textColor"] as? String) ?? 0xFFFFFF),
      cornerRadius: cg(buttonMap["cornerRadius"]) ?? 8
    )

    let mode: ZennopayAppearance.Mode
    switch map["mode"] as? String {
    case "light": mode = .light
    case "dark": mode = .dark
    default: mode = .automatic
    }

    let logo = (map["logo"] as? String).flatMap { UIImage(named: $0) }

    return ZennopayAppearance(
      mode: mode,
      colors: colors,
      cornerRadius: cornerRadius,
      font: font,
      primaryButton: primaryButton,
      logo: logo
    )
  }

  // MARK: result

  static func map(from result: PaymentResult) -> [String: Any] {
    switch result {
    case let .completed(intentID):
      return ["status": "completed", "intentId": intentID]
    case let .pending(intentID):
      return ["status": "pending", "intentId": intentID]
    case let .canceled(intentID):
      return ["status": "canceled", "intentId": intentID]
    case let .failed(intentID, error):
      return [
        "status": "failed",
        "intentId": intentID,
        "error": ["code": wireCode(error)],
      ]
    }
  }

  /// Collapse the native iOS `ZennopayError` onto the stable Flutter wire codes
  /// (`ZennopayErrorCode.wire`) so Dart's `fromWire` resolves them directly.
  private static func wireCode(_ error: ZennopayError) -> String {
    switch error {
    case .invalidJWT, .malformedToken, .jwtMissingClaim, .presentationContextMissing:
      return "invalid_jwt"
    case .intentMismatch:
      return "intent_mismatch"
    case .jwtExpired, .sessionExpired:
      return "jwt_expired"
    case .confirmReplay:
      return "jti_replay"
    case .invalidQRCode:
      return "qr_invalid"
    case .quoteExpired:
      return "quote_expired"
    case .paymentFailed:
      return "confirm_failed"
    case .userCanceled:
      return "canceled"
    case .cameraPermissionDenied:
      return "camera_denied"
    case .timedOut:
      return "timed_out"
    case .networkError, .serverError:
      return "network_error"
    }
  }

  // MARK: helpers

  private static func hex(_ string: String?) -> UInt32? {
    guard var s = string else { return nil }
    if s.hasPrefix("#") { s.removeFirst() }
    return UInt32(s, radix: 16)
  }

  private static func cg(_ value: Any?) -> CGFloat? {
    (value as? NSNumber).map { CGFloat(truncating: $0) }
  }
}
