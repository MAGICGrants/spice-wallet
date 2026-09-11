import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/theme_language_sheets.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_domain/wallet_domain.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _pushHomeIfWalletExists();
  }

  Future<void> _pushHomeIfWalletExists() async {
    final manager = Provider.of<WalletManager>(context, listen: false);
    if (await manager.hasAnyExistingWallet()) {
      await manager.openAll();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/wallet_home', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    return WelcomeView(
      logo: SvgPicture.asset('assets/spice-mark.svg', width: 96, height: 96),
      appName: 'Spice Wallet',
      description: i18n.welcomeDescription,
      labels: WelcomeLabels(
        getStarted: i18n.welcomeGetStarted,
        agreePrefix: i18n.welcomeAgreePrefix,
        termsLink: i18n.welcomeTermsLink,
        agreeMiddle: i18n.welcomeAgreeMiddle,
        privacyLink: i18n.welcomePrivacyLink,
      ),
      onGetStarted: () => Navigator.pushNamed(context, '/tor_settings'),
      onTerms: () => Navigator.pushNamed(context, '/terms_of_service'),
      onPrivacy: () => Navigator.pushNamed(context, '/privacy_policy'),
      onLanguage: () => showLanguageSheet(context),
    );
  }
}
