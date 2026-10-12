import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../utils.dart';
import 'text_edit.dart';

/// Quick fix for `prefer_list_builder`: turns
/// `ListView(children: items.map((item) => W).toList())` into
/// `ListView.builder(itemCount: ..., itemBuilder: ...)`.
class ConvertToListBuilder extends ResolvedCorrectionProducer {
  ConvertToListBuilder({required super.context});

  static const FixKind _kind = FixKind(
    'flutter_perf_lints.fix.convertToListBuilder',
    DartFixKindPriority.standard,
    "Convert to 'ListView.builder'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    AstNode? current = node;
    while (current != null) {
      final call = CtorCall.of(current);
      if (call != null && call.typeName == 'ListView') {
        final edits = planListBuilderEdits(call);
        if (edits == null) return;
        await builder.addDartFileEdit(file, (builder) {
          for (final edit in edits) {
            builder.addSimpleReplacement(
              SourceRange(edit.offset, edit.length),
              edit.replacement,
            );
          }
        });
        return;
      }
      if (current is Statement || current is ClassMember) return;
      current = current.parent;
    }
  }
}

/// Computes the edits converting [call] (an unnamed `ListView` whose
/// `children:` is `source.map((x) => widget).toList()`) to
/// `ListView.builder`. Returns `null` when the shape is not supported.
List<TextEdit>? planListBuilderEdits(CtorCall call) {
  if (call.typeName != 'ListView' || call.constructorName != null) return null;
  final children = call.namedArgument('children');
  if (children == null) return null;

  final toList = children.argumentExpression.unParenthesized;
  if (toList is! MethodInvocation ||
      toList.methodName.name != 'toList' ||
      toList.argumentList.arguments.isNotEmpty) {
    return null;
  }
  final map = toList.target?.unParenthesized;
  if (map is! MethodInvocation || map.methodName.name != 'map') return null;
  final source = map.target;
  if (source == null || !_isStableReference(source)) return null;
  final arguments = map.argumentList.arguments;
  if (arguments.length != 1) return null;
  final mapper = arguments.single;
  if (mapper is! FunctionExpression) return null;
  final parameters = mapper.parameters?.parameters;
  if (parameters == null || parameters.length != 1) return null;
  final itemName = parameters.single.name?.lexeme;
  if (itemName == null) return null;
  final body = mapper.body;
  if (body is! ExpressionFunctionBody) return null;

  final sourceText = source.toSource();
  final isList = isTypeNamed(source.staticType, 'List', ifUnknown: false);
  final indexName = itemName == 'index' ? 'i' : 'index';
  final contextName = itemName == 'context' ? '_' : 'context';
  final element = isList
      ? '$sourceText[$indexName]'
      : '$sourceText.elementAt($indexName)';

  final node = call.node;
  final int typeEnd;
  if (node is InstanceCreationExpression) {
    typeEnd = node.constructorName.type.end;
  } else if (node is MethodInvocation) {
    typeEnd = node.methodName.end;
  } else {
    return null;
  }

  return [
    TextEdit.insert(typeEnd, '.builder'),
    TextEdit(
      children.offset,
      children.length,
      'itemCount: $sourceText.length, '
      'itemBuilder: ($contextName, $indexName) { '
      'final $itemName = $element; '
      'return ${body.expression.toSource()}; }',
    ),
  ];
}

/// Whether [e] can be evaluated repeatedly without side effects.
bool _isStableReference(Expression e) {
  if (e is SimpleIdentifier) return true;
  if (e is PrefixedIdentifier) return true;
  if (e is PropertyAccess) {
    final target = e.target;
    return target == null ||
        target is ThisExpression ||
        _isStableReference(target);
  }
  return false;
}
