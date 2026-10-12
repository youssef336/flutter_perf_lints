import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../utils.dart';

/// Flags resources created by a `State` that are never released.
class UndisposedController extends AnalysisRule {
  UndisposedController()
    : super(
        name: 'undisposed_controller',
        description:
            'Controllers, focus nodes, subscriptions and timers created by a '
            'State must be released in dispose().',
      );

  static const LintCode code = LintCode(
    'undisposed_controller',
    "'{0}' ({1}) is created by this State but never released, which leaks "
        'memory and keeps listeners, tickers or timers alive.',
    correctionMessage: "Call '{0}.{2}()' in dispose().",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

/// Type name -> release method.
const Map<String, String> trackedResourceTypes = {
  'AnimationController': 'dispose',
  'TextEditingController': 'dispose',
  'ScrollController': 'dispose',
  'PageController': 'dispose',
  'TabController': 'dispose',
  'FocusNode': 'dispose',
  'FocusScopeNode': 'dispose',
  'ValueNotifier': 'dispose',
  'ChangeNotifier': 'dispose',
  'StreamSubscription': 'cancel',
  'Timer': 'cancel',
};

const Set<String> _releaseMethods = {'dispose', 'cancel', 'close'};

/// A resource field of a State that is never released.
class UndisposedField {
  UndisposedField(this.variable, this.typeName, this.releaseMethod);

  final VariableDeclaration variable;
  final String typeName;
  final String releaseMethod;

  String get name => variable.name.lexeme;

  /// Whether the field is declared nullable (`Timer? _timer`).
  bool get isNullable {
    final list = variable.parent;
    if (list is VariableDeclarationList) {
      final type = list.type;
      return type != null && type.question != null;
    }
    return false;
  }
}

/// Finds the resource fields of [node] that are created but never released.
List<UndisposedField> findUndisposedFields(ClassDeclaration node) {
  final body = node.body;
  final candidates = <String, UndisposedField>{};

  for (final member in body.members) {
    if (member is! FieldDeclaration || member.isStatic) continue;
    final list = member.fields;
    for (final variable in list.variables) {
      final typeName = _resourceTypeName(list.type, variable.initializer);
      if (typeName == null) continue;
      candidates[variable.name.lexeme] = UndisposedField(
        variable,
        typeName,
        trackedResourceTypes[typeName]!,
      );
    }
  }
  if (candidates.isEmpty) return const [];

  final scan = _ClassScan(candidates.keys.toSet());
  node.accept(scan);

  return [
    for (final field in candidates.values)
      if ((field.variable.initializer != null &&
              _isCreation(field.variable.initializer!)) ||
          scan.created.contains(field.name))
        if (!scan.released.contains(field.name)) field,
  ];
}

String? _resourceTypeName(TypeAnnotation? declared, Expression? initializer) {
  if (declared is NamedType) {
    final name = declared.name.lexeme;
    if (trackedResourceTypes.containsKey(name)) return name;
    return null;
  }
  if (declared == null && initializer != null) {
    final call = CtorCall.of(_stripCascade(initializer));
    if (call != null && trackedResourceTypes.containsKey(call.typeName)) {
      return call.typeName;
    }
    // Resolved code: `late final _sub = stream.listen(...)`.
    final type = initializer.staticType;
    if (type is InterfaceType) {
      final name = type.element.name;
      if (name != null && trackedResourceTypes.containsKey(name)) return name;
    }
  }
  return null;
}

Expression _stripCascade(Expression e) {
  final u = e.unParenthesized;
  return u is CascadeExpression ? u.target.unParenthesized : u;
}

/// Whether [value] creates a new object owned by this State, as opposed to
/// referencing one owned elsewhere (`widget.controller`, a parameter, ...).
bool _isCreation(Expression value) {
  final e = _stripCascade(value);
  return e is InstanceCreationExpression ||
      e is MethodInvocation ||
      e is FunctionExpressionInvocation;
}

String? _fieldName(Expression target) {
  final t = target.unParenthesized;
  if (t is SimpleIdentifier) return t.name;
  if (t is PropertyAccess && t.target is ThisExpression) {
    return t.propertyName.name;
  }
  return null;
}

class _ClassScan extends RecursiveAstVisitor<void> {
  _ClassScan(this.fields);

  final Set<String> fields;
  final Set<String> created = {};
  final Set<String> released = {};
  bool _inDispose = false;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasInDispose = _inDispose;
    _inDispose = node.name.lexeme == 'dispose';
    super.visitMethodDeclaration(node);
    _inDispose = wasInDispose;
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final name = _fieldName(node.leftHandSide);
    if (name != null &&
        fields.contains(name) &&
        _isCreation(node.rightHandSide)) {
      created.add(name);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_releaseMethods.contains(node.methodName.name)) {
      final target = node.realTarget;
      if (target != null) {
        final name = _fieldName(target);
        if (name != null && fields.contains(name)) released.add(name);
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Anything that hands the field to other code from dispose() (a loop
    // over a list of controllers, a helper method, ...) counts as released.
    if (_inDispose && fields.contains(node.name) && !_isReceiver(node)) {
      released.add(node.name);
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Whether [node] is the receiver of a member access (`node.foo`,
/// `node.foo()`), as opposed to being handed to other code.
bool _isReceiver(SimpleIdentifier node) {
  final parent = node.parent;
  if (parent is MethodInvocation) return parent.target == node;
  if (parent is PrefixedIdentifier) return parent.prefix == node;
  if (parent is PropertyAccess) return parent.target == node;
  if (parent is CascadeExpression) return parent.target == node;
  if (parent is AssignmentExpression) return parent.leftHandSide == node;
  return false;
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!isStateClass(node)) return;
    for (final field in findUndisposedFields(node)) {
      rule.reportAtToken(
        field.variable.name,
        arguments: [field.name, field.typeName, field.releaseMethod],
      );
    }
  }
}
