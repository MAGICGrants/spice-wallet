/// Spice's brand widget set. The design tokens, pure primitives, and the
/// wallet-coupled coin/tx/connection widgets now live in the shared `wallet_ui`
/// package (D24). This barrel re-exports them so the ~56 `import '.../ui.dart'`
/// sites keep compiling unchanged.
library;

export 'package:wallet_ui/wallet_ui.dart'
    hide
        displayAmount,
        formatAmount,
        formatFiat,
        shortenMiddle,
        // Spice wraps the shared confirm-send sheet in its own
        // `screens/confirm_send.dart` (same name, app-specific signature).
        showConfirmSendSheet;
