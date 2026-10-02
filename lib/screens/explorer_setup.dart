import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/connection_settings_form.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class ExplorerSetupScreenArgs {
  final String coinSymbol;

  ExplorerSetupScreenArgs({required this.coinSymbol});
}

/// Desktop: explorer setup as a modal (opened from the coin-settings modal).
void showExplorerSetupSheet(BuildContext context, {required String coinSymbol}) {
  showBrandSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight(ctx)),
      child: ExplorerSetupScreen(coinSymbol: coinSymbol, asModal: true),
    ),
  );
}

/// Sets up the optional Blockscout explorer (its own server, Tor/SSL, and
/// test) — separate from the node connection. Used for transaction history.
class ExplorerSetupScreen extends StatelessWidget {
  /// Set when shown as a modal; otherwise the coin comes from the route args.
  final String? coinSymbol;
  final bool asModal;

  const ExplorerSetupScreen({super.key, this.coinSymbol, this.asModal = false});

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments as ExplorerSetupScreenArgs?;
    final coinSymbol = this.coinSymbol ?? args?.coinSymbol ?? '';
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(coinSymbol);
    final configured = wallet?.explorerAddress.isNotEmpty ?? false;

    void onSaved() {
      // Refresh history through the newly-configured explorer.
      unawaited(wallet?.loadTxHistory());
      Navigator.pop(context);
    }

    void onRemove() {
      // Disable the explorer: clear its config, fall back to local history.
      wallet?.setExplorerConnection(address: '', proxyPort: '', useTor: false);
      unawaited(wallet?.persistExplorerConnection());
      unawaited(wallet?.loadTxHistory());
      // Captured before the pop: this context is defunct afterward.
      final toast = BrandToast.of(context);
      Navigator.pop(context);
      toast.show(i18n.explorerRemovedMessage);
    }

    final form = ConnectionSettingsForm(
      coinSymbol: coinSymbol,
      target: ConnectionTarget.explorer,
      saveButtonLabel: i18n.save,
      onSaved: onSaved,
      pinnedSave: !asModal,
    );

    final body = Column(
      mainAxisSize: asModal ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!asModal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: BrandScreenHeader(
              onBack: () => Navigator.pop(context),
              center: CoinBadge(wallet: wallet, fallback: coinSymbol),
              action: configured
                  ? IconCircleButton(icon: Icons.delete_outline, onPressed: onRemove)
                  : null,
            ),
          ),
        Padding(
          // Desktop modal: the card owns the edge padding.
          padding: EdgeInsets.fromLTRB(asModal ? 0 : 20, asModal ? 0 : 14, asModal ? 0 : 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i18n.explorerSetupTitle, style: BrandText.title),
                    const SizedBox(height: 8),
                    Text(
                      i18n.explorerSetupDescription,
                      style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              if (asModal && configured)
                IconCircleButton(icon: Icons.delete_outline, onPressed: onRemove),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (asModal) Flexible(child: SingleChildScrollView(child: form)) else Expanded(child: form),
      ],
    );

    if (asModal) return body;

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: body),
        ),
      ),
    );
  }
}
