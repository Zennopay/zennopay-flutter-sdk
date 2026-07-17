/// Zennopay PaymentSheet for Flutter — a thin native bridge over the native
/// Zennopay iOS/Android checkout sheets (scan → amount → confirm → status).
/// One call in, one [PaymentResult] out. See `Zennopay.presentSheet`.
library zennopay_flutter;

export 'src/zennopay.dart' show Zennopay;

// Public API surface — plain data classes serialized across the platform
// channel; the native SDKs own all UI, networking, and EMVCo decoding.
export 'src/models/payment_result.dart'
    show PaymentResult, Completed, Canceled, Failed, Pending, Receipt;
export 'src/models/zennopay_error.dart' show ZennopayError, ZennopayErrorCode;
export 'src/models/zennopay_config.dart'
    show ZennopayConfig, ZennopayEnvironment;
export 'src/appearance/zennopay_appearance.dart'
    show
        ZennopayAppearance,
        ZennopayColors,
        ZennopayShapes,
        ZennopayTypography,
        ZennopayPrimaryButton;
