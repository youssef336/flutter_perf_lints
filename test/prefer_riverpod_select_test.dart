import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_perf_lints/src/fixes/text_edit.dart';
import 'package:flutter_perf_lints/src/fixes/use_riverpod_select.dart';
import 'package:flutter_perf_lints/src/rules/prefer_riverpod_select.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'src/perf_rule_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferRiverpodSelectTest);
  });

  test('planSelectEdits rewrites the watch and the reads', () {
    const code = '''
void f(Ref ref) {
  final counter = ref.watch(counterProvider);
  print(counter.count);
  print(counter.count + 1);
}
''';
    final unit = parseString(content: code).unit;
    final finder = _WatchFinder();
    unit.accept(finder);
    final read = findSingleRead(finder.found!)!;
    expect(applyEdits(code, planSelectEdits(read)!), '''
void f(Ref ref) {
  final counter = ref.watch(counterProvider.select((v) => v.count));
  print(counter);
  print(counter + 1);
}
''');
  });
}

class _WatchFinder extends RecursiveAstVisitor<void> {
  MethodInvocation? found;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'watch') found ??= node;
    super.visitMethodInvocation(node);
  }
}

@reflectiveTest
class PreferRiverpodSelectTest extends PerfRuleTest {
  @override
  void setUp() {
    rule = PreferRiverpodSelect();
    super.setUp();
  }

  Future<void> test_singleProperty() async {
    const code = r'''
import 'package:stubs/stubs.dart';

void f(Ref ref, Provider<Counter> counterProvider) {
  final counter = ref.watch(counterProvider);
  print(counter.count);
  if (counter.count > 3) print('big');
}
''';
    await assertLintsAt(code, ['ref.watch(counterProvider)']);
  }

  Future<void> test_severalPropertiesOrWholeValue() async {
    await assertNoDiagnostics(r'''
import 'package:stubs/stubs.dart';

void use(Counter c) {}

void f(Ref ref, Provider<Counter> p) {
  final a = ref.watch(p);
  print(a.count);
  print(a.label);

  final b = ref.watch(p);
  use(b);

  final c = ref.watch(p);
  c.increment();

  final d = ref.watch(p.select((v) => v.count));
  print(d.isEven);

  final e = ref.read(p);
  print(e.count);
}
''');
  }
}
