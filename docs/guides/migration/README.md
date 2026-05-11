# Migration guides

This directory holds migration guides for Spreedly iOS SDK major-version upgrades. Pick the file matching your upgrade path.

## Naming convention

Each guide is named `vN-to-vN+1.md`, where `N` is the previous major and `N+1` is the new major:

| File | Covers |
|---|---|
| `v1-to-v2.md` | Migrating an integration from `1.x` to `2.0.0` |
| `v2-to-v3.md` | Migrating an integration from `2.x` to `3.0.0` |

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

