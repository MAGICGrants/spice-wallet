import 'dart:io';

import 'package:flutter/material.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/services/tor_settings_service.dart';
import 'package:spice_wallet/util/socks_http.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

/// Onboarding "Tor choice" — a three-way decision (Built-in / External / No Tor)
/// made before any connection. All start unselected; Continue unlocks once a
/// mode is picked (External also requires a passing connection test).
class TorSettingsScreen extends StatefulWidget {
  const TorSettingsScreen({super.key});

  @override
  State<TorSettingsScreen> createState() => _TorSettingsScreenState();
}

class _TorSettingsScreenState extends State<TorSettingsScreen> {
  TorMode? _selected;
  final _portController = TextEditingController(text: '9050');
  bool _useOrbot = false;
  bool _testing = false;
  bool _tested = false;
  bool _testOk = false;

  bool get _canContinue => _selected != null && (_selected != TorMode.external || _testOk);

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  void _select(TorMode mode) {
    setState(() {
      _selected = mode;
      _tested = false;
      _testOk = false;
    });
  }

  Future<void> _test() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _tested = true;
      _testOk = false;
    });
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
    }
  }

  Future<void> _continue() async {
    await TorSettingsService.sharedInstance.save(
      torMode: _selected!,
      socksPort: _portController.text,
      useOrbot: _useOrbot,
    );
    if (!mounted) return;
    Navigator.pushNamed(context, '/fiat_api_setup');
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return Scaffold(
      backgroundColor: BrandColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: BrandSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: BrandSpacing.sm),
              BrandScreenHeader(
                onBack: () => Navigator.maybePop(context),
                center: const StepDots(count: 4, index: 0),
              ),
              const SizedBox(height: BrandSpacing.lg),
              Text(i18n.torChoiceTitle, style: BrandText.title),
              const SizedBox(height: BrandSpacing.sm),
              Text(i18n.torChoiceSubtitle, style: BrandText.bodyMuted),
              const SizedBox(height: BrandSpacing.xl),
              Expanded(
                child: ListView(
                  children: [
                    _TorOption(
                      title: i18n.torSettingsModeBuiltIn,
                      description: i18n.torChoiceBuiltInDesc,
                      selected: _selected == TorMode.builtIn,
                      badge: i18n.torChoiceRecommended,
                      onTap: () => _select(TorMode.builtIn),
                    ),
                    const SizedBox(height: BrandSpacing.md),
                    _TorOption(
                      title: i18n.torSettingsModeExternal,
                      description: i18n.torChoiceExternalDesc,
                      selected: _selected == TorMode.external,
                      onTap: () => _select(TorMode.external),
                      expanded: _externalFields(i18n, isMobile),
                    ),
                    const SizedBox(height: BrandSpacing.md),
                    _TorOption(
                      title: i18n.torSettingsModeDisabled,
                      description: i18n.torChoiceNoTorDesc,
                      selected: _selected == TorMode.disabled,
                      onTap: () => _select(TorMode.disabled),
                    ),
                  ],
                ),
              ),
              BrandButton(label: i18n.continueText, onPressed: _canContinue ? _continue : null),
              const SizedBox(height: BrandSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _externalFields(AppLocalizations i18n, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PortField(controller: _portController, label: i18n.torSettingsSocksPortLabel),
        if (isMobile)
          _OrbotCheck(
            value: _useOrbot,
            label: i18n.torChoiceOrbot,
            onChanged: (v) => setState(() {
              _useOrbot = v;
              if (v) _portController.text = '9050';
            }),
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
      return const Align(
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
            decoration: const BoxDecoration(color: BrandColors.success, shape: BoxShape.circle),
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
        const Icon(Icons.error_outline, color: BrandColors.error, size: 18),
        const SizedBox(width: BrandSpacing.sm),
        Text(
          i18n.torChoiceTestFailed,
          style: BrandText.caption.copyWith(color: BrandColors.error, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// A selectable Tor-mode card with a radio indicator, expanding inline when
/// selected (External shows its port/Orbot/test fields).
class _TorOption extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final Widget? expanded;

  const _TorOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.badge,
    this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: BrandMotion.transition,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        decoration: const BoxDecoration(color: BrandColors.card, borderRadius: BrandRadii.rField),
        // foregroundDecoration paints the border over the content, so growing it
        // to 2px on select doesn't inset/shift the content (CSS border-box).
        foregroundDecoration: BoxDecoration(
          borderRadius: BrandRadii.rField,
          border: Border.all(
            color: selected ? BrandColors.cinnamon : BrandColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: BrandText.listTitle),
                          if (badge != null) ...[
                            const SizedBox(width: BrandSpacing.sm),
                            _Badge(badge!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(description, style: BrandText.caption),
                    ],
                  ),
                ),
                const SizedBox(width: BrandSpacing.md),
                RadioDot(selected: selected),
              ],
            ),
            if (selected && expanded != null) ...[const SizedBox(height: 14), expanded!],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: BrandColors.successBg,
        borderRadius: BorderRadius.circular(BrandRadii.badge),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Ubuntu Mono',
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: BrandColors.success,
        ),
      ),
    );
  }
}

/// Labeled inset field — a small-caps mono label above the value, per the
/// design (not a Material floating-label box).
class _PortField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _PortField({required this.controller, required this.label});

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
            style: const TextStyle(
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
            style: const TextStyle(fontFamily: 'Ubuntu Mono', fontSize: 14, color: BrandColors.ink),
            cursorColor: BrandColors.cinnamon,
            decoration: const InputDecoration.collapsed(hintText: '9050'),
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
      side: const BorderSide(color: BrandColors.border),
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
              style: const TextStyle(
                fontFamily: 'Ubuntu',
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
