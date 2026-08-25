import 'package:flutter/material.dart';

/// Spice brand design tokens, taken verbatim from the design handoff
/// (brand/screens/README.md + the literal inline styles in
/// `Wallet Screens.dc.html`). One source of truth for `lib/widgets/ui/`.

class BrandColors {
  BrandColors._();

  // Grounds & warm surfaces
  static const paper = Color(0xFFFFFDF6); // screen bg
  static const card = Color(0xFFFFFFFF); // raised list-item cards (lift off the cream ground)
  static const surfaceSunken = Color(0xFFF9F1E4); // fields, secondary buttons, tiles
  static const surfaceTinted = Color(0xFFF4EADB); // segmented-control track
  static const surfaceMuted = Color(0xFFF1E6D5); // disabled fills, neutral pills
  static const hairline = Color(0xFFF1E6D5); // dividers inside cards
  static const border = Color(0xFFEFE3D1); // card / tile borders
  static const borderStrong = Color(0xFFE4D5BE);
  static const inputBorder = Color(0xFFD8C1A2);
  static const frameEdge = Color(0xFFD8C7AC);

  // Ink
  static const ink = Color(0xFF2C170C);
  static const inkMuted = Color(0xFF7C6353);
  static const inkFaint = Color(0xFF9C8571);
  static const inkDisabled = Color(0xFFC4AE96);

  // Brand
  static const cinnamon = Color(0xFFA0451C); // primary buttons, selected states
  static const cinnamonDeep = Color(0xFF8A4B24); // save, links, quieter primary
  static const onCinnamon = Color(0xFFFFFDF6);

  // Semantic
  static const success = Color(0xFF2F7D6B);
  static const successBg = Color(0xFFE7F0E6);
  static const warning = Color(0xFFC98A2E);
  static const warningBg = Color(0xFFFBEFDC);
  static const error = Color(0xFFB04A2F);
  static const errorBg = Color(0xFFF8E4DC);
  static const routeTor = Color(0xFF6B4E9E);
  static const routeProxy = Color(0xFF37628F);

  // Chain brand
  static const monero = Color(0xFFFF6600);
  static const bitcoin = Color(0xFFF7931A);
  static const ethereum = Color(0xFF627EEA);
  static const dai = Color(0xFFF5AC37);
  static const serai = Color(0xFF2F7D6B);
}

class BrandRadii {
  BrandRadii._();
  static const badge = 6.0;
  static const tile = 12.0;
  static const button = 16.0;
  static const field = 18.0;
  static const card = 20.0;
  static const sheet = 22.0;
  static const pill = 999.0;

  static const rTile = BorderRadius.all(Radius.circular(tile));
  static const rButton = BorderRadius.all(Radius.circular(button));
  static const rField = BorderRadius.all(Radius.circular(field));
  static const rCard = BorderRadius.all(Radius.circular(card));
  static const rPill = BorderRadius.all(Radius.circular(pill));
}

class BrandSpacing {
  BrandSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0; // screen gutter
  static const xxl = 32.0;
}

class BrandMotion {
  BrandMotion._();
  /// Universal transition duration for all animated brand widgets.
  static const transition = Duration(milliseconds: 300);
}

class BrandShadows {
  BrandShadows._();
  static const soft = <BoxShadow>[
    BoxShadow(color: Color(0x142C170C), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const sheet = <BoxShadow>[
    BoxShadow(color: Color(0x382C170C), blurRadius: 40, offset: Offset(0, -10)),
  ];
}

/// Type scale. Ubuntu for UI text; Ubuntu Mono for every number, address, seed
/// word, hash and technical badge. Weights 400/500/700.
class BrandText {
  BrandText._();
  static const _ui = 'Ubuntu';
  static const _mono = 'Ubuntu Mono';
  static const _tnum = [FontFeature.tabularFigures()];

  static const balance = TextStyle(
    fontFamily: _mono,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.72, // -.02em
    height: 1,
    color: BrandColors.ink,
    fontFeatures: _tnum,
  );
  static const chainBalance = TextStyle(
    fontFamily: _mono,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1,
    color: BrandColors.ink,
    fontFeatures: _tnum,
  );
  static const title = TextStyle(
    fontFamily: _ui,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.24,
    height: 1.2,
    color: BrandColors.ink,
  );
  static const sheetTitle = TextStyle(
    fontFamily: _ui,
    fontSize: 21,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: BrandColors.ink,
  );
  static const appBar = TextStyle(
    fontFamily: _ui,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: BrandColors.ink,
  );
  static const listTitle = TextStyle(
    fontFamily: _ui,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: BrandColors.ink,
  );
  static const body = TextStyle(fontFamily: _ui, fontSize: 14, color: BrandColors.ink, height: 1.5);
  static const bodyMuted = TextStyle(
    fontFamily: _ui,
    fontSize: 14,
    color: BrandColors.inkMuted,
    height: 1.5,
  );
  static const caption = TextStyle(fontFamily: _ui, fontSize: 12, color: BrandColors.inkMuted);
  static const buttonLabel = TextStyle(fontFamily: _ui, fontSize: 16, fontWeight: FontWeight.w500);
  static const section = TextStyle(
    fontFamily: _mono,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2, // .12em
    color: BrandColors.inkMuted,
  );
  static const mono = TextStyle(
    fontFamily: _mono,
    fontSize: 13,
    color: BrandColors.inkMuted,
    fontFeatures: _tnum,
  );
  // Inline fiat balance — the hero balance treatment, smaller (row trailing).
  static const amount = TextStyle(
    fontFamily: _mono,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: BrandColors.ink,
    fontFeatures: _tnum,
  );
}

/// Material theme built from the brand tokens. Material stays structural
/// plumbing (Scaffold/Navigator); these keep default chrome on-brand.
ThemeData brandLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.cinnamon,
    primary: BrandColors.cinnamon,
    onPrimary: BrandColors.onCinnamon,
    secondary: BrandColors.cinnamonDeep,
    surface: BrandColors.paper,
    onSurface: BrandColors.ink,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: BrandColors.paper,
    fontFamily: 'Ubuntu',
  );
}

ThemeData brandDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BrandColors.cinnamon,
    brightness: Brightness.dark,
    secondary: BrandColors.cinnamonDeep,
  );
  return ThemeData(colorScheme: scheme, fontFamily: 'Ubuntu');
}
