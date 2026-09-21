import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/screens/connection_setup.dart';
import 'package:spice_wallet/screens/explorer_setup.dart';
import 'package:spice_wallet/screens/lws_keys.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class CoinSettingsScreenArgs {
  final String coinSymbol;

  CoinSettingsScreenArgs({required this.coinSymbol});
}

/// Per-blockchain settings groups (connection, explorer, keys), shared by the
/// mobile screen and the desktop modal.
List<Widget> coinSettingsGroups(BuildContext context, CryptoWallet wallet) {
  final i18n = AppLocalizations.of(context)!;
  final coinSymbol = wallet.coinSymbol;
  // Desktop opens these options as stacked modals; mobile navigates full screens.
  final connectionValue = wallet.connectionAddress.isNotEmpty
      ? wallet.connectionAddress
      : i18n.settingsCoinNotConfigured;
  final explorerValue = wallet.explorerAddress.isNotEmpty
      ? wallet.explorerAddress
      : i18n.settingsCoinNotConfigured;

  return [
    SettingsGroup(
      label: i18n.settingsCoinConnectionSection,
      tiles: [
        SettingsNavTile(
          title: i18n.settingsCoinConnectionSetup,
          value: connectionValue,
          valueMono: true,
          onTap: () => isDesktop
              ? showConnectionSetupSheet(context, coinSymbol: coinSymbol)
              : Navigator.pushNamed(
                  context,
                  '/connection_setup',
                  arguments: ConnectionSetupScreenArgs(coinSymbol: coinSymbol),
                ),
        ),
        if (wallet.supportsExplorerUrl)
          SettingsNavTile(
            title: i18n.settingsCoinExplorer,
            value: explorerValue,
            valueMono: true,
            onTap: () => isDesktop
                ? showExplorerSetupSheet(context, coinSymbol: coinSymbol)
                : Navigator.pushNamed(
                    context,
                    '/explorer_setup',
                    arguments: ExplorerSetupScreenArgs(coinSymbol: coinSymbol),
                  ),
          ),
      ],
    ),
    if (coinSymbol == 'XMR') ...[
      const SizedBox(height: 20),
      SettingsGroup(
        label: i18n.settingsCoinKeysSection,
        tiles: [
          SettingsLinkTile(
            title: i18n.lwsKeysTitle,
            linkLabel: i18n.settingsLwsViewKeysButton,
            onTap: () =>
                isDesktop ? showLwsKeysSheet(context) : Navigator.pushNamed(context, '/lws_keys'),
          ),
        ],
      ),
    ],
  ];
}

/// Desktop: per-blockchain settings as a modal (the coin-home gear opens this).
void showCoinSettingsSheet(BuildContext context, {required String coinSymbol}) {
  final wallet = context.read<WalletManager>().getWallet(coinSymbol);
  if (wallet == null) return;
  final i18n = AppLocalizations.of(context)!;
  showBrandSheet<void>(
    context: context,
    isScrollControlled: true,
    // Desktop-only: the modal card owns the edge padding.
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHandle(),
        Center(
          child: CoinBadge(wallet: wallet, label: '${wallet.blockchainName} ${i18n.settingsTitle}'),
        ),
        const SizedBox(height: 18),
        ...coinSettingsGroups(sheetContext, wallet),
      ],
    ),
  );
}

/// Per-blockchain settings (server connection, explorer, keys). Reached from the
/// coin-home gear.
class CoinSettingsScreen extends StatelessWidget {
  const CoinSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments as CoinSettingsScreenArgs?;
    final coinSymbol = args?.coinSymbol ?? 'XMR';
    final wallet = context.watch<WalletManager>().getWallet(coinSymbol);

    if (wallet == null) {
      return Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Center(child: Text('Unknown coin: $coinSymbol', style: BrandText.body)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: BrandScreenHeader(
                    onBack: () => Navigator.pop(context),
                    center: CoinBadge(
                      wallet: wallet,
                      label: '${wallet.blockchainName} ${i18n.settingsTitle}',
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: coinSettingsGroups(context, wallet),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
