import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../utils.dart';

/// Flags `Opacity` widgets driven by an animation.
class AvoidAnimatedOpacityWidget extends AnalysisRule {
  AvoidAnimatedOpacityWidget()
    : super(
        name: 'avoid_animated_opacity_widget',
        description:
            'Animating an Opacity widget rebuilds and re-composites its '
            'subtree every frame; FadeTransition does not rebuild.',
      );

  static const LintCode code = LintCode(
    'avoid_animated_opacity_widget',
    'This Opacity is driven by an animation, so its subtree is rebuilt and '
        'composited into an offscreen layer on every frame.',
    correctionMessage:
        'Use FadeTransition(opacity: animation, child: ...) instead.',
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
    if (call == null ||
        call.typeName != 'Opacity' ||
        call.constructorName != null) {
      return;
    }
    final opacity = call.namedArgument('opacity')?.argumentExpression;
    if (opacity == null || _isConstant(opacity)) return;

    if (_readsAnimationValue(opacity) || _isInAnimatedBuilder(call.node)) {
      rule.reportAtOffset(call.headOffset, call.headEnd - call.headOffset);
    }
  }

  bool _isConstant(Expression e) {
    final u = e.unParenthesized;
    return u is DoubleLiteral || u is IntegerLiteral;
  }

  /// Whether [expression] reads `<animation>.value`.
  bool _readsAnimationValue(Expression expression) {
    final finder = _ValueReadFinder();
    expression.accept(finder);
    return finder.found;
  }

  /// Whether [node] sits inside the `builder:` of an `AnimatedBuilder`.
  bool _isInAnimatedBuilder(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        final named = current.parent;
        if (named is NamedArgument && named.name.lexeme == 'builder') {
          final outer = CtorCall.of(named.parent?.parent);
          if (outer != null &&
              (outer.typeName == 'AnimatedBuilder' ||
                  outer.typeName == 'ListenableBuilder')) {
            return true;
          }
        }
      }
      if (current is ClassMember || current is CompilationUnitMember) break;
      current = current.parent;
    }
    return false;
  }
}

class _ValueReadFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'value' && _isAnimation(node.prefix)) {
      found = true;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (node.propertyName.name == 'value' &&
        target != null &&
        _isAnimation(target)) {
      found = true;
    }
    super.visitPropertyAccess(node);
  }

  /// Unresolved receivers are assumed to be animations; resolved ones must
  /// be an `Animation` (which `AnimationController` implements).
  bool _isAnimation(Expression receiver) =>
      isTypeNamed(receiver.staticType, 'Animation', ifUnknown: true);
}
