import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../utils.dart';

/// Flags scrollables that build every child eagerly from a dynamic list.
class PreferListBuilder extends AnalysisRule {
  PreferListBuilder()
    : super(
        name: 'prefer_list_builder',
        description:
            'Lists whose length is only known at run time should be built '
            'lazily with a .builder constructor.',
      );

  static const LintCode code = LintCode(
    'prefer_list_builder',
    "'{0}' builds every child up front from a dynamic list, even the ones "
        'that are off screen.',
    correctionMessage:
        "Use '{1}' so children are built lazily as they scroll into view.",
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry.addInstanceCreationExpression(this, visitor);
    registry.addMethodInvocation(this, visitor);
  }
}

/// Scrollable constructors that take an eager `children:` list, mapped to
/// the lazy alternative.
const Map<String, String> _eagerScrollables = {
  'ListView': 'ListView.builder',
  'GridView': 'GridView.builder',
  'GridView.count': 'GridView.builder',
  'GridView.extent': 'GridView.builder',
};

const Set<String> _flexWidgets = {'Column', 'Row'};

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) =>
      _check(CtorCall.of(node));

  @override
  void visitMethodInvocation(MethodInvocation node) =>
      _check(CtorCall.of(node));

  void _check(CtorCall? call) {
    if (call == null) return;
    final name = call.constructorName == null
        ? call.typeName
        : '${call.typeName}.${call.constructorName}';

    final lazy = _eagerScrollables[name];
    if (lazy != null) {
      if (_hasDynamicChildren(call)) _report(call, name, lazy);
      return;
    }

    if (_flexWidgets.contains(name) &&
        _hasDynamicChildren(call) &&
        _isScrollViewChild(call.node)) {
      _report(call, 'SingleChildScrollView > $name', 'ListView.builder');
    }
  }

  bool _hasDynamicChildren(CtorCall call) {
    final children = call.namedArgument('children');
    return children != null && isDynamicLengthList(children.argumentExpression);
  }

  /// Whether [node] is the `child:` of a `SingleChildScrollView`.
  bool _isScrollViewChild(Expression node) {
    final named = node.parent;
    if (named is! NamedArgument || named.name.lexeme != 'child') {
      return false;
    }
    final outer = CtorCall.of(named.parent?.parent);
    return outer != null && outer.typeName == 'SingleChildScrollView';
  }

  void _report(CtorCall call, String name, String lazy) {
    rule.reportAtOffset(
      call.headOffset,
      call.headEnd - call.headOffset,
      arguments: [name, lazy],
    );
  }
}
