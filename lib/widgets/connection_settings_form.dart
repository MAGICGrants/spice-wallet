import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/periodic_tasks.dart';
import 'package:spice_wallet/services/foreground_sync_service.dart';
import 'package:spice_wallet/services/shared_preferences_service.dart';
import 'package:spice_wallet/services/tor_service.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/util/logging.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

const isDemoMode = String.fromEnvironment('DEMO_MODE') == 'true';

/// Which connection a [ConnectionSettingsForm] reads/writes/tests: the wallet's
/// node server, or its optional explorer.
enum ConnectionTarget { node, explorer }

/// Shared form widget for editing a server connection (address + Tor/SSL/proxy
/// + test). Operates against the wallet identified by [coinSymbol], on either
/// the node or the explorer connection per [target].
class ConnectionSettingsForm extends StatefulWidget {
  final String coinSymbol;
  final String saveButtonLabel;
  final VoidCallback onSaved;
  final bool isInDialog;
  final Future<void> Function()? onBeforeSave;
  final ConnectionTarget target;

  /// When true the Save button is pinned to the bottom of the available height
  /// (the fields scroll above it), matching the connection-setup screen. When
  /// false Save sits inline at the end of the form (dialogs / explorer setup).
  final bool pinnedSave;

  /// Fires with the selected connection type ('lws' / 'node' / '') on load and
  /// whenever the segmented control changes, so the screen can update its copy.
  final ValueChanged<String>? onConnectionTypeChanged;

  const ConnectionSettingsForm({
    super.key,
    required this.coinSymbol,
    required this.saveButtonLabel,
    required this.onSaved,
    this.isInDialog = false,
    this.onBeforeSave,
    this.target = ConnectionTarget.node,
    this.pinnedSave = false,
    this.onConnectionTypeChanged,
  });

  @override
  State<ConnectionSettingsForm> createState() => _ConnectionSettingsFormState();
}

