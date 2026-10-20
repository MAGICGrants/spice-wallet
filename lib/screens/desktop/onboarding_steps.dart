import 'package:spice_wallet/util/platform.dart';

/// How many steps the desktop onboarding numbers. The password is the last one,
/// and only Linux and Windows set it: macOS and the iOS build on a Mac show this
/// layout but generate the password, so their onboarding ends at the seed.
int get desktopOnboardingSteps => typesWalletPassword ? 5 : 4;
