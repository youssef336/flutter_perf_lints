import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../rules/undisposed_controller.dart';
import 'text_edit.dart';

/// Quick fix for `undisposed_controller`: releases the field in dispose(),
/// creating the method if needed.
class AddDisposeCall extends ResolvedCorrectionProducer {
  AddDisposeCall({required super.context});

  static const FixKind _kind = FixKind(
    'flutter_perf_lints.fix.addDisposeCall',
    DartFixKindPriority.standard,
    "Release '{0}' in dispose()",
  );

  String _name = '';

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_name];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final variable = node.thisOrAncestorOfType<VariableDeclaration>();
    final owner = variable?.thisOrAncestorOfType<ClassDeclaration>();
    if (variable == null || owner == null) return;
    final field = findUndisposedFields(
      owner,
    ).where((f) => f.variable == variable).firstOrNull;
    if (field == null) return;
    _name = field.name;

    final edit = planDisposeEdit(
      owner,
      field,
      content: unitResult.content,
      indent: utils.oneIndent,
      eol: defaultEol,
    );
    if (edit == null) return;
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(edit.offset, edit.length),
        edit.replacement,
      );
    });
  }
}

/// Computes the edit that releases [field] in the `dispose()` of [owner].
TextEdit? planDisposeEdit(
  ClassDeclaration owner,
  UndisposedField field, {
  required String content,
  String indent = '  ',
  String eol = '\n',
}) {
  final call =
      '${field.name}${field.isNullable ? '?' : ''}.${field.releaseMethod}();';

  MethodDeclaration? dispose;
  for (final member in owner.body.members) {
    if (member is MethodDeclaration &&
        member.name.lexeme == 'dispose' &&
        !member.isStatic) {
      dispose = member;
    }
  }

  if (dispose != null) {
    final body = dispose.body;
    if (body is! BlockFunctionBody) return null;
    final block = body.block;
    for (final statement in block.statements) {
      if (_isSuperDispose(statement)) {
        final prefix = linePrefix(content, statement.offset);
        return TextEdit.insert(statement.offset, '$call$eol$prefix');
      }
    }
    final prefix = linePrefix(content, dispose.offset) + indent;
    return TextEdit.insert(block.leftBracket.end, '$eol$prefix$call');
  }

  final members = owner.body.members;
  if (members.isEmpty) return null;
  final anchor = members.last;
  final prefix = linePrefix(content, anchor.offset);
  final inner = '$prefix$indent';
  return TextEdit.insert(
    anchor.end,
    '$eol$eol$prefix@override$eol'
    '${prefix}void dispose() {$eol'
    '$inner$call$eol'
    '${inner}super.dispose();$eol'
    '$prefix}',
  );
}

bool _isSuperDispose(Statement statement) {
  if (statement is! ExpressionStatement) return false;
  final e = statement.expression;
  return e is MethodInvocation &&
      e.target is SuperExpression &&
      e.methodName.name == 'dispose';
}
