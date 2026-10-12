import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_perf_lints/src/fixes/convert_to_list_builder.dart';
import 'package:flutter_perf_lints/src/fixes/text_edit.dart';
import 'package:flutter_perf_lints/src/rules/prefer_list_builder.dart';
import 'package:flutter_perf_lints/src/utils.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'src/perf_rule_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferListBuilderTest);
  });

  group('planListBuilderEdits', () {
    String? fix(String code) {
      final unit = parseString(content: code).unit;
      final finder = _ListViewFinder();
      unit.accept(finder);
      final edits = planListBuilderEdits(CtorCall.of(finder.found)!);
      return edits == null ? null : applyEdits(code, edits);
    }

    test('converts map().toList() to ListView.builder', () {
      expect(
        fix(
          'Widget f(List<String> items) => '
          'ListView(children: items.map((s) => Text(s)).toList());',
        ),
        'Widget f(List<String> items) => ListView.builder(itemCount: '
        'items.length, itemBuilder: (context, index) { final s = '
        'items.elementAt(index); return Text(s); });',
      );
    });

    test('leaves unsupported shapes alone', () {
      expect(
        fix(
          'Widget f(List<String> items) => '
          'ListView(children: [for (final s in items) Text(s)]);',
        ),
        isNull,
      );
    });
  });
}

class _ListViewFinder extends RecursiveAstVisitor<void> {
  AstNode? found;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'ListView') found ??= node;
    super.visitMethodInvocation(node);
  }
}

@reflectiveTest
class PreferListBuilderTest extends PerfRuleTest {
  @override
  void setUp() {
    rule = PreferListBuilder();
    super.setUp();
  }

  Future<void> test_listView_mapToList() async {
    const code = r'''
import 'package:flutter/widgets.dart';

Widget f(List<String> items) =>
    ListView(children: items.map((s) => Text(s)).toList());
''';
    await assertLintsAt(code, ['ListView']);
  }

  Future<void> test_gridView_generate_and_collectionFor() async {
    const code = r'''
import 'package:flutter/widgets.dart';

List<Widget> f(List<String> items) => [
  GridView(gridDelegate: 0, children: List.generate(99, (i) => Text('$i'))),
  GridView.count(crossAxisCount: 2, children: [for (final s in items) Text(s)]),
];
''';
    await assertLintsAt(code, ['GridView', 'GridView.count']);
  }

  Future<void> test_columnInSingleChildScrollView() async {
    const code = r'''
import 'package:flutter/widgets.dart';

Widget f(List<String> items) => SingleChildScrollView(
  child: Column(children: [...items.map((s) => Text(s))]),
);
''';
    await assertLintsAt(code, ['Column']);
  }

  Future<void> test_staticChildren() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

List<Widget> f(List<String> items) => [
  ListView(children: const [Text('a'), Text('b')]),
  ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, i) => Text(items[i]),
  ),
  Column(children: items.map((s) => Text(s)).toList()),
  SingleChildScrollView(child: Column(children: const [Text('a')])),
];
''');
  }
}
