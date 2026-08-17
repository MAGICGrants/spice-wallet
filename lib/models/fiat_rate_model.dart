// FiatRateModel lives in wallet-core (`wallet_fiat`, multicoin). Kept under the
// same import path so call sites are unchanged; the app supplies the Tor proxy
// via FiatRates.install in wallet_core_glue.dart.
export 'package:wallet_fiat/wallet_fiat.dart' show FiatRateModel, FiatApiMode;
