import 'package:wallet_ui/wallet_ui.dart' show RouteAccess, RoutePolicy;

/// Who may open each of Spice's routes. Deny by default: `onGenerateRoute`
/// refuses a route that is not listed here, and one marked
/// [RouteAccess.unlocked] until the user is past every lock (App Lock, the
/// typed password, security keys). `test/route_policy_test.dart` fails if a
/// route is missing.
const routePolicy = RoutePolicy({
  // Launch: runs before anything else, then routes to a lock or home.
  '/loading': RouteAccess.public,
  // Onboarding, before a wallet exists.
  '/welcome': RouteAccess.public,
  '/tor_settings': RouteAccess.public,
  '/fiat_api_setup': RouteAccess.public,
  '/create_wallet': RouteAccess.public,
  '/create_wallet_password': RouteAccess.public,
  '/generate_seed': RouteAccess.public,
  '/restore_wallet': RouteAccess.public,
  // Restore scans a seed's QR code; Send, history and the address book too.
  '/scan_qr': RouteAccess.public,
  // The locks themselves.
  '/unlock': RouteAccess.public,
  '/security_key_unlock': RouteAccess.public,
  // Legal pages, linked from onboarding.
  '/terms_of_service': RouteAccess.public,
  '/privacy_policy': RouteAccess.public,
  // The wallet.
  '/wallet_home': RouteAccess.unlocked,
  '/coin_home': RouteAccess.unlocked,
  '/coin_settings': RouteAccess.unlocked,
  '/history': RouteAccess.unlocked,
  '/send': RouteAccess.unlocked,
  '/receive': RouteAccess.unlocked,
  '/address_book': RouteAccess.unlocked,
  '/settings': RouteAccess.unlocked,
  '/connection_setup': RouteAccess.unlocked,
  '/explorer_setup': RouteAccess.unlocked,
  '/lws_keys': RouteAccess.unlocked,
  '/reveal_seed': RouteAccess.unlocked,
  '/advanced_security': RouteAccess.unlocked,
  '/metadata_backup': RouteAccess.unlocked,
  '/verify_seed': RouteAccess.unlocked,
  '/open_source_licenses': RouteAccess.unlocked,
});
