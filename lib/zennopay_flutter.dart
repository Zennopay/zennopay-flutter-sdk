/// Zennopay PaymentSheet for Flutter — the embeddable, in-app cross-border QR
/// pay flow (scan → amount → confirm → status). One call in, one
/// [PaymentResult] out. See `Zennopay.presentSheet`.
library zennopay_flutter;

export 'src/zennopay.dart' show Zennopay;

// Public API surface
export 'src/models/payment_result.dart'
    show PaymentResult, Completed, Canceled, Failed, Pending, Receipt;
export 'src/models/zennopay_error.dart'
    show ZennopayError, ZennopayErrorCode;
export 'src/models/zennopay_config.dart'
    show ZennopayConfig, ZennopayEnvironment;
export 'src/models/scan_models.dart'
    show Merchant, Quote, ScanResult, PaymentIntentRecord, QrKind;
export 'src/appearance/zennopay_appearance.dart'
    show
        ZennopayAppearance,
        ZennopayColors,
        ZennopayShapes,
        ZennopayTypography,
        ZennopayPrimaryButton;

// Reusable, display-only EMVCo decode.
export 'src/models/emvco_parser.dart' show EmvCoParser, Tlv;
