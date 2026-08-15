import 'package:wallet_domain/wallet_domain.dart' show baseUnitsToDecimalString;

/// Base units → display double at [decimals] magnitude. Lossy (`double`); UI
/// only. `decimalToBaseUnits`/`baseUnitsToDecimalString` now live in
/// `wallet_domain`; import them from there.
double displayAmount(BigInt units, int decimals) =>
    double.tryParse(baseUnitsToDecimalString(units, decimals)) ?? 0;
