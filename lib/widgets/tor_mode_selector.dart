import 'dart:io';

import 'package:flutter/material.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/util/socks_http.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

/// The current choice made in a [TorModeSelector]. [canCommit] is false until a
/// mode is picked, and (for External) a connection test passes.
class TorSelection {
  final TorMode? mode;
  final String port;
  final bool useOrbot;
  final bool canCommit;

  const TorSelection({
    required this.mode,
    required this.port,
    required this.useOrbot,
    required this.canCommit,
  });
}

/// The three-way Tor mode picker (Built-in / External / No Tor) shared by the
/// onboarding "Tor choice" step and the settings Tor sheet. External expands
/// inline with its SOCKS port / Orbot / connection-test controls. Reports every
/// change via [onChanged] so the host can gate its Continue/Save button.
class TorModeSelector extends StatefulWidget {
  final TorMode? initialMode;
  final String initialPort;
  final bool initialUseOrbot;
  final ValueChanged<TorSelection> onChanged;

  const TorModeSelector({
    super.key,
    this.initialMode,
    this.initialPort = '9050',
    this.initialUseOrbot = false,
    required this.onChanged,
  });

  @override
  State<TorModeSelector> createState() => _TorModeSelectorState();
}

class _TorModeSelectorState extends State<TorModeSelector> {
  late TorMode? _selected = widget.initialMode;
  late final TextEditingController _portController = TextEditingController(
    text: widget.initialPort,
  );
  late bool _useOrbot = widget.initialUseOrbot;
  bool _testing = false;
  bool _tested = false;
  bool _testOk = false;

  bool get _canCommit => _selected != null && (_selected != TorMode.external || _testOk);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      TorSelection(
        mode: _selected,
        port: _portController.text,
        useOrbot: _useOrbot,
        canCommit: _canCommit,
      ),
    );
  }

  void _select(TorMode mode) {
    setState(() {
      _selected = mode;
      _tested = false;
      _testOk = false;
    });
    _emit();
  }

  Future<void> _test() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _tested = true;
      _testOk = false;
    });
    _emit();
    try {
      final port = int.tryParse(_portController.text) ?? 9050;
      final proxy = (host: InternetAddress.loopbackIPv4, port: port);
      final response = await makeSocksHttpRequest(
        'GET',
        'https://check.torproject.org/api/ip',
        proxy,
      ).timeout(const Duration(seconds: 15));
      final isTor = response.jsonBody != null && response.jsonBody['IsTor'] == true;
      if (mounted) setState(() => _testOk = response.statusCode == HttpStatus.ok && isTor);
    } catch (_) {
      if (mounted) setState(() => _testOk = false);
    } finally {
      if (mounted) setState(() => _testing = false);
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModeSelectCard(
          title: i18n.torSettingsModeBuiltIn,
          description: i18n.torChoiceBuiltInDesc,
          selected: _selected == TorMode.builtIn,
          radioLeading: true,
          onTap: () => _select(TorMode.builtIn),
        ),
        const SizedBox(height: 9),
        ModeSelectCard(
          title: i18n.torSettingsModeExternal,
          description: i18n.torChoiceExternalDesc,
          selected: _selected == TorMode.external,
          radioLeading: true,
          onTap: () => _select(TorMode.external),
          expanded: _externalFields(i18n, isMobile),
        ),
        const SizedBox(height: 9),
        ModeSelectCard(
          title: i18n.torSettingsModeDisabled,
          description: i18n.torChoiceNoTorDesc,
          selected: _selected == TorMode.disabled,
          radioLeading: true,
          onTap: () => _select(TorMode.disabled),
        ),
      ],
    );
  }

  Widget _externalFields(AppLocalizations i18n, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PortField(
          controller: _portController,
          label: i18n.torSettingsSocksPortLabel,
          onChanged: () {
            setState(() {
              _tested = false;
              _testOk = false;
            });
            _emit();
          },
        ),
        if (isMobile)
          _OrbotCheck(
            value: _useOrbot,
            label: i18n.torChoiceOrbot,
            onChanged: (v) {
              setState(() {
                _useOrbot = v;
                if (v) _portController.text = '9050';
                _tested = false;
                _testOk = false;
              });
              _emit();
            },
          ),
        const SizedBox(height: BrandSpacing.md),
        Row(
          children: [
            Expanded(child: _testStatus(i18n)),
            const SizedBox(width: BrandSpacing.md),
            _TestChip(label: i18n.torSettingsTestConnectionButton, onTap: _testing ? null : _test),
          ],
        ),
      ],
    );
  }

  Widget _testStatus(AppLocalizations i18n) {
    if (_testing) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.cinnamon),
        ),
      );
    }
    if (!_tested) return const SizedBox.shrink();
    if (_testOk) {
      return Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: BrandColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: BrandSpacing.sm),
          Text(
            i18n.torChoiceConnected,
            style: BrandText.caption.copyWith(
              color: BrandColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.error_outline, color: BrandColors.error, size: 18),
        const SizedBox(width: BrandSpacing.sm),
        Text(
          i18n.torChoiceTestFailed,
          style: BrandText.caption.copyWith(color: BrandColors.error, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Labeled inset field — a small-caps mono label above the value, per the
/// design (not a Material floating-label box).
class _PortField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  const _PortField({required this.controller, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
      decoration: BoxDecoration(
        color: BrandColors.paper,
        borderRadius: BorderRadius.circular(BrandRadii.tile),
        border: Border.all(color: BrandColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Ubuntu Mono',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: BrandColors.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 14, color: BrandColors.ink),
            cursorColor: BrandColors.cinnamon,
            decoration: const InputDecoration.collapsed(hintText: '9050'),
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

/// Small compact chip for the connection test action.
class _TestChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _TestChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: BrandColors.border),
    );
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: BrandColors.surfaceSunken,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: BrandColors.cinnamonDeep,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbotCheck extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const _OrbotCheck({required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BrandSpacing.md),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              color: value ? BrandColors.cinnamon : BrandColors.inkFaint,
              size: 22,
            ),
            const SizedBox(width: BrandSpacing.sm),
            Expanded(child: Text(label, style: BrandText.caption)),
          ],
        ),
      ),
    );
  }
}
