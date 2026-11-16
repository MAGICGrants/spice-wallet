import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/l10n/shared_strings.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/widgets/ui/ui.dart' show LabeledAddressCoin, showAddressLabelSheet;
import 'package:wallet_domain/wallet_domain.dart';

/// [wallet]'s used receive addresses, read once per history revision.
///
/// Receive's Labeled tab, an address's own screen, History's address filter and
/// the transaction details all ask on every build; reading the history again
/// each time would rescan it per frame (and on Monero derive addresses through
/// the native library). Keyed on the wallet itself, so a wallet that is gone
/// takes its entry with it.
Future<List<UsedReceiveAddress>> usedReceiveAddresses(CryptoWallet wallet) {
  final revision = wallet.txHistoryRevision;
  final cached = _usedCache[wallet];
  if (cached != null && cached.revision == revision) return cached.addresses;
  final addresses = wallet.loadUsedReceiveAddresses().catchError((Object error) {
    log(LogLevel.error, 'Could not list used ${wallet.coinSymbol} receive addresses: $error');
    return const <UsedReceiveAddress>[];
  });
  _usedCache[wallet] = (revision: revision, addresses: addresses);
  return addresses;
}

final _usedCache = Expando<({int revision, Future<List<UsedReceiveAddress>> addresses})>(
  'usedReceiveAddresses',
);

/// How [wallet] writes its used addresses' totals and names them, or null for a
/// wallet that keeps a single address (Ethereum and its tokens).
LabeledAddressCoin? labeledAddressCoinOf(CryptoWallet wallet) {
  final kind = wallet.rotatingAddressKind;
  if (kind == null) return null;
  return (coinSymbol: wallet.coinSymbol, baseUnitDecimals: wallet.baseUnitDecimals, kind: kind);
}

/// Opens the label sheet on [used] and saves what it returns: a new label, or
/// none when the user cleared the field.
Future<void> editAddressLabel(
  BuildContext context,
  LabeledAddressCoin coin,
  UsedReceiveAddress used,
) async {
  final i18n = AppLocalizations.of(context)!;
  final labels = context.read<AddressLabelModel>();
  final label = await showAddressLabelSheet(
    context: context,
    strings: i18n.shared,
    coin: coin,
    used: used,
    initialLabel: labels.labelFor(coin.coinSymbol, used.address),
  );
  if (label != null) await labels.setLabel(coin.coinSymbol, used.address, label);
}
