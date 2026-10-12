## 0.1.0

First release, built on the official Dart analyzer plugin system
(`analysis_server_plugin`, Dart 3.10+).

Rules (all on by default):

- `undisposed_controller` (warning): controllers, focus nodes, notifiers,
  stream subscriptions and timers created by a `State` and never released.
  Quick fix: release it in `dispose()` (creating the method if needed).
- `image_without_cache_size`: `Image.network/asset/file/memory` without
  `cacheWidth`/`cacheHeight`, and `NetworkImage`/`FileImage`/`MemoryImage`
  not wrapped in `ResizeImage`.
- `prefer_list_builder`: `ListView`/`GridView` (and `Column`/`Row` directly
  in a `SingleChildScrollView`) whose `children` come from `.map()`,
  `List.generate` or a collection-`for`. Quick fix for
  `ListView(children: xs.map(...).toList())`.
- `avoid_animated_opacity_widget`: `Opacity` driven by an animation value or
  built inside an `AnimatedBuilder`.
- `prefer_riverpod_select`: `final x = ref.watch(p)` where only one property
  of `x` is ever read. Quick fix: `ref.watch(p.select((v) => v.prop))`.
- `avoid_setstate_large_subtree`: `setState` in a `State` whose `build` is
  longer than 60 lines or has more than 25 widget constructors.
- `avoid_heavy_work_in_build`: `jsonDecode`, `RegExp(...)`, `DateFormat(...)`,
  `NumberFormat(...)`, `.sort()` and synchronous file I/O inside `build`.
