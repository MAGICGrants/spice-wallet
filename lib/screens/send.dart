import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/consts.dart' as consts;
import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/amount_units.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/models/contact_model.dart';
import 'package:spice_wallet/models/fiat_rate_model.dart';
import 'package:spice_wallet/screens/coin_home.dart';
import 'package:spice_wallet/screens/confirm_send.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/util/format.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class SendScreenArgs {
  final String coinSymbol;
  final String destinationAddress;
  final double? amount;

  /// Set when the address came from a contact (e.g. Send in the address book),
  /// so Send opens showing the contact card rather than a bare address.
  final Contact? contact;

  SendScreenArgs({
    required this.coinSymbol,
    required this.destinationAddress,
    this.amount,
    this.contact,
  });
}

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

final domainRegex = RegExp(r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z]{2,})+$');

class _SendScreenState extends State<SendScreen> {
  bool _isLoading = false;
  bool _isLoadingFees = false;
  bool _feesInProgress = false;
  final _destinationAddressController = TextEditingController(text: '');
  final _amountController = TextEditingController(text: '');
  bool _isSweepAll = false;
  Contact? _selectedContact;

  /// Fee per priority, for display. Filled from the coin's own estimate where it
  /// has one, otherwise from a transaction built to find out.
  List<BigInt?>? _fees;

  /// Transactions built during fee calculation, kept so [_send] can reuse the
  /// selected one. Null entries where the fee came from an estimate instead.
  List<PendingTransaction?>? _feeTxs;
  int _selectedPriority = 1; // 0=Low, 1=Normal, 2=High
  int _feeCalculationCounter = 0;
  String _lastFeeFetchKey = '';
  Timer? _feeDebounce;
  // Bumped on every fee-state change so the (separately-routed) priority
  // selector sheet can rebuild live via a ValueListenableBuilder.
  final ValueNotifier<int> _feeRevision = ValueNotifier(0);

  String _destinationAddressError = '';
  String _lastAddressText = ''; // guards against selection-only listener fires
  String _amountError = '';
  int _openAliasResolving = 0; // >0 while OpenAlias resolution is in flight
  bool _formValid = false; // gates the send button
  final FocusNode _addressFocusNode = FocusNode();
  // Caches the last OpenAlias resolution so re-validation (e.g. amount changes)
  // doesn't repeat the network lookup. Output '' = failed/none.
  String _resolveCacheInput = '';
  String _resolveCacheOutput = '';

  String _coinSymbol = 'XMR';
  bool _argsLoaded = false;

  // Anchored "From" asset dropdown.
  final LayerLink _assetMenuLink = LayerLink();
  final OverlayPortalController _assetMenuController = OverlayPortalController();
  bool _assetMenuOpen = false;

  CryptoWallet _wallet(BuildContext context) {
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(_coinSymbol);
    if (wallet == null) {
      throw StateError('No wallet for $_coinSymbol');
    }
    return wallet;
  }

  /// Typed amount in integer base units at display precision, or null if the
  /// field isn't a valid number. Avoids handling money as a `double`.
  BigInt? _amountUnits(CryptoWallet wallet) {
    final text = _amountController.text.trim();
    if (text.isEmpty) return BigInt.zero;
    try {
      return decimalToBaseUnits(text, wallet.baseUnitDecimals);
    } catch (_) {
      return null;
    }
  }

  /// Compares the typed amount to the unlocked balance in exact integer base
  /// units, so we never use fragile `double ==`/`>`. Returns <0, 0, >0; or null
  /// when either value is unavailable.
  int? _compareAmountToBalance(CryptoWallet wallet) {
    final balanceUnits = wallet.unlockedBalanceBaseUnits;
    final amountUnits = _amountUnits(wallet);
    if (balanceUnits == null || amountUnits == null) return null;
    return amountUnits.compareTo(balanceUnits);
  }

