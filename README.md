# Comanda — Restaurant Management App

A multi-tenant restaurant management app built with **Flutter**, backed by a **FastAPI + PostgreSQL** API.
Restaurant owners run their business from their phone: tables and orders, kitchen dispatch, billing,
daily inventory, cash register and staff — with a permission system that keeps every role in its lane.

> **Comanda** *(Spanish)* — the order ticket a waiter takes to the kitchen.

**Backend repository:** [proyecto_manhattan_backen](https://github.com/jsalas607/proyecto_manhattan_backen)
· Live API: `api.manhattan-project.online`

---

## Features

| Module | What it does |
|---|---|
| **Tables & orders** | Create tables, take orders with per-item options (e.g. *Protein: chicken*), edit and close them. |
| **Kitchen dispatch** | Custom screens per category — the kitchen only sees what it cooks and marks items ready. |
| **Billing** | Charge a table, split across multiple payment methods, register the sale. |
| **Inventory** | Daily stock counts, purchases and waste. Today's expected stock carries over from yesterday's real count. |
| **Cash register** | Open/close the register with starting amounts; totals per payment method include the day's sales. |
| **Finance** | Expenses, losses and daily stats (orders, revenue, average ticket). |
| **Staff & roles** | Custom roles built from 14 granular permissions; each employee only sees the sections they're allowed. |
| **Multi-restaurant** | One account can own several restaurants; data never crosses between them. |

## Permission model

The interesting part of this project. Four levels, all enforced **server-side** (the UI only mirrors them):

| Level | Scope |
|---|---|
| **Superadmin** | The platform. Sees everything, creates and deactivates owners (the paying customers). |
| **Owner** | A paying customer. Only one who can create restaurants; sees **only the restaurants they own**. |
| **Manager** | An employee whose role includes `administrar_restaurante`. Manages regular staff, but **cannot see or delete other managers** (nor themselves). |
| **Employee** | Sees only the sections their role's permissions allow. |

Two owners are fully isolated: one can't list, read or touch the other's restaurants, employees or sales.
Deactivating an owner freezes their whole tenant — their employees lose access too — without deleting any data.

## Tech stack

- **Flutter 3 / Dart** — Material 3, custom dark theme, `google_fonts` (Plus Jakarta Sans)
- **HTTP + JWT** — token persisted with `shared_preferences`
- **Backend** — FastAPI (async), SQLAlchemy, PostgreSQL, Alembic, Docker Compose

## Architecture

```
lib/
├── core/           Infrastructure
│   ├── api_client.dart      HTTP wrapper: base URL, Bearer token, JSON, errors → ApiException
│   ├── api_config.dart      Backend host (single source of truth)
│   ├── session.dart         JWT + user id, persisted across launches
│   ├── api_exception.dart   Typed errors carrying the HTTP status code
│   └── app_design_system.dart  Colors, typography, theme
├── mock/           API layer — one module per domain (auth, menu, orders, inventory…)
├── screens/        36 screens
├── widgets/        Shared components
└── main.dart
```

**Design decisions worth noting:**

- **One HTTP choke point.** Every request goes through `ApiClient`'s five static methods. Swapping the
  entire data source means touching one file — which is exactly how an offline build was prototyped,
  by replacing its body with a local persistence layer and changing nothing else.
- **`Mock*Api` naming is historical.** The app started as a UI prototype backed by in-memory mocks.
  When the real backend landed, the classes kept their names and method signatures so none of the 36
  screens had to change — only their internals became real HTTP calls.
- **Status codes carry meaning.** `ApiException` exposes the HTTP code, so callers can turn a `404`
  into `null` or surface a `403` as a message instead of a crash.
- **Routing by role.** `auth_flow.dart` resolves the landing screen from the user's level:
  superadmin → control panel, owner → restaurant list, employee with one restaurant → straight into it.

## Getting started

```bash
flutter pub get
flutter run
```

The app points at the hosted API by default. To use a different backend, edit the host in
[`lib/core/api_config.dart`](lib/core/api_config.dart):

```dart
static const String host = 'api.manhattan-project.online';
```

Build a release APK:

```bash
flutter build apk --release   # → build/app/outputs/flutter-apk/app-release.apk
```

Regenerate launcher icons after changing `assets/icon/comanda.png`:

```bash
dart run flutter_launcher_icons
```

## Project status

Working end-to-end and running on a physical device against a deployed backend.

Known gaps, kept honest:

- **Image upload is a placeholder.** The photo pickers toggle a flag; the backend endpoint exists but
  isn't wired to a real image picker yet.
- **WebSockets are prepared, not used.** `core/ws_client.dart` implements the client and the backend
  broadcasts events, but screens currently refresh over REST. Live order screens are the next step.
- **Test coverage is thin on the app side.** The logic that matters (isolation, role hierarchy,
  permissions) is covered by end-to-end tests in the backend repo instead.

---

Built by [jsalas607](https://github.com/jsalas607).
