# Spice architecture

How the Spice app is put together on top of **wallet-core**. This documents only
the *spice-specific* choices — the shared wallet engine is documented in
`../../wallet-core/docs/` (`decisions.md`, `reconciliation.md`, `testing.md`,
`storage.md`, `logging.md`, `background-sync.md`), which are the source of truth
for anything below the app layer. Don't duplicate those here; link to them.

## What Spice is

A **multicoin**, self-custody wallet (XMR, BTC, ETH, and ERC-20 DAI, each with a
testnet variant). Its wallet engine is entirely **wallet-core**; the app owns UI,
navigation, branding, and app-support glue.

## How Spice consumes wallet-core

- **Dependency**: the six wallet-core packages (`wallet_infra`, `wallet_domain`,
  `wallet_monero`, `wallet_bitcoin`, `wallet_ethereum`, `wallet_openalias`) are
  SHA-pinned in `pubspec.yaml`. Local dev redirects them to `../wallet-core` via
  the gitignored `pubspec_overrides.yaml`. **Wallet-core changes only reach a
  release build once the pin is bumped** — the override is dev-only.
- **No adapter layer.** Screens bind **directly** to wallet-core's `CryptoWallet`
  and `WalletManager` (its own types — Spice's architecture is the base, see
  wallet-core D2). Skylight wraps them in an `AppWallet`/`MoneroWalletAdapter`
  neutral-type layer because it deleted its own `WalletModel`; Spice never had
  that indirection and doesn't need it (it's already multicoin against the
  generic interface).
- **Glue lives in `lib/wallet_core_glue.dart`.** `installWalletCore()` is the one
  place app differences are injected (called from `main()` and from each
  background isolate, since statics don't cross isolates):
  - `WalletAppConfig.spice` — file names (`mywallet_<coin>`) and `xmr_`-prefixed
    pref keys. **Neither app migrates on-disk state.**
  - `CryptoWallet.aliasResolver` → `resolveOpenAlias`
  - `WalletLog.sink` → routes into `lib/util/logging.dart`
  - `CryptoWallet.incomingTxNotifier` → builds coin-correct notification text
  - `NotificationService` Windows branding
  - the coin registry (`buildCoins()`)

## App-local vs shared

- **Kept app-local** (`lib/util/`, `lib/services/`): logging, dirs, Tor service,
  `TorSettingsService`, secure clipboard/screen, socks, cacert, amount/formatting
  helpers, `NotificationService` re-export. wallet-core has its own internal
  copies (`wallet_infra`); the two are bridged by **injection**, not by importing
  `wallet_infra` into the UI.
- **Shared via wallet-core** (deleted from Spice): the entire wallet engine
  (`CryptoWallet`/`WalletManager`/coins), plus — as of the sharing work — the
  `SharedPreferencesService` and `NotificationService` (Spice re-exports them),
  and the common setting-key strings via `wallet_infra`'s `SettingsKeys` (see
  wallet-core **D21**). Spice's `SharedPreferencesKeys` references those and adds
  its multicoin-only keys.

## Coin registry

`buildCoins()` in the glue registers: `MoneroWallet`, `BitcoinWallet`,
`BitcoinTestnetWallet`, `EthereumWallet`, `EthereumSepoliaWallet`, `DaiWallet`,
`DaiSepoliaWallet`. Connection types: **XMR is LWS or node**; BTC (Electrum) and
ETH (RPC) are always **light** (server-backed). So **node mode is XMR-only** — it
is the only heavy, locally-scanning connection. ERC-20 (DAI) pays fees in ETH
(`feeIsForeign`).

## Background sync & notifications — the multicoin dimension only

The background-sync + tx-notification **design is shared with Skylight**, not
spice-specific: the security rationale (key exposure vs. the LWS/node mode split)
is wallet-core's `background-sync.md`, and the orchestration now lives in the
shared **`wallet_background`** package (wallet-core D22). Spice keeps only the
thin isolate **entry points** (`periodic_tasks.dart`, `foreground_sync_service.dart`
— they bootstrap the isolate then delegate), the `BackgroundSync.install(...)`
config in the glue (coin registry, a Tor hook, iOS bundle id, foreground title),
the desktop-announce/mobile-mark-seen in `main.dart` (widget-lifecycle-bound),
and the native `AppDelegate.swift`/`Info.plist`.

The only genuinely **spice-specific** part is that spice is multicoin:

- **Node-mode XMR is the only heavy background scan.** BTC (Electrum), ETH (RPC)
  and XMR-LWS are light server polls, so a background wake for them is just a
  notification check.
- `runTxNotifier` therefore opens **only the coins a window can sync** and
  filters a heterogeneous set per window; the Background Sync toggle applies to
  XMR-node alone (BTC/ETH always qualify), and the connection form's sync toggles
  are shown for XMR-node only.

## Testing

wallet-core owns the engine's L0–L5 tests (`testing.md`) and the fake seams
(`FakeMoneroBackend`, `FakeElectrumClient`, `fake_ethereum_rpc`). Spice keeps
app-level tests (`test/wallet_core_glue_test.dart` guards the coin registry and
the no-migration key/file naming). Background-sync / notification / iOS paths are
plugin- and device-coupled and are verified on device.
