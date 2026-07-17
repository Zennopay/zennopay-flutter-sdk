package `in`.zennopay.flutter

import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.compose.ui.unit.dp
import com.zennopay.sdk.PaymentResult
import com.zennopay.sdk.Zennopay
import com.zennopay.sdk.ZennopayConfig
import com.zennopay.sdk.ui.ZennopayAppearance
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * Flutter plugin bridging Dart → the native Zennopay Android PaymentSheet.
 *
 * A THIN native bridge: it wraps `com.zennopay.sdk.Zennopay.presentCheckout(...)`
 * against the current Activity and resolves the Dart `present` call exactly once
 * with a map-encoded [PaymentResult]. It renders no UI itself — the native SDK
 * owns scan / amount / confirm / status (and the platform accessibility that
 * comes with it).
 *
 * The host `refreshSession` hook is serviced by calling back into Dart over the
 * same channel (`refreshSession`) and awaiting the reply, so the native SDK's
 * `suspend` refresh never blocks.
 */
class ZennopayFlutterPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activity: ComponentActivity? = null

    /** The Flutter result for the in-flight `present` call. Single-shot. */
    private var pendingResult: Result? = null

    /** The Flutter result for the in-flight `presentReceipt` call. Single-shot. */
    private var pendingReceiptResult: Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "zennopay_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ---- ActivityAware --------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? ComponentActivity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as? ComponentActivity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ---- MethodCallHandler ----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "present" -> present(call, result)
            "presentReceipt" -> presentReceipt(call, result)
            else -> result.notImplemented()
        }
    }

    private fun present(call: MethodCall, result: Result) {
        val intentId = call.argument<String>("intentId")
        val sessionJwt = call.argument<String>("sessionJwt")
        if (intentId == null || sessionJwt == null) {
            result.error("invalid_jwt", "present requires intentId + sessionJwt.", null)
            return
        }

        val host = activity
        if (host == null) {
            result.error(
                "network_error",
                "No ComponentActivity available to present the Zennopay sheet.",
                null,
            )
            return
        }

        val config = ZennopayCodec.config(call.argument<Map<String, Any?>>("config"))
        val appearance = ZennopayCodec.appearance(call.argument<Map<String, Any?>>("appearance"))

        pendingResult = result

        Zennopay.presentCheckout(
            activity = host,
            intentId = intentId,
            sessionJwt = sessionJwt,
            refreshSession = { intent -> requestRefreshedSession(intent) },
            appearance = appearance,
            config = config,
        ) { paymentResult ->
            mainHandler.post {
                pendingResult?.success(ZennopayCodec.map(paymentResult))
                pendingResult = null
            }
        }
    }

    private fun presentReceipt(call: MethodCall, result: Result) {
        val intentId = call.argument<String>("intentId")
        val receiptToken = call.argument<String>("receiptToken")
        if (intentId == null || receiptToken == null) {
            result.error("invalid_jwt", "presentReceipt requires intentId + receiptToken.", null)
            return
        }

        val host = activity
        if (host == null) {
            result.error(
                "network_error",
                "No ComponentActivity available to present the Zennopay receipt.",
                null,
            )
            return
        }

        val config = ZennopayCodec.config(call.argument<Map<String, Any?>>("config"))
        val appearance = ZennopayCodec.appearance(call.argument<Map<String, Any?>>("appearance"))

        pendingReceiptResult = result

        Zennopay.presentReceipt(
            activity = host,
            intentId = intentId,
            receiptToken = receiptToken,
            refreshReceiptToken = { intent -> requestRefreshedReceiptToken(intent) },
            config = config,
            appearance = appearance,
        ) {
            // The receipt is a read-only surface: resolve the Dart call with no
            // value once the user dismisses it.
            mainHandler.post {
                pendingReceiptResult?.success(null)
                pendingReceiptResult = null
            }
        }
    }

    /** Fired by the native SDK on 401/expiry: ask Dart for a fresh JWT. */
    private suspend fun requestRefreshedSession(intentId: String): String? =
        requestRefreshedToken("refreshSession", intentId)

    /** Fired by the native SDK on a 401 mid-poll on the receipt: ask Dart for a
     * fresh receipt token. */
    private suspend fun requestRefreshedReceiptToken(intentId: String): String? =
        requestRefreshedToken("refreshReceiptToken", intentId)

    private suspend fun requestRefreshedToken(method: String, intentId: String): String? =
        suspendCancellableCoroutine { continuation ->
            mainHandler.post {
                channel.invokeMethod(
                    method,
                    mapOf("intentId" to intentId),
                    object : Result {
                        override fun success(result: Any?) =
                            continuation.resume(result as? String)

                        override fun error(code: String, message: String?, details: Any?) =
                            continuation.resume(null)

                        override fun notImplemented() =
                            continuation.resume(null)
                    },
                )
            }
        }
}

/** Translates the channel maps to/from the native SDK's value types. */
private object ZennopayCodec {

    fun config(map: Map<String, Any?>?): ZennopayConfig {
        val m = map ?: emptyMap()
        val environment = when (m["environment"] as? String) {
            "production" -> ZennopayConfig.Environment.PRODUCTION
            "custom" -> ZennopayConfig.Environment.CUSTOM
            else -> ZennopayConfig.Environment.STAGING
        }
        val base = (m["apiBaseUrl"] as? String)
            ?: ZennopayConfig.DEFAULT_STAGING_BASE_URL
        val timeoutMillis =
            ((m["maxPollIntervalSeconds"] as? Number)?.toLong()?.times(1000)) ?: 20_000L
        return ZennopayConfig(
            apiBaseUrl = base,
            environment = environment,
            requestTimeoutMillis = timeoutMillis.coerceAtLeast(1_000L),
        )
    }

