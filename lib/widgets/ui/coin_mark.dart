import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:spice_wallet/theme/brand.dart';
import 'package:spice_wallet/widgets/ui/coin_tile.dart';

/// A coin's icon: the chain-coloured tile with its white glyph for the known
/// chains, falling back to the coin's own logo asset for anything else.
class CoinMark extends StatelessWidget {
  final String coinSymbol;
  final String iconAsset;
  final double size;

  const CoinMark({
    super.key,
    required this.coinSymbol,
    required this.iconAsset,
    this.size = 40,
  });

  static ({Color color, String glyph})? _mark(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'XMR':
        return (color: BrandColors.monero, glyph: 'assets/icons/monero-glyph.svg');
      case 'BTC':
        return (color: BrandColors.bitcoin, glyph: 'assets/icons/bitcoin-glyph.svg');
      case 'TBTC':
        // Testnet Bitcoin — green to distinguish it from mainnet at a glance.
        return (color: const Color(0xFF3E9B6E), glyph: 'assets/icons/bitcoin-glyph.svg');
      case 'ETH':
        return (color: BrandColors.ethereum, glyph: 'assets/icons/ethereum-glyph.svg');
      case 'SETH':
        // Sepolia testnet — grey to distinguish it from mainnet Ethereum.
        return (color: const Color(0xFF8A8F98), glyph: 'assets/icons/ethereum-glyph.svg');
      case 'DAI':
        return (color: BrandColors.dai, glyph: 'assets/icons/dai-glyph.svg');
      case 'SDAI':
        // Sepolia testnet token — grey, matching Sepolia Ethereum.
        return (color: const Color(0xFF8A8F98), glyph: 'assets/icons/dai-glyph.svg');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mark = _mark(coinSymbol);
    if (mark == null) return SvgPicture.asset(iconAsset, width: size, height: size);
    return CoinTile(
      size: size,
      color: mark.color,
      glyph: SvgPicture.asset(mark.glyph, width: size * 0.63, height: size * 0.63),
    );
  }
}
