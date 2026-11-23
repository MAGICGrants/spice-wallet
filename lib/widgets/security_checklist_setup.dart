import 'package:flutter/widgets.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/home_labels.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';
import 'package:wallet_backup_platform/wallet_backup_platform.dart' show MetadataBackupSetup;
import 'package:wallet_domain/wallet_domain.dart' show SeedStore;
import 'package:wallet_fhse/security_keys_ui.dart' show securityKeysOn;

/// The security checklist as Spice reads it: the home's card, and the
/// Security Checklist card in Settings, which shows where each step stands.
SecurityChecklist appSecurityChecklist() => SecurityChecklist(
  autoBackupOn: MetadataBackupSetup.automaticBackupOn,
  securityKeysOn: securityKeysOn,
  // A wallet from before the seed was kept has no words to ask for.
  canVerifySeed: SeedStore.exists,
);

/// Opens Settings' Security Checklist card. True when the user saved.
Future<bool?> showAppSecurityChecklistSheet(BuildContext context) async {
  final checklist = appSecurityChecklist();
  try {
    return await showSecurityChecklistSheet(
      context,
      checklist: checklist,
      labels: securityChecklistSheetLabels(AppLocalizations.of(context)!),
    );
  } finally {
    checklist.dispose();
  }
}
