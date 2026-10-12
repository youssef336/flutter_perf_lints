import 'package:flutter_perf_lints/src/rules/avoid_heavy_work_in_build.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'src/perf_rule_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidHeavyWorkInBuildTest);
  });
}

@reflectiveTest
class AvoidHeavyWorkInBuildTest extends PerfRuleTest {
  @override
  void setUp() {
    rule = AvoidHeavyWorkInBuild();
    super.setUp();
  }

  Future<void> test_heavyCallsInBuild() async {
    const code = r'''
import 'package:flutter/widgets.dart';
import 'package:stubs/stubs.dart';

class W extends StatelessWidget {
  W(this.raw, this.items);
  final String raw;
  final Items items;

  @override
  Widget build(BuildContext context) {
    final data = jsonDecode(raw);
    final re = RegExp(r'\d+');
    items.sort();
    final date = DateFormat.yMd().format(DateTime.now());
    final text = File('a.txt').readAsStringSync();
    return Text('$data $re $date $text');
  }
}
''';
    await assertLintsAt(code, [
      'jsonDecode(raw)',
      'RegExp',
      'sort()',
      'DateFormat.yMd',
      'readAsStringSync()',
    ]);
  }

  Future<void> test_insideItemBuilder() async {
    const code = r'''
import 'package:flutter/widgets.dart';
import 'package:stubs/stubs.dart';

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.builder(
    itemBuilder: (context, i) => Text(DateFormat().format(DateTime.now())),
  );
}
''';
    await assertLintsAt(code, ['DateFormat']);
  }

  Future<void> test_outsideBuildOrInCallbacks() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:stubs/stubs.dart';

final _re = RegExp(r'\d+');

class W extends StatelessWidget {
  W(this.items);
  final Items items;

  static final _format = DateFormat('y');

  Object parse(String raw) => jsonDecode(raw);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        items.sort();
        jsonDecode('{}');
      },
      child: Text('$_re ${_format.format(DateTime.now())}'),
    );
  }
}
''');
  }
}