  Future<String> _resolveAddressIfDomain(String value) async {
    final wallet = _wallet(context);
    if (!domainRegex.hasMatch(value)) return value;
    // All coins use the DNSSEC-over-Tor OpenAlias resolver (Monero included).
    // Empty result → caller shows the resolve error.
    if (wallet.aliasAsset.isNotEmpty) {
      if (value == _resolveCacheInput) return _resolveCacheOutput; // avoid re-lookup
      final i18n = AppLocalizations.of(context)!;
      // Counter (not a bool): resolution runs from several call sites that can
      // overlap (validate, fee calc, send), so the spinner stays up until all
      // finish.
      if (mounted) setState(() => _openAliasResolving++);
      String resolved = '';
      String error = '';
      try {
        resolved = (await wallet.resolveAlias(value))?.address ?? '';
        error = resolved.isEmpty ? i18n.sendOpenAliasResolveError : '';
      } catch (e) {
        log(LogLevel.warn, 'openalias resolve failed: $e', coin: wallet.coinSymbol);
        resolved = '';
        error = i18n.sendOpenAliasResolveError;
      } finally {
        if (mounted) {
          setState(() {
            _openAliasResolving--;
            _destinationAddressError = error;
          });
        }
      }
      _resolveCacheInput = value;
      _resolveCacheOutput = resolved;
      return resolved;
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    _destinationAddressController.addListener(_onAddressChanged);
    _amountController.addListener(_onAmountChanged);
    _addressFocusNode.addListener(_onAddressFocusChanged);
  }

  @override
  void dispose() {
    _feeDebounce?.cancel();
    _destinationAddressController.removeListener(_onAddressChanged);
    _amountController.removeListener(_onAmountChanged);
    _addressFocusNode.removeListener(_onAddressFocusChanged);
    _addressFocusNode.dispose();
    _destinationAddressController.dispose();
    _amountController.dispose();
    _feeRevision.dispose();
    super.dispose();
  }

  /// Resolve OpenAlias when the address field loses focus (the user finished
  /// typing), rather than on every keystroke.
  void _onAddressFocusChanged() {
    if (!_addressFocusNode.hasFocus) {
      _feeDebounce?.cancel();
      unawaited(() async {
        // Resolve the alias even if the amount isn't filled yet (shows the
        // spinner / address error). Fee calc runs after and reuses the cache.
        await _resolveDestinationAddress();
        await _calculateFeesIfValid();
      }());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    _loadFormFromArgs();
  }

  void _loadFormFromArgs() {
    final args = ModalRoute.of(context)!.settings.arguments as SendScreenArgs?;

    if (args != null) {
      _coinSymbol = args.coinSymbol;
      _destinationAddressController.text = args.destinationAddress;
      _amountController.text = args.amount != null ? args.amount.toString() : '';
      // Same pair the in-send picker sets, so the contact card renders here too.
      _selectedContact = args.contact;
    }
  }

  void _pasteAddressFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || !mounted) return;

    final text = data.text ?? '';
    // Assigning text fires _onAddressChanged, which clears any stale error; then
    // surface the invalid-address warning inline so a bad paste is seen at once
    // rather than only on focus-loss.
    _destinationAddressController.text = text;
    _showInvalidAddressIfNeeded(text);
  }

  /// Sets the inline `Invalid <coin> address` error immediately for a pasted or
  /// scanned value. OpenAlias domains are skipped — they resolve on unfocus.
  void _showInvalidAddressIfNeeded(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final wallet = _wallet(context);
    if (domainRegex.hasMatch(trimmed) && wallet.aliasAsset.isNotEmpty) return;
    if (!wallet.isAddressValid(trimmed)) {
      setState(
        () => _destinationAddressError = AppLocalizations.of(
          context,
        )!.invalidAddressForChain(wallet.blockchainName),
      );
    }
  }

  Future<void> _scanQrCode() async {
    final wallet = _wallet(context);

    final result = await Navigator.pushNamed(context, '/scan_qr');

    if (result == null || result is! String) return;

    String address = '';
    double? amount;
    final uri = Uri.tryParse(result);

    if (uri != null && uri.scheme.toLowerCase() == wallet.coinSymbol.toLowerCase()) {
      if (!wallet.isAddressValid(uri.path)) {
        if (mounted) {
          _destinationAddressController.text = uri.path;
          _showInvalidAddressIfNeeded(uri.path);
        }
        return;
      }

      address = uri.path;

      if (uri.queryParameters.containsKey('tx_amount')) {
        amount = double.tryParse(uri.queryParameters['tx_amount']!);
      }
    } else if (wallet.isAddressValid(result)) {
      address = result;
    } else {
      if (mounted) {
        _destinationAddressController.text = result;
        _showInvalidAddressIfNeeded(result);
      }
      return;
    }

    _destinationAddressController.text = address;
    if (amount != null) {
      _amountController.text = amount.toString();
    }
  }

