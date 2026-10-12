import 'package:flutter_perf_lints/src/rules/avoid_animated_opacity_widget.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'src/perf_rule_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidAnimatedOpacityWidgetTest);
  });
}

@reflectiveTest
class AvoidAnimatedOpacityWidgetTest extends PerfRuleTest {
  @override
  void setUp() {
    rule = AvoidAnimatedOpacityWidget();
    super.setUp();
  }

  Future<void> test_animationValue() async {
    const code = r'''
import 'package:flutter/widgets.dart';

Widget f(AnimationController controller, Animation<double> fade) => Column(
  children: [
    Opacity(opacity: controller.value, child: const Text('a')),
    Opacity(opacity: 1 - fade.value, child: const Text('b')),
  ],
);
''';
    await assertLintsAt(code, ['Opacity', 'Opacity']);
  }

  Future<void> test_insideAnimatedBuilder() async {
    const code = r'''
import 'package:flutter/widgets.dart';

Widget f(Listenable l, double Function() read) => AnimatedBuilder(
  animation: l,
  builder: (context, child) => Opacity(opacity: read(), child: child),
);
''';
    await assertLintsAt(code, ['Opacity']);
  }

  Future<void> test_staticOrNonAnimation() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

Widget f(bool visible, ValueNotifier<double> n, Animation<double> a) => Column(
  children: [
    Opacity(opacity: 0.5, child: const Text('a')),
    Opacity(opacity: visible ? 1 : 0, child: const Text('b')),
    Opacity(opacity: n.value, child: const Text('c')),
    FadeTransition(opacity: a, child: const Text('d')),
  ],
);
''');
  }
}
