import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/screens/coin_home.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/widgets/connection_settings_form.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class ConnectionSetupScreenArgs {
  final String coinSymbol;

  ConnectionSetupScreenArgs({required this.coinSymbol});
}

/// Desktop: connection setup as a modal (opened from the coin-settings modal).
void showConnectionSetupSheet(BuildContext context, {required String coinSymbol}) {
  showBrandSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight(ctx)),
      child: ConnectionSetupScreen(coinSymbol: coinSymbol, asModal: true),
    ),
  );
}

class ConnectionSetupScreen extends StatefulWidget {
  /// Set when shown as a modal; otherwise the coin comes from the route args.
  final String? coinSymbol;
  final bool asModal;

  const ConnectionSetupScreen({super.key, this.coinSymbol, this.asModal = false});

  @override
  State<ConnectionSetupScreen> createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends State<ConnectionSetupScreen> {
  bool? _wasConfigured;
  String? _selectedType; // 'lws' / 'node' / '' — reported by the form.

  /// Name shown in "Enter the address of your {type}.", following the form's
  /// segmented selection (Monero LWS ↔ node) rather than the persisted type.
  String _descriptionType(AppLocalizations i18n, CryptoWallet? wallet) {
    switch (_selectedType) {
      case 'lws':
        return i18n.connectionTypeLws;
      case 'node':
        return i18n.connectionTypeNode;
      default:
        return wallet?.connectionTypeName ?? 'server';
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final args = ModalRoute.of(context)?.settings.arguments as ConnectionSetupScreenArgs?;
    final coinSymbol = widget.coinSymbol ?? args?.coinSymbol ?? 'XMR';
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(coinSymbol);
    final connectionTypeName = _descriptionType(i18n, wallet);

    _wasConfigured ??= wallet?.connectionAddress.isNotEmpty ?? false;

    void onSaved() {
      unawaited(() async {
        // Rebuild first if the server kind changed (e.g. Monero LWS↔node),
        // then refresh against the new connection.
        await manager.applyConnectionChange(coinSymbol);
        await manager.getWallet(coinSymbol)?.load();

        // Tokens (e.g. DAI) piggyback on this chain's connection but hold their
        // own in-memory copy. Re-read it so their balances load now, instead of
        // only after a restart re-hydrates every wallet's persisted connection.
        for (final token in tokensOf(manager, coinSymbol)) {
          await token.loadPersistedConnection();
          await token.load();
        }
      }());

      // Modal, or editing an existing connection: return to where it opened.
      // A first-time setup (from the coin card) advances into the coin home.
      if (widget.asModal || _wasConfigured == true) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(
          context,
          '/coin_home',
          arguments: CoinHomeScreenArgs(coinSymbol: coinSymbol),
        );
      }
    }

    final form = ConnectionSettingsForm(
      coinSymbol: coinSymbol,
      saveButtonLabel: i18n.save,
      onSaved: onSaved,
      // Modal sizes to content (inline Save); the full screen pins Save to the
      // bottom of the available height.
      pinnedSave: !widget.asModal,
      onConnectionTypeChanged: (type) {
        if (type != _selectedType) setState(() => _selectedType = type);
      },
    );

    final body = Column(
      mainAxisSize: widget.asModal ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.asModal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: BrandScreenHeader(
              onBack: () => Navigator.pop(context),
              center: CoinBadge(wallet: wallet, fallback: coinSymbol),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            // Desktop modal: the card owns the edge padding.
            widget.asModal ? 0 : 20,
            widget.asModal ? 0 : 14,
            widget.asModal ? 0 : 20,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // In the modal there's no header, so the coin mark leads the title
              // (as the LWS keys modal does).
              if (widget.asModal && wallet != null)
                Row(
                  children: [
                    CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 34),
                    const SizedBox(width: 11),
                    Expanded(child: Text(i18n.connectionSetupTitle, style: BrandText.title)),
                  ],
                )
              else
                Text(i18n.connectionSetupTitle, style: BrandText.title),
              const SizedBox(height: 8),
              Text(
                _selectedType == 'lws'
                    ? i18n.connectionSetupDescriptionLws(connectionTypeName)
                    : i18n.connectionSetupDescription(connectionTypeName),
                style: BrandText.bodyMuted.copyWith(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (widget.asModal)
          Flexible(child: SingleChildScrollView(child: form))
        else
          Expanded(child: form),
      ],
    );

    if (widget.asModal) return body;

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
