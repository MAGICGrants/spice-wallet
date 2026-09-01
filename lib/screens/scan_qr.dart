import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'package:spice_wallet/l10n/app_localizations.dart';
import 'package:spice_wallet/widgets/ui/ui.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  bool _hasScanned = false;

  void _onScan(Code result) {
    if (_hasScanned) return;

    final text = result.text;
    if (text == null || text.isEmpty) return;

    _hasScanned = true;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context)!;

    // ReaderWidget centres its scan square using the full screen size, so it
    // must be full-bleed; the brand header floats over its dimmed top band.
    return Scaffold(
      backgroundColor: BrandColors.ink,
      body: Stack(
        children: [
          Positioned.fill(
            child: ReaderWidget(
              onScan: _onScan,
              showGallery: false,
              cropPercent: 1.0,
              tryHarder: true,
              scanDelay: const Duration(milliseconds: 200),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Align(
                alignment: Alignment.topCenter,
                child: BrandScreenHeader(
                  onBack: () => Navigator.pop(context),
                  center: Text(
                    i18n.scanQrTitle,
                    style: BrandText.appBar.copyWith(fontSize: 16, color: BrandColors.paper),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
