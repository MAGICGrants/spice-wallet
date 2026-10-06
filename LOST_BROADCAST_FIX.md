# Lost broadcast reply / double-send fix

## The problem
When a send's broadcast reply is lost (Tor circuit collapse, timeout, dropped
socket), the wallet couldn't tell "never sent" from "sent but no answer." It
reported a flat failure, which invited the user to retry — and a retry could
broadcast a **second, real payment**. Only Bitcoin handled this correctly;
Ethereum/DAI and Monero didn't. A related inverse bug: an *accepted* send could
be reported as failed if the post-broadcast sync hiccuped.

## What changed

### Ethereum / DAI (`wallet_ethereum`)
- `commitTx` now classifies the failure instead of throwing a flat error:
  - **pre-send** (connect/Tor-circuit failed — nothing transmitted) → new
    `RequestNotSentException`; records nothing, keeps the nonce, surfaces an
    ordinary connectivity error.
  - **post-send** (bytes out, reply lost) → records the tx as *unresolved*,
    **keeps the nonce** (so a retry reuses the slot instead of queuing a second
    payment), throws `BroadcastFailure(unknown)`.
  - **node rejection** → `rejected` (nothing moved, nonce untouched).
  - **"already known"** → treated as in-network success.
- Split the net layer so pre-send vs post-send is distinguishable
  (`RequestNotSentException` thrown from the SOCKS connect phase and the direct
  connect/write/close phase).
- **Reconciliation**: the pending tx + record carry the nonce; `refresh()`
  watches the account's *mined* nonce and, once a later tx supersedes it with no
  receipt, **removes** the never-sent tx.
- `configure` no longer force-upgrades a schemeless **local** address to https
  (fixes local http nodes).
- Load-time invariant: drop any persisted `failed` record with no block
  (impossible state — only the old mark-failed code produced it).

### Bitcoin (`wallet_bitcoin`)
- Post-broadcast sync now swallows *all* errors, not just disconnects — an
  accepted broadcast can no longer be retro-reported as failed.

### Shared UI (`wallet_ui`)
- `TxActivityRow` status cue: warning triangle for `unknown`, error mark for
  `failed`, hourglass only for a healthy pending.
- The confirm sheet no longer **crashes** when `onConfirm` throws (a pre-existing
  bug any failed send could hit).

### Domain (`wallet_domain`)
- `loadTxHistory` gained `emptyTxHistoryIsAuthoritative` (default off →
  Bitcoin/Monero unchanged); ETH opts in so a removed tx actually clears from the
  list.

### Spice app
- Confirm flow returns a typed `ConfirmSendResult`:
  - **unknown** → close sheet, show a **warning sheet** ("not confirmed as sent —
    check before sending again"), route home, no "Sent!".
  - **connection error** → close sheet, toast "Couldn't reach the server…", back
    to the form to retry (no false success).
  - **rejected** → sheet stays open (nothing moved).
- Added the `sendNoConnectionError` string (en + pt).

## Behavior matrix (send failure cases)

| Case | Sheet | History | Message |
|---|---|---|---|
| Connection error (never reached server) | closes → back to form | no tx | "Couldn't reach the server…" |
| Rejected (node refused) | stays open (retry) | no tx | generic error |
| Unknown (sent, reply lost) | closes → warning sheet → home | recorded unresolved, self-clears | warning sheet text |
| Accepted but sync failed | pops as sent | recorded ok | — |

## Tests
New/updated coverage: pre-send records nothing + keeps nonce; post-send unknown
recorded + nonce kept; already-known → sent; reconciliation removes a superseded
tx (and keeps one whose nonce isn't mined yet); Bitcoin accepted-survives-sync-
failure; the confirm sheet survives a throwing `onConfirm`; scheme-by-locality in
`configure`; the load-time failed-without-block filter. All suites green —
wallet_ethereum, wallet_bitcoin, wallet_domain, wallet_ui, spice.

Reproduced live on the emulator: connection error (no tx, sheet closes) and the
post-send unknown (via a local stub RPC that drops only the broadcast reply).

## Deferred (not started)
- **Monero**: still throws a flat `FormatException` on commit; needs the same
  unknown-classification + guarded post-broadcast bookkeeping (and a decision on
  where its unresolved marker lives, since it has no Dart-side tx map).
- **Skylight** (Monero-only): mirror the warning-sheet/display once Monero lands.
