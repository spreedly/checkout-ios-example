# Migration guides

Pick the guide that matches your upgrade path.

## From web iframe-ui

| Guide | Covers |
|---|---|
| [from-legacy.md](from-legacy.md) | iframe-ui / iFrame v1 → native **`SPLTextField`** or **`CardFormDropIn`**: `HostedFieldState` (including **`iin`** prefix on card number), `setNumberFormat` / `toggleMask`, headless vs express matrix, **not the same as iframe** gaps (`luhnValid`, `setValue`), mapping tables, and code samples |
| [Headless PAN API quick reference](../custom-payment-forms.md#headless-pan-api-quick-reference) | SwiftUI, UIKit, and Objective-C cheat sheet — field params, global mask APIs, `HostedFieldState`, pay/validate (headless only) |

## Major-version upgrades

When a new **major** iOS SDK version ships, migration guides are published here as `vN-to-vN+1.md` and linked from [`CHANGELOG.md`](../../CHANGELOG.md). Until a guide exists for your target major, use the CHANGELOG **Breaking Changes** section and re-run your integration tests after bumping the package version.

## What you'll find in a guide

A migration guide covers everything you need to upgrade an integration to the new major version:

| Section | Content |
|---|---|
| Summary | What changed at a high level and who is affected |
| Breaking changes | Concrete API differences with before/after Swift snippets |
| Deprecations carried forward | APIs deprecated in `N.x` and removed in `N+1` |
| Step-by-step upgrade | Ordered checklist: bump dependency, update Xcode/Swift floors, fix compiler errors, run regression tests |
| Compatibility matrix | Required Xcode, Swift, and iOS minimums for the new major |
| Backporting notes | What is supported on `release/N.x` and what is not |

## See also

- [`CHANGELOG.md`](../../CHANGELOG.md) — major releases link to the relevant migration guide here