  void _showContactPicker() async {
    // Contacts hold one address per blockchain; a token (DAI) uses its chain's.
    final manager = Provider.of<WalletManager>(context, listen: false);
    final contactModel = Provider.of<ContactModel>(context, listen: false);
    final i18n = AppLocalizations.of(context)!;
    final chainSymbol = chainSymbolOf(_wallet(context));
    final chain = manager.getWallet(chainSymbol) ?? _wallet(context);

    final contact = await showContactPickerSheet<Contact>(
      context: context,
      labels: ContactPickerLabels(
        title: i18n.sendPickContactTitle,
        subtitle: i18n.sendPickContactSubtitle(chain.blockchainName),
        searchHint: i18n.addressBookSearchHint,
        cancel: i18n.cancel,
        noContacts: i18n.addressBookNoContactsForCoin(chainSymbol),
        noResults: i18n.addressBookNoSearchResults,
      ),
      headerIcon: CoinMark(coinSymbol: chainSymbol, iconAsset: chain.iconAsset, size: 34),
      search: (query) {
        final results = contactModel.searchContacts(query);
        // Selectable contacts (with an address on this chain) first.
        bool has(Contact c) => c.addressFor(chainSymbol) != null;
        final ordered = [...results.where(has), ...results.where((c) => !has(c))];
        return [for (final c in ordered) _contactEntry(c, chain, chainSymbol)];
      },
    );

    if (contact == null || !mounted) return;
    final address = contact.addressFor(chainSymbol);
    if (address == null) return;
    setState(() {
      _selectedContact = contact;
      _destinationAddressController.text = address;
    });
  }

  ContactPickerEntry<Contact> _contactEntry(
    Contact contact,
    CryptoWallet chain,
    String chainSymbol,
  ) {
    final i18n = AppLocalizations.of(context)!;
    final address = contact.addressFor(chainSymbol);
    final enabled = address != null;
    // Enabled: this chain's badge + address. Disabled: the first chain the
    // contact does have, so the "No X address" reason reads honestly.
    final badgeSymbol = enabled
        ? chainSymbol
        : (contact.addresses.keys.isNotEmpty ? contact.addresses.keys.first : chainSymbol);
    return ContactPickerEntry<Contact>(
      value: contact,
      name: contact.name,
      addressShort: enabled ? shortenMiddle(address, head: 8, tail: 10) : null,
      disabledReason: enabled ? null : i18n.sendContactNoAddress(chain.blockchainName),
      badgeCoinSymbol: badgeSymbol,
    );
  }

  void _clearSelectedContact() {
    _destinationAddressController.text = '';

    setState(() {
      _selectedContact = null;
    });
  }

  Future<String> _resolveDestinationAddress() async {
    return _resolveAddressIfDomain(_destinationAddressController.text);
  }

  Future<bool> _validateForm({bool setErrors = true}) async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final unresolvedDestinationAddress = _destinationAddressController.text;
    String destinationAddress = '';

    if (amount == 0) {
      return false;
    }

    final wallet = _wallet(context);
    final i18n = AppLocalizations.of(context)!;

    if (domainRegex.hasMatch(unresolvedDestinationAddress)) {
      destinationAddress = await _resolveAddressIfDomain(unresolvedDestinationAddress);

      if (destinationAddress == '') {
        if (setErrors) {
          setState(() {
            _destinationAddressError = i18n.sendOpenAliasResolveError;
          });
        }
        return false;
      }
    } else if (wallet.isAddressValid(unresolvedDestinationAddress)) {
      destinationAddress = unresolvedDestinationAddress;
    } else {
      if (setErrors) {
        setState(() {
          _destinationAddressError = i18n.invalidAddressForChain(wallet.blockchainName);
        });
      }
      return false;
    }

    if (destinationAddress.isEmpty) return false;

    if ((_compareAmountToBalance(wallet) ?? 1) > 0) {
      if (setErrors) {
        setState(() {
          _amountError = i18n.sendInsufficientBalanceError;
        });
      }
      return false;
    }

