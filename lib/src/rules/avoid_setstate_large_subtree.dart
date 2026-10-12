import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../utils.dart';

/// Flags `setState` in a State whose `build` method is large.
class AvoidSetStateLargeSubtree extends AnalysisRule {
  AvoidSetStateLargeSubtree({
    this.maxBuildLines = defaultMaxBuildLines,
    this.maxWidgetConstructors = defaultMaxWidgetConstructors,
  }) : super(
         name: 'avoid_setstate_large_subtree',
         description:
             'setState rebuilds the whole build() subtree; in a large build '
             'method, rebuild only the part that changes.',
       );

  /// Default threshold for the number of lines of `build`.
  static const int defaultMaxBuildLines = 60;

  /// Default threshold for the number of widget constructor calls in
  /// `build`.
  static const int defaultMaxWidgetConstructors = 25;

  static const LintCode code = LintCode(
    'avoid_setstate_large_subtree',
    'setState rebuilds the whole build() of this State ({0} lines, {1} '
        'widget constructors).',
    correctionMessage:
        'Hold the changing value in a ValueNotifier and rebuild only the '
        'affected part with ValueListenableBuilder (or extract a smaller '
        'StatefulWidget).',
  );

  /// `build` methods longer than this many lines are considered large.
  final int maxBuildLines;

  /// `build` methods with more widget constructor calls than this are
  /// considered large.
  final int maxWidgetConstructors;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AvoidSetStateLargeSubtree rule;

  /// Size of each `build` method, computed once per class.
  final Map<MethodDeclaration, ({int lines, int widgets})> _sizes = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'setState') return;
    final target = node.target;
    if (target != null && target is! ThisExpression) return;

    final owner = node.thisOrAncestorOfType<ClassDeclaration>();
    if (owner == null || !isStateClass(owner)) return;
    final build = _buildMethodOf(owner);
    if (build == null) return;

    final size = _sizes.putIfAbsent(build, () => _measure(build));
    if (size.lines > rule.maxBuildLines ||
        size.widgets > rule.maxWidgetConstructors) {
      rule.reportAtNode(node.methodName, arguments: [size.lines, size.widgets]);
    }
  }

  MethodDeclaration? _buildMethodOf(ClassDeclaration owner) {
    for (final member in owner.body.members) {
      if (member is MethodDeclaration && isBuildMethod(member)) return member;
    }
    return null;
  }

  ({int lines, int widgets}) _measure(MethodDeclaration build) {
    final unit = build.root as CompilationUnit;
    final body = build.body;
    final first = unit.lineInfo.getLocation(body.offset).lineNumber;
    final last = unit.lineInfo.getLocation(body.end).lineNumber;
    final counter = _WidgetCounter();
    body.accept(counter);
    return (lines: last - first + 1, widgets: counter.count);
  }
}

class _WidgetCounter extends RecursiveAstVisitor<void> {
  int count = 0;

  /// Non-widget value types commonly constructed inside build methods.
  static const Set<String> _valueTypes = {
    'EdgeInsets',
    'EdgeInsetsDirectional',
    'BorderRadius',
    'Radius',
    'BoxDecoration',
    'ShapeDecoration',
    'BoxShadow',
    'TextStyle',
    'Color',
    'Duration',
    'Offset',
    'Size',
    'BoxConstraints',
    'Border',
    'BorderSide',
    'RoundedRectangleBorder',
    'LinearGradient',
    'Key',
    'ValueKey',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _count(CtorCall.of(node));
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _count(CtorCall.of(node));
    super.visitMethodInvocation(node);
  }

  void _count(CtorCall? call) {
    if (call == null || _valueTypes.contains(call.typeName)) return;
    final node = call.node;
    if (node is InstanceCreationExpression &&
        !isTypeNamed(node.staticType, 'Widget', ifUnknown: true)) {
      return;
    }
    count++;
  }
}
