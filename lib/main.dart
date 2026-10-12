import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/fixes/add_dispose_call.dart';
import 'src/fixes/convert_to_list_builder.dart';
import 'src/fixes/use_riverpod_select.dart';
import 'src/rules/avoid_animated_opacity_widget.dart';
import 'src/rules/avoid_heavy_work_in_build.dart';
import 'src/rules/avoid_setstate_large_subtree.dart';
import 'src/rules/image_without_cache_size.dart';
import 'src/rules/prefer_list_builder.dart';
import 'src/rules/prefer_riverpod_select.dart';
import 'src/rules/undisposed_controller.dart';

/// The entry point the Dart analysis server loads.
final plugin = FlutterPerfLintsPlugin();

/// Registers every rule and quick fix of `flutter_perf_lints`.
///
/// All rules are registered as warning rules, so they are on by default and
/// can be turned off one by one under `plugins: flutter_perf_lints:
/// diagnostics:` in `analysis_options.yaml`.
class FlutterPerfLintsPlugin extends Plugin {
  @override
  String get name => 'flutter_perf_lints';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(UndisposedController())
      ..registerWarningRule(ImageWithoutCacheSize())
      ..registerWarningRule(PreferListBuilder())
      ..registerWarningRule(AvoidAnimatedOpacityWidget())
      ..registerWarningRule(PreferRiverpodSelect())
      ..registerWarningRule(AvoidSetStateLargeSubtree())
      ..registerWarningRule(AvoidHeavyWorkInBuild())
      ..registerFixForRule(UndisposedController.code, AddDisposeCall.new)
      ..registerFixForRule(PreferListBuilder.code, ConvertToListBuilder.new)
      ..registerFixForRule(PreferRiverpodSelect.code, UseRiverpodSelect.new);
  }
}
