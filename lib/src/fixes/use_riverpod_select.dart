import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../rules/prefer_riverpod_select.dart';
import 'text_edit.dart';

/// Quick fix for `prefer_riverpod_select`: watches only the property that is
/// read.
class UseRiverpodSelect extends ResolvedCorrectionProducer {
  UseRiverpodSelect({required super.context});

  static const FixKind _kind = FixKind(
    'flutter_perf_lints.fix.useRiverpodSelect',
    DartFixKindPriority.standard,
    "Watch only '{0}' with select()",
  );

  String _property = '';

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_property];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final watch = node is MethodInvocation
        ? node as MethodInvocation
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (watch == null) return;
    final read = findSingleRead(watch);
    if (read == null) return;
    final edits = planSelectEdits(read);
    if (edits == null) return;
    _property = read.property;
    await builder.addDartFileEdit(file, (builder) {
      for (final edit in edits) {
        builder.addSimpleReplacement(
          SourceRange(edit.offset, edit.length),
          edit.replacement,
        );
      }
    });
  }
}

/// Computes the edits turning `final s = ref.watch(p); ... s.count` into
/// `final s = ref.watch(p.select((v) => v.count)); ... s`.
List<TextEdit>? planSelectEdits(SingleRead read) {
  final provider = read.provider;
  final needsParens =
      provider is! Identifier &&
      provider is! PropertyAccess &&
      provider is! MethodInvocation &&
      provider is! FunctionExpressionInvocation &&
      provider is! IndexExpression;
  final source = needsParens ? '(${provider.toSource()})' : provider.toSource();
  final name = read.variable.name.lexeme;
  return [
    TextEdit(
      provider.offset,
      provider.length,
      '$source.select((v) => v.${read.property})',
    ),
    for (final r in read.reads) TextEdit(r.offset, r.length, name),
  ];
}
