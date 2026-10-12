import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';

/// Base class for rule tests.
///
/// The rules match Flutter types by name, so instead of the real Flutter SDK
/// the tests use a small stub `package:flutter` (plus `package:stubs` for
/// `dart:io` / `intl` / riverpod look-alikes that the analyzer's mock SDK
/// does not provide).
abstract class PerfRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage('flutter').addFile('lib/widgets.dart', _flutterStubs);
    newPackage('stubs').addFile('lib/stubs.dart', _otherStubs);
    super.setUp();
  }

  /// The offset of the [occurrence]-th [snippet] in [code].
  int offsetOf(String code, String snippet, {int occurrence = 1}) {
    var offset = -1;
    for (var i = 0; i < occurrence; i++) {
      offset = code.indexOf(snippet, offset + 1);
      if (offset < 0) {
        throw ArgumentError('"$snippet" (#$occurrence) not found in the code');
      }
    }
    return offset;
  }

  /// Asserts that the rule under test reports exactly one diagnostic on
  /// each of [snippets] in [code], and nothing else.
  ///
  /// A snippet listed twice matches its first and then its second
  /// occurrence in [code].
  Future<void> assertLintsAt(String code, List<String> snippets) {
    final seen = <String, int>{};
    return assertDiagnostics(code, [
      for (final snippet in snippets)
        lint(
          offsetOf(
            code,
            snippet,
            occurrence: seen[snippet] = (seen[snippet] ?? 0) + 1,
          ),
          snippet.length,
        ),
    ]);
  }
}

const String _flutterStubs = r'''
abstract class Key {}
abstract class BuildContext {}

abstract class Widget {
  const Widget({Key? key});
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget({super.key});
  Widget build(BuildContext context);
}

abstract class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
  State createState();
}

abstract class State<T extends StatefulWidget> {
  T get widget => throw 0;
  BuildContext get context => throw 0;
  void initState() {}
  void didChangeDependencies() {}
  void dispose() {}
  void setState(void Function() fn) {}
  Widget build(BuildContext context);
}

mixin TickerProviderStateMixin<T extends StatefulWidget> on State<T> {}

abstract class Listenable {}

class ChangeNotifier implements Listenable {
  void addListener(void Function() listener) {}
  void removeListener(void Function() listener) {}
  void dispose() {}
}

class ValueNotifier<T> extends ChangeNotifier {
  ValueNotifier(this.value);
  T value;
}

abstract class Animation<T> implements Listenable {
  T get value;
}

class AnimationController extends Animation<double> {
  AnimationController({Object? vsync, Duration? duration});
  @override
  double get value => 0;
  void forward() {}
  void dispose() {}
}

class TextEditingController extends ChangeNotifier {
  TextEditingController({String? text});
}

class ScrollController extends ChangeNotifier {}

class PageController extends ScrollController {}

class TabController extends ChangeNotifier {
  TabController({required int length, required Object vsync});
}

class FocusNode extends ChangeNotifier {}

class EdgeInsets {
  const EdgeInsets.all(double value);
}

class Text extends Widget {
  const Text(String data, {super.key});
}

class SizedBox extends Widget {
  const SizedBox({super.key, double? width, double? height, Widget? child});
}

class Padding extends Widget {
  const Padding({super.key, required EdgeInsets padding, Widget? child});
}

class Container extends Widget {
  const Container({super.key, Widget? child});
}

class Column extends Widget {
  const Column({super.key, List<Widget> children = const []});
}

class Row extends Widget {
  const Row({super.key, List<Widget> children = const []});
}

class GestureDetector extends Widget {
  const GestureDetector({super.key, void Function()? onTap, Widget? child});
}

class SingleChildScrollView extends Widget {
  const SingleChildScrollView({super.key, Widget? child});
}

class ListView extends Widget {
  ListView({super.key, List<Widget> children = const []});
  ListView.builder({
    super.key,
    int? itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  });
}

class GridView extends Widget {
  GridView({super.key, required Object gridDelegate, List<Widget> children = const []});
  GridView.count({super.key, required int crossAxisCount, List<Widget> children = const []});
  GridView.builder({
    super.key,
    required Object gridDelegate,
    required Widget Function(BuildContext, int) itemBuilder,
  });
}

class Opacity extends Widget {
  const Opacity({super.key, required double opacity, Widget? child});
}

class FadeTransition extends Widget {
  const FadeTransition({super.key, required Animation<double> opacity, Widget? child});
}

class AnimatedBuilder extends Widget {
  const AnimatedBuilder({
    super.key,
    required Listenable animation,
    required Widget Function(BuildContext, Widget?) builder,
    Widget? child,
  });
}

class ValueListenableBuilder<T> extends Widget {
  const ValueListenableBuilder({
    super.key,
    required ValueNotifier<T> valueListenable,
    required Widget Function(BuildContext, T, Widget?) builder,
  });
}

abstract class ImageProvider<T extends Object> {
  const ImageProvider();
}

class NetworkImage extends ImageProvider<NetworkImage> {
  const NetworkImage(String url);
}

class ResizeImage extends ImageProvider<ResizeImage> {
  const ResizeImage(ImageProvider<Object> imageProvider, {int? width, int? height});
  static ImageProvider<Object> resizeIfNeeded(
    int? cacheWidth,
    int? cacheHeight,
    ImageProvider<Object> provider,
  ) => provider;
}

class Image extends Widget {
  const Image({super.key, required ImageProvider<Object> image});
  Image.network(String src, {super.key, int? cacheWidth, int? cacheHeight, double? width});
  Image.asset(String name, {super.key, int? cacheWidth, int? cacheHeight});
  Image.file(Object file, {super.key, int? cacheWidth, int? cacheHeight});
}
''';

const String _otherStubs = r'''
class Timer {
  Timer(Duration duration, void Function() callback);
  Timer.periodic(Duration duration, void Function(Timer) callback);
  void cancel() {}
}

class StreamSubscription<T> {
  void cancel() {}
}

class Stream<T> {
  StreamSubscription<T> listen(void Function(T) onData) => StreamSubscription<T>();
}

dynamic jsonDecode(String source) => null;

class File {
  File(String path);
  String readAsStringSync() => '';
}

class DateFormat {
  DateFormat([String? pattern]);
  DateFormat.yMd();
  String format(DateTime date) => '';
}

class Items {
  void sort([int Function(int, int)? compare]) {}
}

class Counter {
  int count = 0;
  String label = '';
  void increment() {}
}

class Provider<T> {
  Provider<R> select<R>(R Function(T) selector) => throw 0;
}

class Ref {
  T watch<T>(Provider<T> provider) => throw 0;
  T read<T>(Provider<T> provider) => throw 0;
}
''';
