import 'package:flutter/material.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(args.toastMessage)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

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
                center: const StepDots(count: 4, index: 2),
              ),
              const SizedBox(height: BrandSpacing.lg),
              Text(i18n.createWalletTitle, style: BrandText.title),
              const SizedBox(height: BrandSpacing.sm),
              Text(i18n.createWalletDescription, style: BrandText.bodyMuted),
              const SizedBox(height: BrandSpacing.xl),
              _OptionCard(
                icon: Icons.add,
                title: i18n.createWalletCreateNewButton,
                description: i18n.createWalletCreateNewDesc,
                onTap: () => Navigator.pushNamed(context, '/generate_seed'),
              ),
              const SizedBox(height: BrandSpacing.md),
              _OptionCard(
                icon: Icons.refresh,
                title: i18n.createWalletRestoreExistingButton,
                description: i18n.createWalletRestoreExistingDesc,
                onTap: () => Navigator.pushNamed(context, '/restore_wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width choice card: icon tile + title + description + chevron.
class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BrandColors.card,
        borderRadius: BrandRadii.rField,
        border: Border.all(color: BrandColors.border),
      ),
      child: ClipRRect(
        borderRadius: BrandRadii.rField,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BrandColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: BrandColors.cinnamon, size: 22),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: BrandColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(description, style: BrandText.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: BrandSpacing.sm),
                  const Icon(Icons.chevron_right, color: BrandColors.inkFaint, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
