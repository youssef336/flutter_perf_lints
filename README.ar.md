<p align="center"><a href="README.md">English</a></p>

<p align="center"><img src="https://raw.githubusercontent.com/youssef336/flutter_perf_lints/main/screenshots/banner.png" alt="flutter_perf_lints banner" width="100%"></p>

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

> **English summary.** `flutter_perf_lints` is an analyzer plugin built on the **official Dart
> analyzer plugin system** (`analysis_server_plugin`, enabled from the top-level `plugins:` section of
> `analysis_options.yaml`; no `custom_lint`, no extra dev dependency, no separate CLI). Its seven rules
> show up in the IDE and in `dart analyze`: undisposed controllers / focus nodes / subscriptions /
> timers in a `State`, images decoded at full resolution, `ListView`/`GridView`/`Column` built eagerly
> from a dynamic list, `Opacity` driven by an animation, `ref.watch(p)` where only one property is read,
> `setState` in a State with a huge `build()`, and parsing / regex / sorting / sync I/O inside `build()`.
> Three rules ship IDE quick fixes. Rules match Flutter types by name, so they keep working on partially
> resolved code, and every rule is unit-tested with `analyzer_testing`.

<div dir="rtl">

باكدج lints بتمسك مشاكل الأداء والذاكرة في Flutter **وإنت بتكتب**: controller نسيت تعمله dispose،
صورة 4000px بتتفك عشان تظهر 48px، ليستة بتبني كل العناصر مرة واحدة، `Opacity` بتتبني كل frame،
و`setState` بيعيد بناء شاشة كاملة عشان رقم واحد اتغير. التحذيرات بتظهر في الـ IDE وفي `dart analyze`،
ومن غير ما تضيف أي حاجة لـ `pubspec.yaml`.

## ✨ بتمسك إيه

| القاعدة | بتمسك إيه | الحل | Quick fix |
|---|---|---|---|
| `undisposed_controller` ⚠️ | `AnimationController`، `TextEditingController`، `ScrollController`، `PageController`، `TabController`، `FocusNode`، `ValueNotifier`/`ChangeNotifier`، `StreamSubscription`، `Timer` اتعملوا جوه الـ `State` ومحدش عملهم `dispose()`/`cancel()` | اقفله في `dispose()` | ✅ بيضيف السطر (وبيعمل `dispose()` لو مش موجودة) |
| `image_without_cache_size` | `Image.network/asset/file/memory` من غير `cacheWidth`/`cacheHeight`، و`NetworkImage(...)` مش ملفوفة في `ResizeImage` | فك الصورة على المقاس اللي هتظهر بيه | ✗ |
| `prefer_list_builder` | `ListView(children:)`/`GridView(children:)`، أو `Column`/`Row` جوه `SingleChildScrollView`، والـ children جايين من `.map(...)` أو `List.generate` أو `for` | `ListView.builder` / `GridView.builder` | ✅ لشكل `ListView(children: xs.map(...).toList())` |
| `avoid_animated_opacity_widget` | `Opacity` قيمتها `animation.value`، أو جوه `builder` بتاع `AnimatedBuilder` | `FadeTransition` | ✗ |
| `prefer_riverpod_select` | `final s = ref.watch(p);` وبعدين بتقرا `s.count` بس | `ref.watch(p.select((v) => v.count))` | ✅ |
| `avoid_setstate_large_subtree` | `setState` في `State` الـ `build` بتاعها أكتر من 60 سطر أو أكتر من 25 widget | `ValueNotifier` + `ValueListenableBuilder`، أو widget أصغر | ✗ |
| `avoid_heavy_work_in_build` | جوه `build`: `jsonDecode`، `RegExp(...)`، `DateFormat(...)`، `NumberFormat(...)`، `.sort()`، `readAsStringSync` وأخواتها | احسبها مرة واحدة (initState، field، `static final`، provider) | ✗ |

⚠️ = warning، والباقي info. كل القواعد **شغالة لوحدها** من أول ما تفعّل الباكدج.

## 📦 التسطيب

محتاج **Dart 3.11+** (Flutter 3.41 أو أحدث). في `analysis_options.yaml` بتاع مشروعك
(في الـ root، مش في فولدر جوه)، ضيف `plugins:` كـ section لوحده على أول مستوى:

</div>

```yaml
plugins:
  flutter_perf_lints: ^0.1.0
```

<div dir="rtl">

ولو عايز تثبّت نسخة معينة:

</div>

```yaml
plugins:
  flutter_perf_lints: ^0.1.0
```

