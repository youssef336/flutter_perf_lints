<p align="center"><a href="README.ar.md">العربية</a></p>

<h1 align="center">Flutter Perf Lints</h1>

<p align="center">
  Lint rules that catch Flutter performance and memory problems while you type: leaked controllers, full-size image decodes, eager lists, animated Opacity, oversized rebuilds and heavy work in <code>build()</code>.
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_perf_lints"><img src="https://img.shields.io/pub/v/flutter_perf_lints?style=for-the-badge&logo=dart&label=pub.dev" alt="pub.dev"/></a>
  <img src="https://img.shields.io/badge/Dart-3.11%2B-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart 3.11+">
  <img src="https://img.shields.io/badge/Flutter-3.41%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/analyzer-plugin-2ea44f?style=for-the-badge" alt="Analyzer plugin">
  <img src="https://img.shields.io/badge/rules-7-orange?style=for-the-badge" alt="7 rules">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="MIT">
</p>

> **Summary.** `flutter_perf_lints` is an analyzer plugin built on the **official Dart
> analyzer plugin system** (`analysis_server_plugin`, enabled from the top-level `plugins:` section of
> `analysis_options.yaml`; no `custom_lint`, no extra dev dependency, no separate CLI). Its seven rules
> show up in the IDE and in `dart analyze`: undisposed controllers / focus nodes / subscriptions /
> timers in a `State`, images decoded at full resolution, `ListView`/`GridView`/`Column` built eagerly
> from a dynamic list, `Opacity` driven by an animation, `ref.watch(p)` where only one property is read,
> `setState` in a State with a huge `build()`, and parsing / regex / sorting / sync I/O inside `build()`.
> Three rules ship IDE quick fixes. Rules match Flutter types by name, so they keep working on partially
> resolved code, and every rule is unit-tested with `analyzer_testing`.

A lints package that catches Flutter performance and memory problems **while you type**: a controller
you forgot to `dispose`, a 4000px image decoded just to be shown at 48px, a list that builds all of
its items at once, an `Opacity` rebuilt every frame, and a `setState` that rebuilds a whole screen
because one number changed. The warnings show up in the IDE and in `dart analyze`, and you don't
add anything to `pubspec.yaml`.

## ✨ What it catches

