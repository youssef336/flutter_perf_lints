import 'package:flutter_perf_lints/src/rules/avoid_setstate_large_subtree.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'src/perf_rule_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidSetStateLargeSubtreeTest);
  });
}

String _stateWith(String buildBody) =>
    '''
import 'package:flutter/widgets.dart';

class W extends StatefulWidget {
  @override
  State<W> createState() => _S();
}

class _S extends State<W> {
  int _n = 0;

  void _tap() {
    setState(() => _n++);
  }

  @override
  Widget build(BuildContext context) {
$buildBody
  }
}
''';

@reflectiveTest
class AvoidSetStateLargeSubtreeTest extends PerfRuleTest {
  @override
  void setUp() {
    rule = AvoidSetStateLargeSubtree(
      maxBuildLines: 20,
      maxWidgetConstructors: 6,
    );
    super.setUp();
  }

  Future<void> test_tooManyWidgets() async {
    final code = _stateWith('''
    return Column(children: [
      Text('\$_n'),
      const Text('a'),
      const Text('b'),
      const Text('c'),
      const Text('d'),
      const SizedBox(),
      GestureDetector(onTap: _tap),
    ]);''');
    await assertLintsAt(code, ['setState']);
  }

  Future<void> test_tooManyLines() async {
    final lines = List.filled(25, '    // layout').join('\n');
    final code = _stateWith('$lines\n    return Text(\'\$_n\');');
    await assertLintsAt(code, ['setState']);
  }

  Future<void> test_smallBuild() async {
    await assertNoDiagnostics(
      _stateWith('''
    return GestureDetector(
      onTap: _tap,
      child: Padding(padding: const EdgeInsets.all(8), child: Text('\$_n')),
    );'''),
    );
  }

  Future<void> test_defaultThresholds() async {
    rule = AvoidSetStateLargeSubtree();
    await assertNoDiagnostics(_stateWith("    return Text('\$_n');"));
  }
}
