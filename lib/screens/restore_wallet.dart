import 'package:bip39/bip39.dart' as bip39;
// ignore: implementation_imports — the BIP39 English wordlist for per-word checks.
import 'package:bip39/src/wordlists/english.dart' show WORDLIST;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/util/secure_screen.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class RestoreWalletScreen extends StatefulWidget {
  const RestoreWalletScreen({super.key});

  @override
  State<RestoreWalletScreen> createState() => _RestoreWalletScreenState();
}

class _RestoreWalletScreenState extends State<RestoreWalletScreen> with SecureScreenMixin {
  static final Set<String> _wordSet = WORDLIST.toSet();

  DateTime? _restoreDate; // null once chosen = "I'm not sure" (scan from genesis)
  bool _scanChosen = false;
  bool _isLoading = false;

  bool _valid(String w) => _wordSet.contains(w);

  Future<void> _openScanFrom() async {
    final i18n = AppLocalizations.of(context)!;
    final result = await showScanFromSheet(
      context: context,
      initial: _restoreDate,
      chosen: _scanChosen,
      labels: ScanFromSheetLabels(
        title: i18n.restoreScanTitle,
        description: i18n.restoreScanDescription,
        pickMonth: i18n.restoreScanPickMonth,
        notSure: i18n.restoreScanNotSure,
        notSureDesc: i18n.restoreScanNotSureDesc,
        done: i18n.restoreScanDone,
        locale: Localizations.localeOf(context).toString(),
      ),
    );
    if (result != null) {
      setState(() {
        _restoreDate = result.date;
        _scanChosen = true;
      });
    }
  }

  Future<void> _restore(String mnemonic, String _) async {
    if (_isLoading) return;
    if (!bip39.validateMnemonic(mnemonic)) return;

    final i18n = AppLocalizations.of(context)!;
    final manager = Provider.of<WalletManager>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      await manager.restoreAll(
        seed: Bip39Seed(mnemonic),
        from: RestorePoint.date(_restoreDate ?? DateTime(2014, 4, 18)),
      );
    } catch (error) {
      log(LogLevel.error, error.toString());
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
      }
      return;
    }

    manager.syncInBackground();
    if (mounted) {
      Provider.of<FiatRateModel>(context, listen: false).startService(walletManager: manager);
      Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    final String scanValue;
    final TextStyle scanStyle;
    if (!_scanChosen) {
      scanValue = i18n.restoreWalletNotSet;
      scanStyle = BrandText.body.copyWith(color: BrandColors.inkFaint);
    } else if (_restoreDate != null) {
      scanValue = DateFormat.yMMM(Localizations.localeOf(context).toString()).format(_restoreDate!);
      scanStyle = BrandText.amount;
    } else {
      scanValue = i18n.restoreScanFromStart;
      scanStyle = BrandText.body;
    }

    return RestoreWalletView(
      labels: RestoreWalletLabels(
        title: i18n.restoreWalletTitle,
        subtitle: i18n.restoreWalletSubtitle,
        seedLength: i18n.restoreWalletSeedLength,
        paste: i18n.restoreWalletPaste,
        restoreButton: i18n.restoreWalletRestoreButton,
        badWord: (position) => i18n.restoreWalletBadWord(position),
        didYouMean: (word) => i18n.restoreWalletDidYouMean(word),
      ),
      seedTypes: [
        SeedTypeOption(
          id: 'bip39',
          label: 'BIP39', // single type → selector hidden, label unseen

          lengthOptions: const [12, 15, 18, 21, 24],
          defaultLength: 15,
          isValidWord: _valid,
          suggestWord: _suggest,
          mnemonicError: (mnemonic) =>
              bip39.validateMnemonic(mnemonic) ? null : i18n.restoreWalletChecksumError,
        ),
      ],
      restoring: _isLoading,
      canRestore: () => _scanChosen,
      onRestore: _restore,
      restorePointFields: ScanFromCard(
        label: i18n.restoreWalletScanFrom,
        reason: i18n.restoreWalletScanFromReason,
        value: scanValue,
        valueStyle: scanStyle,
        onTap: _openScanFrom,
      ),
    );
  }

  String? _suggestWord;
  String? _suggestResult;

  /// Closest wordlist word within edit distance 2, for the "did you mean" hint.
  /// Cached so it doesn't rescan 2048 words unless the input changed.
  String? _suggest(String word) {
    if (word == _suggestWord) return _suggestResult;
    _suggestWord = word;
    _suggestResult = _computeSuggest(word);
    return _suggestResult;
  }

  String? _computeSuggest(String word) {
    if (word.isEmpty) return null;
    String? best;
    var bestDist = 3;
    for (final w in WORDLIST) {
      if ((w.length - word.length).abs() >= bestDist) continue;
      final d = _levenshtein(word, w);
      if (d < bestDist) {
        bestDist = d;
        best = w;
      }
    }
    return best;
  }

  int _levenshtein(String a, String b) {
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final cur = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      cur[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        cur[j + 1] = [cur[j] + 1, prev[j + 1] + 1, prev[j] + cost].reduce((x, y) => x < y ? x : y);
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = cur[j];
      }
    }
    return prev[b.length];
  }
}