    fun appearance(map: Map<String, Any?>?): ZennopayAppearance {
        val m = map ?: return ZennopayAppearance.Automatic
        @Suppress("UNCHECKED_CAST")
        val colorsMap = m["colors"] as? Map<String, Any?> ?: emptyMap()

        val colors = ZennopayAppearance.Colors(
            primary = argb(colorsMap["primary"], 0xFF1B6B2F),
            background = argb(colorsMap["background"], 0xFFFAFAF8),
            surface = argb(colorsMap["surface"], 0xFFFFFFFF),
            textPrimary = argb(colorsMap["textPrimary"], 0xFF0A0F14),
            textSecondary = argb(colorsMap["textSecondary"], 0xFF5A6675),
            textTertiary = argb(colorsMap["textTertiary"], 0xFF687280),
            border = argb(colorsMap["border"], 0xFFE8E9EC),
            success = argb(colorsMap["success"], 0xFF15803D),
            pending = argb(colorsMap["pending"], 0xFF7C5E1A),
            failure = argb(colorsMap["failure"], 0xFFA53939),
        )

        @Suppress("UNCHECKED_CAST")
        val radius = m["cornerRadius"] as? Map<String, Any?> ?: emptyMap()
        val shapes = ZennopayAppearance.Shapes(
            input = ((radius["input"] as? Number)?.toDouble() ?: 4.0).dp,
            card = ((radius["card"] as? Number)?.toDouble() ?: 8.0).dp,
            slide = ((radius["slide"] as? Number)?.toDouble() ?: 12.0).dp,
        )

        @Suppress("UNCHECKED_CAST")
        val font = m["font"] as? Map<String, Any?> ?: emptyMap()
        val typography = ZennopayAppearance.Typography(
            // Arbitrary partner font families can't be resolved to a Compose
            // FontFamily here; the native SDK falls back to its bundled sans.
            fontFamily = null,
            scale = (font["scale"] as? Number)?.toFloat() ?: 1f,
        )

        @Suppress("UNCHECKED_CAST")
        val button = m["primaryButton"] as? Map<String, Any?> ?: emptyMap()
        val primaryButton = ZennopayAppearance.PrimaryButton(
            background = argb(button["background"], 0xFF1B6B2F),
            textColor = argb(button["textColor"], 0xFFFFFFFF),
            cornerRadius = ((button["cornerRadius"] as? Number)?.toDouble() ?: 8.0).dp,
        )

        val mode = when (m["mode"] as? String) {
            "light" -> ZennopayAppearance.Mode.Light
            "dark" -> ZennopayAppearance.Mode.Dark
            else -> ZennopayAppearance.Mode.Automatic
        }

        return ZennopayAppearance(
            mode = mode,
            colors = colors,
            shapes = shapes,
            typography = typography,
            primaryButton = primaryButton,
            logo = null,
        )
    }

    fun map(result: PaymentResult): Map<String, Any?> = when (result) {
        is PaymentResult.Completed -> mapOf(
            "status" to "completed",
            "intentId" to result.intentId,
            "receipt" to mapOfNonNull(
                "merchantName" to result.merchantName,
                "localAmount" to result.localAmount,
                "localCurrency" to result.localCurrency,
                "usdDebited" to result.usdDebited,
                "transactionId" to result.transactionId,
                "verifiableQrData" to result.verifiableQrData,
            ),
        )
        is PaymentResult.Pending -> mapOf(
            "status" to "pending",
            "intentId" to result.intentId,
        )
        is PaymentResult.Canceled -> mapOf(
            "status" to "canceled",
            "intentId" to (result.intentId ?: ""),
        )
        is PaymentResult.Failed -> mapOf(
            "status" to "failed",
            "intentId" to (result.intentId ?: ""),
            "error" to mapOf("code" to wireCode(result.error.code)),
        )
    }

    /**
     * Collapse the native Android dotted error codes onto the stable Flutter
     * wire codes (`ZennopayErrorCode.wire`) so Dart's `fromWire` resolves them.
     */
    private fun wireCode(code: String): String = when (code) {
        "client.invalid_jwt", "client.malformed_token",
        "client.invalid_issuer", "client.missing_intent_id" -> "invalid_jwt"
        "client.intent_mismatch", "jwt.intent_id_mismatch_with_path" -> "intent_mismatch"
        "client.jwt_expired", "auth.refresh_failed", "auth.unauthorized" -> "jwt_expired"
        "jwt.jti_replay" -> "jti_replay"
        "scanner.camera_denied" -> "camera_denied"
        "scanner.qr_undecodable", "scan.validation_failed" -> "qr_invalid"
        "confirm.quote_expired", "confirm.quote_mismatch",
        "confirm.quote_superseded" -> "quote_expired"
        "confirm.dynamic_amount_override" -> "amount_not_allowed"
        "confirm.not_scanned", "jwt.intent_invalid_state",
        "payment.declined" -> "confirm_failed"
        "status.polling_timeout" -> "timed_out"
        "network.error" -> "network_error"
        else -> "network_error"
    }

    private fun mapOfNonNull(vararg pairs: Pair<String, Any?>): Map<String, Any?>? {
        val filtered = pairs.filter { it.second != null }
        return if (filtered.isEmpty()) null else filtered.toMap()
    }

    private fun argb(value: Any?, fallback: Long): Long {
        val hex = value as? String ?: return fallback
        val rgb = hex.removePrefix("#").toLongOrNull(16) ?: return fallback
        return 0xFF000000L or (rgb and 0xFFFFFF)
    }
}