<div dir="rtl">

- **مش** محتاج تضيفها في `pubspec.yaml` ولا `dev_dependencies`: الـ analysis server بيجيبها لوحده.
- بعد أي تعديل في `plugins:` **اعمل restart للـ analysis server** (في VS Code:
  «Dart: Restart Analysis Server»، وفي Android Studio: زرار الـ restart في تاب Dart Analysis).
- أول مرة بتاخد ثواني لحد ما الـ plugin يتبني، وبعد كده بيبقى cached.

## 🔕 تقفل قاعدة

قاعدة معينة للمشروع كله:

</div>

```yaml
plugins:
  flutter_perf_lints: ^0.1.0
    diagnostics:
      avoid_heavy_work_in_build: false
      prefer_riverpod_select: false
```

<div dir="rtl">

أو تغيّر درجتها (`error` / `warning` / `info`):

</div>

```yaml
    diagnostics:
      undisposed_controller: error
```

<div dir="rtl">

أو في سطر واحد / فايل واحد (لاحظ اسم الـ plugin قبل القاعدة):

</div>

```dart
// ignore: flutter_perf_lints/image_without_cache_size
Image.asset('assets/logo.png'),

// ignore_for_file: flutter_perf_lints/prefer_list_builder
```

<div dir="rtl">

## 🧪 تجربها بسرعة

فولدر `example/` فيه app صغير فيه غلطة مقصودة لكل قاعدة:

</div>

```bash
cd example
flutter pub get
dart analyze
```

<div dir="rtl">

والمفروض يطلع 12 تحذير من السبع قواعد.

## ❓ أسئلة

**ليه `flutter analyze` مش بيطلّع التحذيرات و`dart analyze` بيطلّعها؟**
من Flutter 3.47 الأمر `flutter analyze` بقى بيكلم الـ analysis server عن طريق LSP، وبيخرج أول ما
التحليل الأساسي يخلص، قبل ما الـ plugins (ومنها دي) تبعت نتايجها بثواني. ده من أداة flutter مش من
الباكدج: الـ IDE بيعرض التحذيرات عادي، و`dart analyze` بيستناها. في الـ CI استخدم `dart analyze`.

**ده بديل لـ `custom_lint`؟**
آه. دي مبنية على نظام الـ plugins الرسمي بتاع Dart (من 3.10)، فمش محتاج `custom_lint` في
`dev_dependencies` ولا أمر منفصل: نفس `dart analyze` ونفس الـ IDE.

**محتاج Riverpod عشان `prefer_riverpod_select`؟**
لأ. القاعدة بتبص على الكود بس (`ref.watch(...)` متخزّن في متغيّر)، فلو مش بتستخدم Riverpod مش
هتطلع خالص.

**ليه قاعدة بتطلع على كود أنا متأكد إنه سليم؟**
القواعد heuristic وبتطابق الأسماء، فممكن تطلع غلط في حالات زي:
`Image.asset` لأيقونة صغيرة أصلًا، أو `DateFormat` في `build` لشاشة نادرًا بتتبني، أو controller
بيتقفل في helper مش بيتنادي من `dispose()`. استخدم `// ignore:` للحالة دي، أو اقفل القاعدة.

**أقدر أغيّر حدود `avoid_setstate_large_subtree`؟**
لسه لأ من `analysis_options.yaml` (نظام الـ plugins مش بيدّي options للقواعد لحد دلوقتي).
الحدود 60 سطر / 25 widget، ولو مش مناسبة اقفلها أو غيّر درجتها.

**الـ quick fixes بتشتغل مع `dart fix`؟**
لأ. نظام الـ plugins بيعرضها في الـ IDE بس (💡 جنب التحذير)، مش في `dart fix --apply`.

## ⚖️ الحدود

- `undisposed_controller` بيعتبر الحاجة اتقفلت لو اتنادى عليها `dispose()`/`cancel()`/`close()`
  في أي حتة في الـ class، أو لو اتبعتت لأي حاجة جوه `dispose()` (loop، helper). ده بيقلّل الإنذارات
  الغلط بس ممكن يفوّت حالات.
- controller جاي من بره (`_c = widget.controller`) مش بيتحسب، لأنه مش ملك الـ State.
- `avoid_heavy_work_in_build` بيتجاهل الـ callbacks اللي بتبدأ بـ `on` (`onTap`، `onPressed` …)،
  بس بيعدّ الـ builders (`itemBuilder`، `builder`) لأنها بتشتغل وقت البناء.

</div>

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
