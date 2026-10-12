import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Flags `ref.watch(p)` results of which only one property is ever read.
class PreferRiverpodSelect extends AnalysisRule {
  PreferRiverpodSelect()
    : super(
        name: 'prefer_riverpod_select',
        description:
            'When only one property of a watched provider is used, watch '
            'just that property with select().',
      );

  static const LintCode code = LintCode(
    'prefer_riverpod_select',
    "Only '{1}' of the watched value is read, but '{0}' rebuilds on every "
        'change of the whole value.',
    correctionMessage:
        'Watch just that property: ref.watch({0}.select((v) => v.{1})).',
  );

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

/// The result of analysing one `final x = ref.watch(p);` declaration.
class SingleRead {
  SingleRead(this.watch, this.variable, this.property, this.reads);

  /// The `ref.watch(p)` invocation.
  final MethodInvocation watch;

  /// The variable the watched value is stored in.
  final VariableDeclaration variable;

  /// The only property read from [variable].
  final String property;

  /// Every `x.property` expression (a [PrefixedIdentifier] or
  /// [PropertyAccess]).
  final List<Expression> reads;

  /// The provider expression passed to `watch`.
  Expression get provider => watch.argumentList.arguments.first as Expression;
}

/// Returns the single-property usage of [node], or `null` if [node] is not a
/// `ref.watch(p)` stored in a local variable that is only read through one
/// property.
SingleRead? findSingleRead(MethodInvocation node) {
  if (node.methodName.name != 'watch') return null;
  final target = node.target;
  if (target is! SimpleIdentifier || target.name != 'ref') return null;
  final arguments = node.argumentList.arguments;
  if (arguments.length != 1 || arguments.first is NamedArgument) {
    return null;
  }
  final provider = arguments.first;
  if (provider is! Expression) return null;
  if (provider is MethodInvocation && provider.methodName.name == 'select') {
    return null;
  }

  final variable = node.parent;
  if (variable is! VariableDeclaration || variable.initializer != node) {
    return null;
  }
  final statement = variable.parent?.parent;
  if (statement is! VariableDeclarationStatement) return null;
  final block = statement.parent;
  if (block is! Block) return null;

  final name = variable.name.lexeme;
  final collector = _ReferenceCollector(name, variable);
  final index = block.statements.indexOf(statement);
  for (final s in block.statements.skip(index + 1)) {
    s.accept(collector);
  }
  if (collector.escaped || collector.reads.isEmpty) return null;
  final properties = collector.reads.map(_propertyOf).toSet();
  if (properties.length != 1) return null;
  final property = properties.single;
  if (property == 'hashCode' || property == 'runtimeType') return null;
  return SingleRead(node, variable, property, collector.reads);
}

String _propertyOf(Expression read) => read is PrefixedIdentifier
    ? read.identifier.name
    : (read as PropertyAccess).propertyName.name;

class _ReferenceCollector extends RecursiveAstVisitor<void> {
  _ReferenceCollector(this.name, this.declaration);

  final String name;
  final VariableDeclaration declaration;
  final List<Expression> reads = [];
  bool escaped = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name != name) return;
    // Resolved code: make sure it is our variable, not a shadowing one.
    final element = node.element;
    final declared = declaration.declaredFragment?.element;
    if (element != null && declared != null && element != declared) return;

    final parent = node.parent;
    if (parent is PrefixedIdentifier && parent.prefix == node) {
      if (_isPlainRead(parent)) {
        reads.add(parent);
        return;
      }
    } else if (parent is PropertyAccess &&
        parent.target == node &&
        !parent.isNullAware) {
      if (_isPlainRead(parent)) {
        reads.add(parent);
        return;
      }
    }
    // Passed somewhere, called, compared, assigned... the whole value
    // matters.
    escaped = true;
  }

  /// Whether [read] is a value read, not the target of an assignment or a
  /// method call (`x.items.add(...)` still only reads `items`, so it counts).
  bool _isPlainRead(Expression read) {
    final parent = read.parent;
    if (parent is AssignmentExpression && parent.leftHandSide == read) {
      return false;
    }
    if (parent is PostfixExpression || parent is PrefixExpression) {
      final operator = parent is PostfixExpression
          ? parent.operator.lexeme
          : (parent as PrefixExpression).operator.lexeme;
      if (operator == '++' || operator == '--') return false;
    }
    return true;
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final read = findSingleRead(node);
    if (read == null) return;
    rule.reportAtNode(
      node,
      arguments: [read.provider.toSource(), read.property],
    );
  }
}