class _ConnectionSettingsFormState extends State<ConnectionSettingsForm> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _customProxyPortController = TextEditingController();

  bool _useTor = false;
  String _connectionType = '';
  List<String> _connectionTypeOptions = const [];
  bool _hasTested = false;
  bool _connectionTestIsLoading = false;
  bool _connectionSuccess = false;
  String? _errorMessage;
  bool _backgroundSyncEnabled = false;
  bool _foregroundSyncEnabled = false;
  TorConnectionStatus _torStatus = TorService.sharedInstance.status;
  Timer? _torStatusTimer;
  bool _testCancelled = false;
  int? _latencyMs;

  // The as-loaded values, so save can tell what the user actually changed:
  // enabling sync or editing the connection needs a working test; disabling
  // sync alone does not.
  String _initialAddress = '';
  String _initialProxyPort = '';
  bool _initialUseTor = false;
  String _initialConnectionType = '';
  bool _initialBackgroundSync = false;
  bool _initialForegroundSync = false;

  /// Background / continuous sync only matter for a Monero **node** scan — the
  /// one heavy background job. LWS syncs server-side, so the toggles are hidden
  /// there (nothing to keep advancing in the background). Android-only.
  bool get _showSyncOptions =>
      Platform.isAndroid && widget.coinSymbol == 'XMR' && !_isExplorer && _connectionType == 'node';

  @override
  void initState() {
    super.initState();
    _loadPersistedConnection();
    // Load the toggle values up front (they're cheap global prefs); their
    // visibility is gated by _showSyncOptions, which only shows them in node
    // mode once the connection type has loaded / been selected.
    if (Platform.isAndroid && widget.coinSymbol == 'XMR' && !_isExplorer) _loadSyncPrefs();
  }

  Future<void> _loadSyncPrefs() async {
    final bg =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.backgroundSyncEnabled) ??
        false;
    final fg =
        await SharedPreferencesService.get<bool>(SharedPreferencesKeys.foregroundSyncEnabled) ??
        false;
    if (mounted) {
      setState(() {
        _backgroundSyncEnabled = bg;
        _foregroundSyncEnabled = fg;
        _initialBackgroundSync = bg;
        _initialForegroundSync = fg;
      });
    }
  }

  // Toggles are pending: they stage the choice and are applied by _saveConnection
  // (enabling requires saving over a working connection; disabling does not).
  void _setBackgroundSyncEnabled(bool value) => setState(() => _backgroundSyncEnabled = value);

  void _setForegroundSyncEnabled(bool value) => setState(() => _foregroundSyncEnabled = value);

  /// Persists the pending sync selection and starts/stops the services. LWS
  /// can't sync on-device, so both are forced off when the saved connection
  /// isn't an Android Monero node (where the toggles are hidden). The
  /// WorkManager task is then re-evaluated — it stays only if Notifications
  /// still needs it, on the lighter constraint.
  Future<void> _applySyncSelection() async {
    final bg = _showSyncOptions && _backgroundSyncEnabled;
    final fg = _showSyncOptions && _foregroundSyncEnabled;
    // Capture before the await so context isn't used across an async gap. Seed
    // the notification "synced" only when every active wallet is caught up.
    final active = fg
        ? Provider.of<WalletManager>(context, listen: false).activeWallets
        : const <CryptoWallet>[];
    final synced = active.isNotEmpty && active.every(isWalletFullySynced);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.backgroundSyncEnabled, bg);
    await SharedPreferencesService.set<bool>(SharedPreferencesKeys.foregroundSyncEnabled, fg);
    if (fg) {
      await startForegroundSync(synced: synced);
    } else {
      await stopForegroundSync();
    }
    await applyBackgroundTaskRegistration();
    if (mounted) {
      setState(() {
        _backgroundSyncEnabled = bg;
        _foregroundSyncEnabled = fg;
      });
    }
  }

  @override
  void dispose() {
    _torStatusTimer?.cancel();
    _addressController.dispose();
    _customProxyPortController.dispose();
    super.dispose();
  }

  bool get _isExplorer => widget.target == ConnectionTarget.explorer;

  Future<void> _loadPersistedConnection() async {
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(widget.coinSymbol);
    if (wallet == null) return;

    final conn = await (_isExplorer
        ? wallet.getPersistedExplorerConnection()
        : wallet.getPersistedConnection());

    final options = _isExplorer ? const <String>[] : wallet.connectionTypeOptions;

    final useTor = conn.useTor && TorSettingsService.sharedInstance.torMode != TorMode.disabled;
    final type = options.contains(conn.connectionType)
        ? conn.connectionType
        : (options.isNotEmpty ? options.first : '');
    setState(() {
      _addressController.text = conn.address;
      _customProxyPortController.text = conn.proxyPort;
      _useTor = useTor;
      _connectionTypeOptions = options;
      _connectionType = type;
      _initialAddress = cleanConnectionAddress(conn.address);
      _initialProxyPort = conn.proxyPort;
      _initialUseTor = useTor;
      _initialConnectionType = type;
    });
    widget.onConnectionTypeChanged?.call(_connectionType);

    if (conn.useTor && TorSettingsService.sharedInstance.torMode == TorMode.builtIn) {
      _pollTorStatus();
    }
  }

  Future<void> _scanQrCode() async {
    final i18n = AppLocalizations.of(context)!;

    final result = await Navigator.pushNamed(context, '/scan_qr');

    if (result != null && result is String) {
      final scannedAddress = cleanConnectionAddress(result);
      if (isValidConnectionAddress(scannedAddress)) {
        _addressController.text = scannedAddress;
        _onAddressChange(scannedAddress);
      } else {
        if (mounted) {
          if (widget.isInDialog) {
            setState(() {
              _errorMessage = i18n.lwsSetupInvalidQrCode;
            });
          } else {
            showBrandToast(context, i18n.lwsSetupInvalidQrCode);
          }
        }
      }
    }
  }

  void _onAddressChange(String rawValue) {
    final hadProtocol = RegExp(r'https?:\/\/').hasMatch(rawValue);
    final value = cleanConnectionAddress(rawValue);

    // Strip any http(s):// the user typed from the field itself so it's ignored.
    if (_addressController.text != value) {
      _addressController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }

    final useTor = onionAddressRegex.hasMatch(value);
    final i18n = AppLocalizations.of(context)!;

    // Never auto-disable Tor if the user already turned it on.
    _setUseTor(useTor || _useTor);

    setState(() {
      _hasTested = false;
      _errorMessage = isRemoteIp(value) ? i18n.connectionRemoteIpNotAllowed : null;
    });

    if (hadProtocol) {
      showBrandToast(
        context,
        addressUsesSsl(value) ? i18n.connectionProtocolHttps : i18n.connectionProtocolHttp,
      );
    }
  }

  void _onProxyPortChange(String value) {
    setState(() {
      _hasTested = false;
    });
  }

  void _setUseTor(bool? value) {
    if (TorSettingsService.sharedInstance.torMode == TorMode.disabled) {
      log(LogLevel.info, 'Tor is disabled. Not setting useTor to true.');
      value = false;
    }

    setState(() {
      _useTor = value ?? false;
      _hasTested = false;
    });

    if (value == true) {
      _customProxyPortController.text = '';

      if (TorSettingsService.sharedInstance.torMode == TorMode.builtIn) {
        _pollTorStatus();
      }
    }
  }

  void _pollTorStatus() {
    _torStatusTimer?.cancel();

    // Sync to the live status now so a stale snapshot can't keep the
    // "starting" indicator up.
    final current = TorService.sharedInstance.status;
    if (current != _torStatus) {
      setState(() => _torStatus = current);
    }
    if (current == TorConnectionStatus.connected) return;

    _torStatusTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final status = TorService.sharedInstance.status;
      if (status == TorConnectionStatus.connected) {
        timer.cancel();
        if (mounted) setState(() => _torStatus = status);
      }
    });
  }

  void _setConnectionType(String value) {
    setState(() {
      _connectionType = value;
      _hasTested = false;
      _errorMessage = null;
    });
    widget.onConnectionTypeChanged?.call(value);
  }

  String _connectionTypeLabel(AppLocalizations i18n, String type) {
    switch (type) {
      case 'node':
        return i18n.connectionTypeNode;
      case 'lws':
        return i18n.connectionTypeLws;
      default:
        return type;
    }
  }

  /// Resolves the SOCKS proxy port to pass to `wallet.testConnection`.
  /// When the user enabled Tor, this comes from the running TorService;
  /// otherwise it's the optional custom HTTP/SOCKS proxy field.
  Future<String?> _resolveProxyPort() async {
    if (_useTor) {
      final proxyInfo = await TorSettingsService.sharedInstance.getProxy();
      return proxyInfo?.port.toString();
    }
    final custom = _customProxyPortController.text.trim();
    return custom.isEmpty ? null : custom;
  }

  Future _testConnection() async {
    final i18n = AppLocalizations.of(context)!;
    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(widget.coinSymbol);
    if (wallet == null) return;

    final daemonAddress = cleanConnectionAddress(_addressController.text);

    if (isDemoMode && daemonAddress == 'demo') {
      setState(() {
        _hasTested = true;
        _connectionSuccess = true;
      });
      return;
    }

    if (isRemoteIp(daemonAddress)) {
      setState(() {
        _hasTested = false;
        _errorMessage = i18n.connectionRemoteIpNotAllowed;
      });
      return;
    }

    if (_useTor && TorSettingsService.sharedInstance.torMode == TorMode.disabled) {
      showBrandToast(context, i18n.lwsSetupTorDisabledError);
      return;
    }

    setState(() {
      _testCancelled = false;
      _hasTested = true;
      _connectionTestIsLoading = true;
      _connectionSuccess = false;
      _errorMessage = null;
      _latencyMs = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final proxyPort = await _resolveProxyPort();
      if (_isExplorer) {
        await wallet.testExplorerConnection(
          address: daemonAddress,
          proxyPort: proxyPort,
          useTor: _useTor,
        );
      } else {
        await wallet.testConnection(
          address: daemonAddress,
          proxyPort: proxyPort,
          useTor: _useTor,
          connectionType: _connectionType,
        );
      }
      if (!mounted || _testCancelled) return;
      setState(() {
        _connectionSuccess = true;
        _latencyMs = stopwatch.elapsedMilliseconds;
      });
    } catch (error) {
      log(LogLevel.warn, 'testConnection failed: $error', coin: widget.coinSymbol);
      if (!mounted || _testCancelled) return;
      setState(() {
        _connectionSuccess = false;
      });
    } finally {
      if (mounted && !_testCancelled) {
        setState(() {
          _connectionTestIsLoading = false;
        });
      }
    }
  }

  /// Best-effort UI cancel: the in-flight network call can't be aborted, but we
  /// drop its result and return the card to the untested state.
  void _stopTest() {
    setState(() {
      _testCancelled = true;
      _hasTested = false;
      _connectionTestIsLoading = false;
      _connectionSuccess = false;
    });
  }

  Future<void> _saveConnection() async {
    final daemonAddress = cleanConnectionAddress(_addressController.text);
    final proxyAddress = _customProxyPortController.text;

    if (isRemoteIp(daemonAddress)) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.connectionRemoteIpNotAllowed);
      return;
    }

    final manager = Provider.of<WalletManager>(context, listen: false);
    final wallet = manager.getWallet(widget.coinSymbol);
    if (wallet == null) return;

    if (_isExplorer) {
      wallet.setExplorerConnection(
        address: daemonAddress,
        proxyPort: proxyAddress,
        useTor: _useTor,
      );
      await wallet.persistExplorerConnection();
    } else {
      wallet.setConnection(
        address: daemonAddress,
        proxyPort: proxyAddress,
        useTor: _useTor,
        connectionType: _connectionType,
      );
      await wallet.persistCurrentConnection();

      // Apply the pending background / continuous sync selection over the
      // connection just saved (also re-evaluates the WorkManager task). Node-only;
      // saving an LWS connection forces them off since the toggles are hidden.
      if (widget.coinSymbol == 'XMR') {
        await _applySyncSelection();
      }
    }
    await widget.onBeforeSave?.call();

    widget.onSaved();
  }

  /// How the successful probe reached the server (the one server fact we can
  /// state from an unauthenticated test). Height / subaddress support aren't
  /// returned by the probe, so they're not shown.
  String _successDetail(AppLocalizations i18n) {
    if (_useTor) return i18n.connectionReachedOverTor;
    if (_customProxyPortController.text.trim().isNotEmpty) return i18n.connectionReachedViaProxy;
    return i18n.connectionReachedDirect;
  }

  /// Maps this wrapper's flags onto the shared test-card state. Order matches
  /// the old `_buildTestCard`: starting-Tor takes over; then idle / testing /
  /// success / failure.
  ConnectionTestState _testState(TorMode torMode) {
    if (_useTor && torMode == TorMode.builtIn && _torStatus != TorConnectionStatus.connected) {
      return ConnectionTestState.startingTor;
    }
    if (!_hasTested) return ConnectionTestState.idle;
    if (_connectionTestIsLoading) return ConnectionTestState.testing;
    return _connectionSuccess ? ConnectionTestState.success : ConnectionTestState.failure;
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final torMode = TorSettingsService.sharedInstance.torMode;
    final wallet = Provider.of<WalletManager>(context, listen: false).getWallet(widget.coinSymbol);
    final addressHint =
        (_isExplorer
            ? wallet?.explorerAddressExample
            : wallet?.connectionAddressExampleForType(_connectionType)) ??
        i18n.lwsSetupAddressHint;
    final addressLabel = _isExplorer ? i18n.explorerAddressLabel : i18n.address;

    final hasWorkingConnection = _hasTested && _connectionSuccess && !_connectionTestIsLoading;
    final connectionChanged =
        cleanConnectionAddress(_addressController.text) != _initialAddress ||
        _useTor != _initialUseTor ||
        _customProxyPortController.text != _initialProxyPort ||
        _connectionType != _initialConnectionType;
    final enablingSync =
        (_backgroundSyncEnabled && !_initialBackgroundSync) ||
        (_foregroundSyncEnabled && !_initialForegroundSync);
    final syncChanged =
        _backgroundSyncEnabled != _initialBackgroundSync ||
        _foregroundSyncEnabled != _initialForegroundSync;
    // Disabling sync alone needs no working connection; enabling it or editing
    // the connection does.
    final disablingSyncOnly = syncChanged && !enablingSync && !connectionChanged;
    final canSave = !_connectionTestIsLoading && (hasWorkingConnection || disablingSyncOnly);

    return ConnectionFormView(
      labels: ConnectionFormLabels(
        proxyPortLabel: i18n.connectionProxyPortLabel,
        proxyPortHint: i18n.connectionProxyPortHint,
        useTorLabel: i18n.lwsSetupUseTorLabel,
        startingTorTitle: i18n.lwsSetupStartingTor,
        testButton: i18n.lwsSetupTestConnectionButton,
        testStop: i18n.connectionTestStop,
        testingTitle: i18n.connectionTestingTitle,
        testingDetail: i18n.connectionTestingDetail,
        testAgain: i18n.connectionTestAgain,
        resultWorksTitle: i18n.connectionResultWorksTitle,
        resultFailedTitle: i18n.connectionResultFailedTitle,
        resultFailedDetail: i18n.connectionResultFailedDetail,
      ),
      addressLabel: addressLabel,
      addressHint: addressHint,
      addressController: _addressController,
      onAddressChanged: _onAddressChange,
      onScan: (Platform.isAndroid || Platform.isIOS) ? _scanQrCode : null,
      errorMessage: _errorMessage,
      proxyController: _customProxyPortController,
      onProxyChanged: _onProxyPortChange,
      proxyEnabled: !_useTor,
      connectionTypeLabels: [for (final t in _connectionTypeOptions) _connectionTypeLabel(i18n, t)],
      selectedTypeIndex: _connectionTypeOptions.indexOf(_connectionType),
      onSelectType: (i) => _setConnectionType(_connectionTypeOptions[i]),
      useTor: _useTor,
      torDisabled: torMode == TorMode.disabled,
      onToggleTor: () => _setUseTor(!_useTor),
      pillProxyPort: _customProxyPortController.text,
      pillAddress: cleanConnectionAddress(_addressController.text),
      syncRows: _showSyncOptions
          ? [
              ConnectionSyncRow(
                label: i18n.settingsBackgroundSyncLabel,
                help: i18n.settingsBackgroundSyncDescription,
                checked: _backgroundSyncEnabled,
                onToggle: _setBackgroundSyncEnabled,
              ),
              ConnectionSyncRow(
                label: i18n.settingsForegroundSyncLabel,
                help: i18n.settingsForegroundSyncDescription,
                checked: _foregroundSyncEnabled,
                onToggle: _setForegroundSyncEnabled,
              ),
            ]
          : const [],
      testState: _testState(torMode),
      onTest: _testConnection,
      onStopTest: _stopTest,
      onTestAgain: _testConnection,
      successDetail: _successDetail(i18n),
      successLatency: _latencyMs != null ? '$_latencyMs ms' : null,
      saveButtonLabel: widget.saveButtonLabel,
      canSave: canSave,
      onSave: _saveConnection,
      pinnedSave: widget.pinnedSave,
    );
  }
}