    return true;
  }

  Future<PendingTransaction?> _createTxForPriority(String destinationAddress, int priority) async {
    final wallet = _wallet(context);
    final amountUnits = _amountUnits(wallet) ?? BigInt.zero;
    final maxRetries = 10;

    for (int i = 0; i < maxRetries; i++) {
      try {
        return await wallet.createTx(
          destinationAddress,
          amountUnits,
          _isSweepAll,
          priority: priority,
        );
      } catch (error) {
        if (error.toString().contains('Unlocked funds too low')) {
          return null;
        }

        if (i == maxRetries - 1) {
          rethrow;
        }
      }
    }

    throw Exception('Failed to create fee priority transaction after $maxRetries retries');
  }

  Future<void> _calculateFees() async {
    final feeFetchKey = '${_destinationAddressController.text}-${_amountController.text}';

    if (feeFetchKey == _lastFeeFetchKey) {
      return;
    }

    _lastFeeFetchKey = feeFetchKey;

    final i18n = AppLocalizations.of(context)!;

    _feeCalculationCounter++;
    final currentRequest = _feeCalculationCounter;

    setState(() {
      _isLoadingFees = true;
      _feesInProgress = true;
      _fees = null;
      _feeTxs = null;
    });
    _feeRevision.value++;

    final destinationAddress = await _resolveDestinationAddress();

    try {
      final fees = List<BigInt?>.filled(3, null);
      final builtTxs = List<PendingTransaction?>.filled(3, null);
      final priorityOrder = [
        _selectedPriority,
        for (var i = 0; i < 3; i++)
          if (i != _selectedPriority) i,
      ];

      for (final idx in priorityOrder) {
        if (currentRequest != _feeCalculationCounter) return;

        await Future<void>.delayed(Duration.zero);

        // wallet-core prices a transaction by building it — there is no separate
        // fee estimate — so build one per priority to read its fee.
        final tx = await _createTxForPriority(destinationAddress, idx + 1);
        builtTxs[idx] = tx;
        fees[idx] = tx?.feeBaseUnits;

        if (currentRequest == _feeCalculationCounter && mounted) {
          setState(() {
            _fees = List.from(fees);
            _feeTxs = List.from(builtTxs);
            if (idx == _selectedPriority) {
              _isLoadingFees = false;
            }
          });
          _feeRevision.value++;
        }
      }

      if (currentRequest == _feeCalculationCounter && mounted) {
        setState(() {
          _isLoadingFees = false;
          _feesInProgress = false;

          if (_fees?[_selectedPriority] == null) {
            for (int i = _selectedPriority; i >= 0; i--) {
              if (_fees?[i] != null) {
                _selectedPriority = i;
                break;
              }
            }
          }
        });
        _feeRevision.value++;
      }
    } catch (error) {
      if (currentRequest == _feeCalculationCounter && mounted) {
        setState(() {
          _isLoadingFees = false;
          _feesInProgress = false;
        });
        _feeRevision.value++;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.sendFailedToGetFeesError)));
      }
    }
  }

  Future<void> _send() async {
    final wallet = _wallet(context);
    final i18n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _destinationAddressError = '';
      _amountError = '';
    });

    final isValid = await _validateForm();

    if (!isValid) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final destinationAddressUnresolved = _destinationAddressController.text;
    final amountUnits = _amountUnits(wallet) ?? BigInt.zero;
    String destinationAddress = '';
    String? destinationOpenAlias;

    if (domainRegex.hasMatch(destinationAddressUnresolved)) {
      destinationAddress = await _resolveAddressIfDomain(destinationAddressUnresolved);
      destinationOpenAlias = destinationAddressUnresolved;
    } else {
      destinationAddress = destinationAddressUnresolved;
    }

    try {
      PendingTransaction tx;

      final currentFeeFetchKey = '${_destinationAddressController.text}-${_amountController.text}';
      final cachedTx = _feeTxs != null && _feeTxs!.length > _selectedPriority
          ? _feeTxs![_selectedPriority]
          : null;

      if (currentFeeFetchKey == _lastFeeFetchKey && cachedTx != null) {
        tx = cachedTx;
      } else {
        tx = await wallet.createTx(
          destinationAddress,
          amountUnits,
          _isSweepAll,
          priority: _selectedPriority + 1,
        );
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final committed = await showConfirmSendSheet(
          context,
          ConfirmSendScreenArgs(
            coinSymbol: _coinSymbol,
            tx: tx,
            destinationAddress: destinationAddress,
            destinationOpenAlias: destinationOpenAlias,
            destinationContactName: _selectedContact?.name,
          ),
        );
        if (committed == true && mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/coin_home',
            // remove until the coin home screen is reached
            (route) => route.settings.name == '/wallet_home',
            arguments: CoinHomeScreenArgs(coinSymbol: _coinSymbol, showTxSuccessToast: true),
          );
        }
      }
    } catch (error) {
      if (error.toString().contains('Insufficient gas funds')) {
        setState(() {
          _amountError = i18n.sendInsufficientGasError;
        });
      } else if (error.toString().contains('Unlocked funds too low')) {
        if ((_compareAmountToBalance(wallet) ?? 0) < 0) {
          setState(() {
            _amountError = i18n.sendInsufficientBalanceToCoverFeeError;
          });
        } else {
          setState(() {
            _amountError = i18n.sendInsufficientBalanceError;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i18n.unknownError)));
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _setBalanceAsSendAmount() {
    final wallet = _wallet(context);
    final units = wallet.unlockedBalanceBaseUnits;
    _amountController.text = units == null
        ? ''
        : baseUnitsToDecimalString(units, wallet.baseUnitDecimals);

    setState(() {
      _isSweepAll = true;
    });
  }

  void _setPriority(int priority) {
    if (priority == _selectedPriority) return;
    // Fees for all three priorities are computed together in _calculateFees, so
    // switching just re-reads the cached one (no recalculation needed).
    setState(() => _selectedPriority = priority);
    _feeRevision.value++;
  }

  void _onAddressChanged() {
    // The controller also notifies on selection changes — setting text emits a
    // second, selection-only fire a frame later. Ignore those, or that fire
    // would wipe the invalid-address error a paste just set.
    final text = _destinationAddressController.text;
    if (text == _lastAddressText) return;
    _lastAddressText = text;

    // Input changed: invalidate the resolution cache + clear any stale error.
    _resolveCacheInput = '';
    _resolveCacheOutput = '';
    if (_destinationAddressError.isNotEmpty) {
      setState(() => _destinationAddressError = '');
    }

    final isOpenAliasDomain = domainRegex.hasMatch(text) && _wallet(context).aliasAsset.isNotEmpty;

    // While the user is actively typing a domain, defer the (network) OpenAlias
    // resolution until the field unfocuses. Just clear fees + disable send.
    if (isOpenAliasDomain && _addressFocusNode.hasFocus) {
      _feeDebounce?.cancel();
      _feeCalculationCounter++;
      setState(() {
        _fees = null;
        _feeTxs = null;
        _isLoadingFees = false;
        _feesInProgress = false;
        _formValid = false;
      });
      _feeRevision.value++;
      return;
    }

    _scheduleFeeCalculation();
  }

  void _onAmountChanged() {
    final wallet = _wallet(context);
    final isFullBalance = _compareAmountToBalance(wallet) == 0;

    if (isFullBalance && !_isSweepAll) {
      setState(() {
        _isSweepAll = true;
      });
    }

    if (!isFullBalance && _isSweepAll) {
      setState(() {
        _isSweepAll = false;
      });
    }

    _scheduleFeeCalculation();
  }

  void _scheduleFeeCalculation() {
    _feeDebounce?.cancel();
    _feeDebounce = Timer(Duration(milliseconds: 400), () {
      unawaited(_calculateFeesIfValid());
    });
  }

  Future<void> _calculateFeesIfValid() async {
    final wallet = _wallet(context);
    final amountUnits = _amountUnits(wallet);

    if (amountUnits == null ||
        amountUnits <= BigInt.zero ||
        (_compareAmountToBalance(wallet) ?? 1) > 0) {
      _feeCalculationCounter++;
      _lastFeeFetchKey = '';
      if (mounted) {
        setState(() {
          _isLoadingFees = false;
          _feesInProgress = false;
          _fees = null;
          _feeTxs = null;
          _formValid = false;
        });
        _feeRevision.value++;
      }
      return;
    }

    final valid = await _validateForm(setErrors: false);
    if (mounted) setState(() => _formValid = valid);
    if (valid) {
      await _calculateFees();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final walletManager = context.watch<WalletManager>();
    final wallet = walletManager.getWallet(_coinSymbol);

    if (wallet == null) {
      return Scaffold(
        backgroundColor: BrandColors.paper,
        body: SafeArea(
          child: Center(child: Text('Unknown coin: $_coinSymbol', style: BrandText.body)),
        ),
      );
    }

    final fiatRate = context.watch<FiatRateModel>();
    final fiatSymbol = consts.currencySymbols[fiatRate.fiatCode] ?? '\$';
    final coinRate = fiatRate.rateFor(wallet.coinSymbol);

    final amount = double.tryParse(_amountController.text) ?? 0;
    final amountFiat = coinRate != null ? amount * coinRate : 0.0;

    return SendView(
      labels: SendLabels(
        title: i18n.sendTitle,
        toLabel: i18n.sendToLabel,
        amount: i18n.amount,
        priorityHeading: i18n.sendPriorityHeading,
        networkFee: i18n.sendNetworkFee,
        sendButton: i18n.sendSendButton,
        cancel: i18n.cancel,
        pasteButton: i18n.sendPasteButton,
        scanButton: i18n.sendScanButton,
        contactsButton: i18n.sendContactsButton,
        maxButton: i18n.sendMaxButton,
        // Anchor the label to the settlement chain, not the asset — a DAI send
        // goes to an "Ethereum address", not a "Dai address".
        addressHint: i18n.sendAddressHint(chainNameOf(walletManager, wallet)),
        priorityLabels: [i18n.sendPriorityLow, i18n.sendPriorityNormal, i18n.sendPriorityHigh],
      ),
      onBack: () => Navigator.pop(context),
      assetSection: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            label: i18n.sendFromLabel,
            padding: const EdgeInsets.only(left: 4, bottom: 8),
          ),
          _fromCard(wallet, assetsOnChainOf(walletManager, wallet), fiatRate, fiatSymbol),
        ],
      ),
      addressController: _destinationAddressController,
      addressFocusNode: _addressFocusNode,
      addressError: _destinationAddressError,
      openAliasResolving: _openAliasResolving > 0,
      onPaste: _pasteAddressFromClipboard,
      onScan: _scanQrCode,
      onPickContact: _showContactPicker,
      contactName: _selectedContact?.name,
      contactAddressShort: _selectedContact != null
          ? shortenMiddle(_destinationAddressController.text, head: 8, tail: 10)
          : null,
      onClearContact: _clearSelectedContact,
      amountController: _amountController,
      amountError: _amountError,
      onMax: _setBalanceAsSendAmount,
      coinSymbol: wallet.coinSymbol,
      amountFiatText: '≈ ${formatFiat(amountFiat, fiatSymbol)}',
      selectedPriority: _selectedPriority,
      onSelectPriority: _setPriority,
      feeValue: _feeValue(wallet, fiatSymbol, coinRate),
      onCancel: () => Navigator.pop(context),
      onSend: (_formValid && _openAliasResolving == 0 && !_isLoading) ? _send : null,
      sendLoading: _isLoading,
    );
  }

  Widget _fromCard(
    CryptoWallet wallet,
    List<CryptoWallet> assets,
    FiatRateModel fiatRate,
    String fiatSymbol,
  ) {
    final canChoose = assets.length > 1;
    final card = AnimatedContainer(
      duration: BrandMotion.transition,
      decoration: BoxDecoration(color: BrandColors.card, borderRadius: BorderRadius.circular(16)),
      // Border drawn over the content (CSS border-box) so thickening it on open
      // doesn't shift the layout.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _assetMenuOpen ? BrandColors.primary : BrandColors.border,
          width: _assetMenuOpen ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          CoinMark(coinSymbol: wallet.coinSymbol, iconAsset: wallet.iconAsset, size: 32),
          const SizedBox(width: 12),
          Expanded(child: _assetLabel(wallet)),
          if (canChoose)
            AnimatedRotation(
              turns: _assetMenuOpen ? 0.5 : 0,
              duration: BrandMotion.transition,
              child: Icon(Icons.keyboard_arrow_down, size: 20, color: BrandColors.inkMuted),
            ),
        ],
      ),
    );
    if (!canChoose) return card;
    return CompositedTransformTarget(
      link: _assetMenuLink,
      child: OverlayPortal(
        controller: _assetMenuController,
        overlayChildBuilder: (ctx) => _assetDropdown(ctx, assets, fiatRate, fiatSymbol),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleAssetMenu,
          child: card,
        ),
      ),
    );
  }

  void _toggleAssetMenu() {
    setState(() => _assetMenuOpen = !_assetMenuOpen);
    if (_assetMenuOpen) {
      FocusScope.of(context).unfocus();
      _assetMenuController.show();
    } else {
      _assetMenuController.hide();
    }
  }

  void _closeAssetMenu() {
    if (!_assetMenuOpen) return;
    setState(() => _assetMenuOpen = false);
    _assetMenuController.hide();
  }

  Widget _assetDropdown(
    BuildContext ctx,
    List<CryptoWallet> assets,
    FiatRateModel fiatRate,
    String fiatSymbol,
  ) {
    final width = math.min(MediaQuery.of(ctx).size.width, 480.0) - 32;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeAssetMenu),
        ),
        CompositedTransformFollower(
          link: _assetMenuLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: SizedBox(
            width: width,
            child: Material(
              color: Colors.transparent,
              child: BrandCard(
                radius: 20,
                clipBehavior: Clip.antiAlias,
                shadow: const [
                  BoxShadow(color: Color(0x1F2C170C), blurRadius: 24, offset: Offset(0, 12)),
                ],
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final asset in assets) _assetDropdownRow(asset, fiatRate, fiatSymbol),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _assetDropdownRow(CryptoWallet asset, FiatRateModel fiatRate, String fiatSymbol) {
    final i18n = AppLocalizations.of(context)!;
    final configured = asset.connectionAddress.isNotEmpty;
    final selected = asset.coinSymbol == _coinSymbol;
    final balance = asset.unlockedBalance;
    final rate = fiatRate.rateFor(asset.coinSymbol);
    final fiat = (rate != null && balance is double && !fiatRate.isDisabled)
        ? balance * rate
        : null;
    final subtitle = !configured
        ? i18n.homeNoConnection
        : (balance is double
              ? formatAmount(balance, asset.decimals, symbol: asset.coinSymbol)
              : '—');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? BrandColors.surfaceSunken : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _closeAssetMenu();
            _selectAsset(asset.coinSymbol);
          },
          child: Opacity(
            opacity: configured ? 1 : 0.5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
              child: Row(
                children: [
                  CoinMark(coinSymbol: asset.coinSymbol, iconAsset: asset.iconAsset, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.assetName,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                            color: BrandColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Ubuntu Mono',
                            fontSize: 11.5,
                            height: 1.3,
                            color: BrandColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fiat != null ? '$fiatSymbol${NumberFormat('#,##0').format(fiat)}' : '—',
                    style: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 13,
                      color: BrandColors.inkMuted,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check, size: 18, color: BrandColors.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _assetLabel(CryptoWallet wallet) {
    final i18n = AppLocalizations.of(context)!;
    final balance = wallet.unlockedBalance;
    final available = balance == null
        ? '—'
        : '${formatAmount(balance, wallet.decimals)} ${i18n.sendAvailableSuffix}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wallet.assetName,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.25,
            color: BrandColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          available,
          style: TextStyle(
            fontFamily: 'Ubuntu Mono',
            fontSize: 11.5,
            height: 1.3,
            color: BrandColors.inkMuted,
          ),
        ),
      ],
    );
  }

  /// Switches the send form to a different asset on the same chain. The picker
  /// only offers same-chain assets (all EVM), which share an address format, so
  /// the destination is kept; only the amount and fee state (asset-specific) reset.
  void _selectAsset(String coinSymbol) {
    if (coinSymbol == _coinSymbol) return;
    setState(() {
      _coinSymbol = coinSymbol;
      _isSweepAll = false;
      _fees = null;
      _feeTxs = null;
      _isLoadingFees = false;
      _feesInProgress = false;
      _formValid = false;
      _amountError = '';
      _lastFeeFetchKey = '';
    });
    _feeCalculationCounter++;
    _amountController.clear(); // fires _onAmountChanged → revalidates for the new asset
  }

  Widget _feeValue(CryptoWallet wallet, String fiatSymbol, double? coinRate) {
    final feeUnits = (_fees != null && _fees!.length > _selectedPriority)
        ? _fees![_selectedPriority]
        : null;
    if (_isLoadingFees || (_feesInProgress && feeUnits == null)) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.primary),
      );
    }
    if (feeUnits == null) {
      return Text(
        '—',
        style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12, color: BrandColors.inkMuted),
      );
    }
    final fee = displayAmount(feeUnits, wallet.feeBaseUnitDecimals);
    final feeStr = formatAmount(fee, wallet.feeDecimals, symbol: wallet.feeCoinSymbol);
    final feeFiat = (coinRate != null && !wallet.feeIsForeign)
        ? ' · ${formatFiat(fee * coinRate, fiatSymbol)}'
        : '';
    return Text(
      '$feeStr$feeFiat',
      style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12, color: BrandColors.inkMuted),
    );
  }
}
