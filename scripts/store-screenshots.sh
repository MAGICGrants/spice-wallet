#!/usr/bin/env bash
#
# Spice's App Store and F-Droid screenshots, taken from
# integration_test/store_screenshots_test.dart by wallet-core's
# scripts/store-screenshots.sh, in the sibling ../wallet-core checkout. See
# that script for the options, the devices and where the pictures go.
#
#   scripts/store-screenshots.sh                        # App Store: iPhone and iPad
#   scripts/store-screenshots.sh --device android --update-fdroid   # F-Droid: a Pixel
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# The listing's screenshots, most important first, as <screen>-<theme>: the
# order of each App Store set (which takes the first 10; the last two are
# F-Droid's only) and of F-Droid's. The design-system artifact's
# store-listing.md lists the same order; change both together.
export STORE_SHOTS="
  wallet_home-dark
  history-dark
  tor_settings-dark
  advanced_security-light
  backup-light
  address_book-light
  send-light
  receive-light
  connection_settings-light
  ether_coin-light
  monero_coin-light
  bitcoin_coin-light
"

exec ../wallet-core/scripts/store-screenshots.sh "$@"
