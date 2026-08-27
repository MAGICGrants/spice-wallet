import 'dart:async';
import 'dart:io';
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
import 'package:spice_wallet/screens/confirm_send.dart';
import 'package:spice_wallet/util/coin_assets.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class SendScreenArgs {
  final String coinSymbol;
  final String destinationAddress;
  final double? amount;

  SendScreenArgs({required this.coinSymbol, required this.destinationAddress, this.amount});
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
  List<PendingTransaction?>? _fees;
  int _selectedPriority = 1; // 0=Low, 1=Normal, 2=High
  int _feeCalculationCounter = 0;
  String _lastFeeFetchKey = '';
  Timer? _feeDebounce;
  // Bumped on every fee-state change so the (separately-routed) priority
  // selector sheet can rebuild live via a ValueListenableBuilder.
  final ValueNotifier<int> _feeRevision = ValueNotifier(0);

  String _destinationAddressError = '';
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
    }
  }

  void _pasteAddressFromClipboard() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);

    if (data != null) {
      _destinationAddressController.text = data.text ?? '';
    }
  }

  Future<void> _scanQrCode() async {
    final wallet = _wallet(context);
    final i18n = AppLocalizations.of(context)!;

    final result = await Navigator.pushNamed(context, '/scan_qr');

    if (result == null || result is! String) return;

    String address = '';
    double? amount;
    final uri = Uri.tryParse(result);

    if (uri != null && uri.scheme.toLowerCase() == wallet.coinSymbol.toLowerCase()) {
      if (!wallet.isAddressValid(uri.path)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.sendInvalidAddressError)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(i18n.sendInvalidAddressError)));
      }
      return;
    }

    _destinationAddressController.text = address;
    if (amount != null) {
      _amountController.text = amount.toString();
    }
  }

  void _showContactPicker() {
    // Contacts hold one address per blockchain; a token (DAI) uses its chain's.
    final chainSymbol = chainSymbolOf(_wallet(context));
    showDialog(
      context: context,
      builder: (context) => _ContactPickerDialog(
        coinSymbol: chainSymbol,
        onContactSelected: (contact) {
          final address = contact.addressFor(chainSymbol);
          if (address == null) return;

          setState(() {
            _selectedContact = contact;
            _destinationAddressController.text = address;
          });
          Navigator.of(context).pop();
        },
      ),
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
          _destinationAddressError = i18n.sendInvalidAddressError;
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
    });
    _feeRevision.value++;

    final destinationAddress = await _resolveDestinationAddress();

    try {
      final fees = List<PendingTransaction?>.filled(3, null);
      final priorityOrder = [
        _selectedPriority,
        for (var i = 0; i < 3; i++)
          if (i != _selectedPriority) i,
      ];

      for (final idx in priorityOrder) {
        if (currentRequest != _feeCalculationCounter) return;

        await Future<void>.delayed(Duration.zero);

        fees[idx] = await _createTxForPriority(destinationAddress, idx + 1);

        if (currentRequest == _feeCalculationCounter && mounted) {
          setState(() {
            _fees = List.from(fees);
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
      final cachedTx = _fees != null && _fees!.length > _selectedPriority
          ? _fees![_selectedPriority]
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
        Navigator.pushNamed(
          context,
          '/confirm_send',
          arguments: ConfirmSendScreenArgs(
            coinSymbol: _coinSymbol,
            tx: tx,
            destinationAddress: destinationAddress,
            destinationOpenAlias: destinationOpenAlias,
            destinationContactName: _selectedContact?.name,
          ),
        );
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
    // Input changed: invalidate the resolution cache + clear any stale error.
    _resolveCacheInput = '';
    _resolveCacheOutput = '';
    if (_destinationAddressError.isNotEmpty) {
      setState(() => _destinationAddressError = '');
    }

    final text = _destinationAddressController.text;
    final isOpenAliasDomain = domainRegex.hasMatch(text) && _wallet(context).aliasAsset.isNotEmpty;

    // While the user is actively typing a domain, defer the (network) OpenAlias
    // resolution until the field unfocuses. Just clear fees + disable send.
    if (isOpenAliasDomain && _addressFocusNode.hasFocus) {
      _feeDebounce?.cancel();
      _feeCalculationCounter++;
      setState(() {
        _fees = null;
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

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(i18n),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 26, 16, 16),
                    children: [
                      _sectionLabel(i18n.sendFromLabel),
                      _fromCard(
                        wallet,
                        assetsOnChainOf(walletManager, wallet),
                        fiatRate,
                        fiatSymbol,
                      ),
                      const SizedBox(height: 14),
                      _sectionLabel(i18n.sendToLabel),
                      _toCard(wallet, i18n),
                      if (_destinationAddressError.isNotEmpty) _errorText(_destinationAddressError),
                      const SizedBox(height: 14),
                      _sectionLabel(i18n.amount),
                      _amountCard(wallet, i18n, fiatSymbol, coinRate),
                      if (_amountError.isNotEmpty) _errorText(_amountError),
                      const SizedBox(height: 14),
                      _sectionLabel(i18n.sendPriorityHeading),
                      _prioritySection(wallet, i18n, fiatSymbol, coinRate),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      BrandButton.outline(
                        label: i18n.cancel,
                        expand: false,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: BrandButton(
                          label: i18n.sendSendButton,
                          loading: _isLoading,
                          onPressed: (_formValid && _openAliasResolving == 0 && !_isLoading)
                              ? _send
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations i18n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SizedBox(
        height: 44,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconCircleButton(icon: Icons.close, onPressed: () => Navigator.pop(context)),
            ),
            Center(child: Text(i18n.sendTitle, style: BrandText.appBar.copyWith(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) =>
      SectionHeader(label: text, padding: const EdgeInsets.only(left: 4, bottom: 8));

  Widget _errorText(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Text(text, style: BrandText.caption.copyWith(color: BrandColors.error)),
  );

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.card,
        border: Border.all(color: BrandColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: padding,
      child: child,
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
      decoration: BoxDecoration(
        color: BrandColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      // Border drawn over the content (CSS border-box) so thickening it on open
      // doesn't shift the layout.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _assetMenuOpen ? BrandColors.cinnamon : BrandColors.border,
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
              child: const Icon(Icons.keyboard_arrow_down, size: 20, color: BrandColors.inkMuted),
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
              child: Container(
                decoration: BoxDecoration(
                  color: BrandColors.card,
                  border: Border.all(color: BrandColors.border),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1F2C170C), blurRadius: 24, offset: Offset(0, 12)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
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
              ? '${balance.toStringAsFixed(asset.decimals.clamp(0, 8))} ${asset.coinSymbol}'
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
                          asset.coinName,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                            color: BrandColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
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
                    style: const TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 13,
                      color: BrandColors.inkMuted,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, size: 18, color: BrandColors.cinnamon),
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
        : '${balance.toStringAsFixed(wallet.decimals.clamp(0, 8))} ${i18n.sendAvailableSuffix}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wallet.coinName,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.25,
            color: BrandColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          available,
          style: const TextStyle(
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
      _isLoadingFees = false;
      _feesInProgress = false;
      _formValid = false;
      _amountError = '';
      _lastFeeFetchKey = '';
    });
    _feeCalculationCounter++;
    _amountController.clear(); // fires _onAmountChanged → revalidates for the new asset
  }

  Widget _toCard(CryptoWallet wallet, AppLocalizations i18n) {
    if (_selectedContact != null) {
      return _card(
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: BrandColors.surfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Text(
                _selectedContact!.name.isNotEmpty ? _selectedContact!.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: BrandColors.cinnamonDeep,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedContact!.name, style: BrandText.listTitle),
                  const SizedBox(height: 2),
                  Text(i18n.sendSelectedContact, style: BrandText.caption),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _clearSelectedContact,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close, size: 20, color: BrandColors.inkMuted),
              ),
            ),
          ],
        ),
      );
    }

    final isMobile = Platform.isAndroid || Platform.isIOS;
    return _card(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _destinationAddressController,
            focusNode: _addressFocusNode,
            maxLines: null,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              fontFamily: 'Ubuntu Mono',
              fontSize: 13.5,
              height: 1.5,
              color: BrandColors.ink,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: i18n.sendAddressHint(wallet.coinName),
              hintStyle: const TextStyle(
                fontFamily: 'Ubuntu Mono',
                fontSize: 13.5,
                height: 1.5,
                color: BrandColors.inkMuted,
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: _openAliasResolving > 0
                  ? const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: BrandColors.cinnamon,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: BrandColors.surfaceTinted),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniAction(
                  Icons.content_paste_outlined,
                  i18n.sendPasteButton,
                  _pasteAddressFromClipboard,
                ),
              ),
              if (isMobile) ...[
                const SizedBox(width: 7),
                Expanded(
                  child: _miniAction(Icons.qr_code_scanner, i18n.sendScanButton, _scanQrCode),
                ),
              ],
              const SizedBox(width: 7),
              Expanded(
                child: _miniAction(
                  Icons.person_outline,
                  i18n.sendContactsButton,
                  _showContactPicker,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: BrandColors.surfaceSunken,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: BrandColors.cinnamonDeep),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: BrandColors.cinnamonDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountCard(
    CryptoWallet wallet,
    AppLocalizations i18n,
    String fiatSymbol,
    double? coinRate,
  ) {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final amountFiat = coinRate != null ? amount * coinRate : 0.0;
    return _card(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d*)?'))],
                  style: const TextStyle(
                    fontFamily: 'Ubuntu Mono',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: BrandColors.ink,
                  ),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '0.000000',
                    hintStyle: TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: BrandColors.inkFaint,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                wallet.coinSymbol,
                style: const TextStyle(
                  fontFamily: 'Ubuntu Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BrandColors.inkMuted,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _setBalanceAsSendAmount,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6E8D2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    i18n.sendMaxButton,
                    style: const TextStyle(
                      fontFamily: 'Ubuntu Mono',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: BrandColors.cinnamonDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(height: 1, color: BrandColors.surfaceTinted),
          const SizedBox(height: 11),
          Text(
            '≈ $fiatSymbol${amountFiat.toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'Ubuntu Mono',
              fontSize: 12,
              color: BrandColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _prioritySection(
    CryptoWallet wallet,
    AppLocalizations i18n,
    String fiatSymbol,
    double? coinRate,
  ) {
    final labels = [i18n.sendPriorityLow, i18n.sendPriorityNormal, i18n.sendPriorityHigh];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: BrandColors.surfaceTinted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _setPriority(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == _selectedPriority ? BrandColors.paper : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: i == _selectedPriority
                            ? [
                                BoxShadow(
                                  color: BrandColors.ink.withValues(alpha: 0.08),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 13,
                          height: 1,
                          fontWeight: i == _selectedPriority ? FontWeight.w500 : FontWeight.w400,
                          color: i == _selectedPriority ? BrandColors.ink : BrandColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 11, 4, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                i18n.sendNetworkFee,
                style: const TextStyle(fontSize: 12, color: BrandColors.inkMuted),
              ),
              _feeValue(wallet, fiatSymbol, coinRate),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feeValue(CryptoWallet wallet, String fiatSymbol, double? coinRate) {
    final feeTx = (_fees != null && _fees!.length > _selectedPriority)
        ? _fees![_selectedPriority]
        : null;
    if (_isLoadingFees || (_feesInProgress && feeTx == null)) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.cinnamon),
      );
    }
    if (feeTx == null) {
      return const Text(
        '—',
        style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12, color: BrandColors.inkMuted),
      );
    }
    final fee = displayAmount(feeTx.feeBaseUnits, wallet.feeBaseUnitDecimals);
    final feeStr = '${fee.toStringAsFixed(wallet.feeDecimals.clamp(0, 8))} ${wallet.feeCoinSymbol}';
    final feeFiat = (coinRate != null && !wallet.feeIsForeign)
        ? ' · $fiatSymbol${(fee * coinRate).toStringAsFixed(2)}'
        : '';
    return Text(
      '$feeStr$feeFiat',
      style: const TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12, color: BrandColors.inkMuted),
    );
  }
}

class _ContactPickerDialog extends StatefulWidget {
  final String coinSymbol;
  final Function(Contact) onContactSelected;

  const _ContactPickerDialog({required this.coinSymbol, required this.onContactSelected});

  @override
  State<_ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<_ContactPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth.clamp(0.0, 500.0);

    return AlertDialog(
      constraints: BoxConstraints.tightFor(width: dialogWidth),
      insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: i18n.addressBookSearchHint,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Consumer<ContactModel>(
                builder: (context, contactModel, child) {
                  final filteredContacts = contactModel.searchContacts(
                    _searchQuery,
                    coinSymbol: widget.coinSymbol,
                  );

                  if (filteredContacts.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? i18n.addressBookNoContactsForCoin(widget.coinSymbol)
                            : i18n.addressBookNoSearchResults,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final address = contact.addressFor(widget.coinSymbol)!;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(contact.name, style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          address,
                          style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => widget.onContactSelected(contact),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n.cancel))],
    );
  }
}
