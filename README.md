# Cookory

> Photograph what you cooked, and your household's culinary history grows on its own.

An iOS app for recording home cooking. Not a recipe finder — a record of what
you have actually made, how each dish improved over time, and what became a
staple in your home.

**日本語版は [README.ja.md](README.ja.md) をご覧ください。**

[![CI](https://github.com/y-as-u-16/Cookory/actions/workflows/ci.yml/badge.svg)](https://github.com/y-as-u-16/Cookory/actions/workflows/ci.yml)
[![Architecture](https://github.com/y-as-u-16/Cookory/actions/workflows/architecture.yml/badge.svg)](https://github.com/y-as-u-16/Cookory/actions/workflows/architecture.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Status

**Early development.** The design is complete and documented; implementation is
just beginning. The app does not do anything useful yet.

What exists today:

| Area | State |
|---|---|
| Product & architecture design | Documented ([docs/](docs/)) |
| CI (build, test, architecture rules) | Working |
| Domain / Data / Feature layers | Not yet implemented |

---

## Concept

Most cooking apps answer *what should I cook next?* Cookory answers a different
question: *what have we cooked, and what became ours?*

```
cook → photograph → saved in seconds → linked to the same dish over time
  ↑                                                          │
  └──────────── "let's make that again" ←────────────────────┘
```

The guiding principle:

> **Recording must be effortless. Looking back should be rich.**

A photo is the only required input. Dish name, rating, and notes are all
optional and can be added later — or never.

---

## Core features

- **Capture** — record a meal in under 10 seconds; the photo saves before you
  fill in anything else
- **Cookbook** — a personal dish encyclopedia built only from what you actually
  cooked
- **History** — every time you made the same dish, in sequence, so improvement
  is visible
- **Memory** — resurfaces dishes you have not made in a while, and what you
  cooked a year ago today

---

## Architecture

Feature-Based + Clean Architecture + MVVM, local-first, with CQRS-lite for
read-heavy screens.

```
Presentation  →  Application  →  Domain  ←  Data
 SwiftUI          UseCase        Entity     SwiftData
 ViewModel        Query          Port       FileSystem
```

Dependencies point inward. `Domain` imports nothing but `Foundation`, so the
business rules stay independent of SwiftUI, SwiftData, and any future backend.

Three decisions worth calling out:

1. **SwiftData models are not domain entities.** They are separate types with
   explicit mappers, so persistence concerns never leak into business rules.
2. **Repositories are per aggregate, never per screen.** `HomeRepository` is
   forbidden; `MealRecordRepository` is correct. Screen-specific reads become
   Query objects instead.
3. **The local database is the single source of truth.** When cloud sync is
   added, it sits *behind* SwiftData — the UI never talks to a remote API
   directly.

These are not aspirations. They are enforced in CI by
[`scripts/check-architecture.sh`](scripts/check-architecture.sh), which fails
the build on violation.

Full rationale: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

---

## Documentation

| Document | Contents |
|---|---|
| [docs/APP_DESIGN.md](docs/APP_DESIGN.md) | Product design — concept, UX principles, screens, MVP scope, roadmap |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Technical design — layers, entities, persistence, testing, sync strategy |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | How to build, test, and contribute changes |

---

## Requirements

- Xcode 26 or later
- iOS 26.5+ deployment target
- Swift 5.0 language mode

## Getting started

```bash
git clone https://github.com/y-as-u-16/Cookory.git
cd Cookory
open Cookory.xcodeproj
```

`DEVELOPMENT_TEAM` is intentionally empty so the project builds without a
signing identity. Set your own team in Xcode's *Signing & Capabilities* tab to
run on a physical device; the simulator needs no configuration.

Run the test suite from the command line:

```bash
xcodebuild test \
  -project Cookory.xcodeproj \
  -scheme Cookory \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:CookoryTests
```

---

## License

[MIT](LICENSE) © 2026 y_as_u_16

The source is MIT-licensed. The name *Cookory*, its icon, and its App Store
presence are not covered by that grant.
