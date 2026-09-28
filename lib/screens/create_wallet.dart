import 'package:flutter/material.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/util/platform.dart';
import 'package:spice_wallet/screens/desktop/wallet_setup_view.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

class CreateWalletScreenArgs {
  String toastMessage;
  CreateWalletScreenArgs({required this.toastMessage});
}

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  @override
  void initState() {
    super.initState();
    _showErrorIfNeeded();
  }

  void _showErrorIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as CreateWalletScreenArgs?;
      if (args != null && args.toastMessage != '') {
        showBrandToast(context, args.toastMessage);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    final labels = CreateWalletLabels(
      title: i18n.createWalletTitle,
      subtitle: i18n.createWalletDescription,
      createNew: i18n.createWalletCreateNewButton,
      createNewDesc: i18n.createWalletCreateNewDesc,
      restore: i18n.createWalletRestoreExistingButton,
      restoreDesc: i18n.createWalletRestoreExistingDesc,
    );
    void createNew() => Navigator.pushNamed(context, '/generate_seed');
    void restore() => Navigator.pushNamed(context, '/restore_wallet');

    if (isDesktop) {
      return DesktopWalletSetupView(
        labels: labels,
        continueText: i18n.continueText,
        noteGenerated: i18n.onboardingWalletNoteGenerated,
        noteRestore: i18n.onboardingWalletNoteRestore,
        createBullets: [
          i18n.onboardingWalletCreateBullet1,
          i18n.onboardingWalletCreateBullet2,
          i18n.onboardingWalletCreateBullet3,
        ],
        restoreBullets: [
          i18n.onboardingWalletRestoreBullet1,
          i18n.onboardingWalletRestoreBullet2,
          i18n.onboardingWalletRestoreBullet3,
        ],
        onCreateNew: createNew,
        onRestore: restore,
        onBack: () => Navigator.pop(context),
      );
    }

    return CreateWalletView(
      stepCount: 4,
      stepIndex: 2,
      labels: labels,
      onCreateNew: createNew,
      onRestore: restore,
    );
  }
}
