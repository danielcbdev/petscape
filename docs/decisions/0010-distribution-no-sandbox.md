# ADR-0010: Direct distribution without App Sandbox

- Status: Accepted (distribution policy revised 2026-10-25)
- Date: 2026-10-16; owner distribution decision recorded 2026-10-25
- Related: [release.md](../development/release.md), [permissions.md](../specifications/permissions.md)

## Context

Distribution will be via GitHub Releases, outside the Mac App Store. Window interaction (M12+) needs
the Accessibility API to observe other apps. The bundle identifier cannot be assumed to be free if it
is based only on the app name.

## Problem

Decide sandboxing, signing/notarization approach and bundle identifier policy early, because changing
sandboxing later moves app data (`UserDefaults` → `~/Library/Containers/…`) and breaks permissions.

## Alternatives

| Option | Consequence |
|---|---|
| Mac App Store | Requires App Sandbox → AX observation of other apps not possible; overlay apps face review risk |
| Sandboxed, direct distribution | Same AX limitation; no benefit for this app |
| Not sandboxed, Hardened Runtime, Developer ID signed, notarized | Full public API access (AX), identified developer and a smoother Gatekeeper experience; requires paid Apple Developer Program membership |
| **Not sandboxed, ad-hoc signed** | No membership fee or Apple identity/notarization; downloaded builds may warn or be blocked by Gatekeeper and users must make their own informed trust decision |

## Decision

- **No App Sandbox. Hardened Runtime on**, with no exception entitlements.
- **Owner decision (2026-10-25): M21 will not use paid Apple Developer Program membership.**
  Release packages are ad-hoc signed and are not submitted for notarization. Verify signature
  integrity, package checksums and contents, but do not imply Apple-verified developer identity or
  Gatekeeper approval. Installation guidance describes the real macOS warning and the user-approved
  override for users who independently decide to trust the source; never disable Gatekeeper or
  remove quarantine metadata as a workaround.
- Bundle identifier is **provisional**: `io.github.danielcbdev.petscape`, defined once in
  `Config/Base.xcconfig` (`PETSCAPE_BUNDLE_ID`) so it can be changed before the first public release.
  Changing it after release resets users' preferences and permission grants.

## Rationale

The product's differentiating features need AX; sandboxing provides no user-facing benefit for a
local, network-free app. The owner chose a no-cost release path for M21. This preserves the
unsandboxed feature set but sacrifices Developer ID identity and notarization, so the resulting
download may produce Gatekeeper friction and does not provide Apple's notarization assurance.
Revisit the distribution trust model only if the owner changes this decision.

## Consequences

- Mac App Store distribution is not possible without a feature-reduced variant (not planned).
- Developer ID and notarization are deferred from M21 by owner decision; see
  [release policy](../development/release.md).

## Risks

| Risk | Mitigation |
|---|---|
| Ad-hoc release → Gatekeeper warnings and no Apple-verified identity | Clear install/security instructions, checksum, and explicit disclosure; users choose whether to approve the app |
| Bundle ID collides or is changed late | Decide before first public release (open decision D-03) |