| Rule | What it catches | Fix | Quick fix |
|---|---|---|---|
| `undisposed_controller` ⚠️ | `AnimationController`, `TextEditingController`, `ScrollController`, `PageController`, `TabController`, `FocusNode`, `ValueNotifier`/`ChangeNotifier`, `StreamSubscription`, `Timer` created inside a `State` that nobody calls `dispose()`/`cancel()` on | Close it in `dispose()` | ✅ adds the line (and creates `dispose()` if it doesn't exist) |
| `image_without_cache_size` | `Image.network/asset/file/memory` without `cacheWidth`/`cacheHeight`, and `NetworkImage(...)` not wrapped in a `ResizeImage` | Decode the image at the size it will be shown at | ✗ |
| `prefer_list_builder` | `ListView(children:)`/`GridView(children:)`, or a `Column`/`Row` inside a `SingleChildScrollView`, whose children come from `.map(...)`, `List.generate` or `for` | `ListView.builder` / `GridView.builder` | ✅ for the `ListView(children: xs.map(...).toList())` shape |
| `avoid_animated_opacity_widget` | `Opacity` whose value is `animation.value`, or inside the `builder` of an `AnimatedBuilder` | `FadeTransition` | ✗ |
| `prefer_riverpod_select` | `final s = ref.watch(p);` and then you only read `s.count` | `ref.watch(p.select((v) => v.count))` | ✅ |
| `avoid_setstate_large_subtree` | `setState` in a `State` whose `build` is more than 60 lines or more than 25 widgets | `ValueNotifier` + `ValueListenableBuilder`, or a smaller widget | ✗ |
| `avoid_heavy_work_in_build` | Inside `build`: `jsonDecode`, `RegExp(...)`, `DateFormat(...)`, `NumberFormat(...)`, `.sort()`, `readAsStringSync` and friends | Compute it once (initState, a field, `static final`, a provider) | ✗ |

⚠️ = warning; the rest are info. All rules are **on by default** as soon as you enable the package.

## 📦 Installation

Requires **Dart 3.11+** (Flutter 3.41 or newer). In your project's `analysis_options.yaml`
(at the root, not in a subfolder), add `plugins:` as its own top-level section:

```yaml
plugins:
  flutter_perf_lints: ^0.1.0
```

To pin a specific version:

```yaml
plugins:
  flutter_perf_lints: ^0.1.0
```

- You **don't** need to add it to `pubspec.yaml` or `dev_dependencies`: the analysis server fetches it by itself.
- After any change to `plugins:`, **restart the analysis server** (in VS Code:
  "Dart: Restart Analysis Server"; in Android Studio: the restart button in the Dart Analysis tab).
- The first time takes a few seconds while the plugin is built; after that it is cached.

## 🔕 Turning a rule off

A specific rule for the whole project:

```yaml
plugins:
  flutter_perf_lints: ^0.1.0
    diagnostics:
      avoid_heavy_work_in_build: false
      prefer_riverpod_select: false
```

Or change its severity (`error` / `warning` / `info`):

```yaml
    diagnostics:
      undisposed_controller: error
```

Or for a single line / a single file (note the plugin name before the rule):

```dart
// ignore: flutter_perf_lints/image_without_cache_size
Image.asset('assets/logo.png'),

// ignore_for_file: flutter_perf_lints/prefer_list_builder
```

## 🧪 Try it quickly

The `example/` folder contains a small app with one deliberate mistake per rule:

```bash
cd example
flutter pub get
dart analyze
```

You should get 12 warnings from the seven rules.

## ❓ FAQ

**Why does `dart analyze` show the warnings but `flutter analyze` doesn't?**
Since Flutter 3.47, `flutter analyze` talks to the analysis server over LSP and exits as soon as
the core analysis finishes, a few seconds before plugins (including this one) send their results.
This comes from the flutter tool, not from the package: the IDE shows the warnings normally, and
`dart analyze` waits for them. In CI, use `dart analyze`.

**Is this a replacement for `custom_lint`?**
Yes. It is built on Dart's official plugin system (since 3.10), so you don't need `custom_lint` in
`dev_dependencies` or a separate command: the same `dart analyze` and the same IDE.

**Do I need Riverpod for `prefer_riverpod_select`?**
No. The rule only looks at the code (`ref.watch(...)` stored in a variable), so if you don't use
Riverpod it will never fire.

**Why does a rule fire on code I'm sure is fine?**
The rules are heuristic and match by name, so they can be wrong in cases like:
an `Image.asset` for an icon that is already small, a `DateFormat` in the `build` of a screen that
is rarely built, or a controller closed in a helper that isn't called from `dispose()`. Use
`// ignore:` for that case, or turn the rule off.

**Can I change the thresholds of `avoid_setstate_large_subtree`?**
Not yet from `analysis_options.yaml` (the plugin system doesn't provide rule options so far).
The thresholds are 60 lines / 25 widgets; if they don't suit you, turn the rule off or change its
severity.

**Do the quick fixes work with `dart fix`?**
No. The plugin system only shows them in the IDE (💡 next to the warning), not in `dart fix --apply`.

## ⚖️ Limitations

- `undisposed_controller` considers a resource closed if `dispose()`/`cancel()`/`close()` is called
  on it anywhere in the class, or if it is passed to anything inside `dispose()` (a loop, a helper).
  This reduces false alarms but can miss some cases.
- A controller that comes from outside (`_c = widget.controller`) is not counted, because the State
  doesn't own it.
- `avoid_heavy_work_in_build` ignores callbacks whose names start with `on` (`onTap`, `onPressed` …),
  but does count builders (`itemBuilder`, `builder`) because they run at build time.

## 🛠 Tech stack

- Dart analyzer plugin on [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin)
  and [`analyzer`](https://pub.dev/packages/analyzer) (`AnalysisRule` + `SimpleAstVisitor`).
- IDE quick fixes as `ResolvedCorrectionProducer`s.
- Tests with [`analyzer_testing`](https://pub.dev/packages/analyzer_testing) (`AnalysisRuleTest`) and
  `test_reflective_loader`, against a small stub `package:flutter`, so the suite needs no Flutter SDK.

## 🏗 Project structure

| Path | Role |
|---|---|
| `lib/main.dart` | the plugin entry point the analysis server loads (`plugin` top-level) |
| `lib/src/rules/` | one file per rule |
| `lib/src/fixes/` | quick fixes, with their edit planning kept testable on parsed code |
| `lib/src/utils.dart` | constructor-call matching across resolved / unresolved code, `State` / `build` helpers |
| `test/` | one test file per rule (positive + negative cases) plus fix tests |
| `example/` | a Flutter app with one deliberate violation per rule |

## 🚀 Development

```bash
git clone https://github.com/youssef336/flutter_perf_lints.git
cd flutter_perf_lints
dart pub get
dart test
dart analyze
cd example && flutter pub get && dart analyze   # every rule should fire
```

## 📄 License

[MIT](LICENSE)

## 👤 Author

**Youssef Belal Zakaria** · [GitHub @youssef336](https://github.com/youssef336)

⭐ If you like this project, give it a star!
