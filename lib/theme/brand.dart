// Spice's brand tokens now live in the shared `wallet_ui` design system; this
// re-export keeps the ~56 `import 'package:spice_wallet/theme/brand.dart'`
// call sites compiling. The concrete palette is `spicePalette` (theme/palette.dart),
// installed via `BrandColors.install(spicePalette)` in `main()`.
export 'package:wallet_ui/design.dart';
