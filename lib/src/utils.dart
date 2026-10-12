import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

/// A constructor call, normalised across resolved and unresolved code.
///
/// When Flutter is resolved, `Image.network(...)` is an
/// [InstanceCreationExpression]. When the type cannot be resolved (missing
/// import, analysis without the Flutter SDK) the parser leaves it as a
/// [MethodInvocation]. Rules match on type *names*, so both shapes are folded
/// into this one view.
class CtorCall {
  CtorCall._(this.node, this.typeName, this.constructorName, this.arguments);

  /// The whole call expression.
  final Expression node;

  /// `Image` in `Image.network(...)`.
  final String typeName;

  /// `network` in `Image.network(...)`, or `null` for the unnamed constructor.
  final String? constructorName;

  /// The argument list of the call.
  final ArgumentList arguments;

  /// The offset where the reported "head" of the call starts.
  int get headOffset => node.offset;

  /// The end of the type and constructor name, for example the end of
  /// `Image.network` in `Image.network(url)`.
  int get headEnd => arguments.offset;

  /// Returns the call view of [node], or `null` if it is not a constructor
  /// call.
  static CtorCall? of(AstNode? node) {
    if (node is InstanceCreationExpression) {
      final ctor = node.constructorName;
      return CtorCall._(
        node,
        ctor.type.name.lexeme,
        ctor.name?.name,
        node.argumentList,
      );
    }
    if (node is MethodInvocation) {
      // Only unresolved shapes: a resolved constructor call is never a
      // MethodInvocation.
      final target = node.target;
      final method = node.methodName.name;
      if (target == null && node.operator == null && _isTypeLike(method)) {
        return CtorCall._(node, method, null, node.argumentList);
      }
      if (target is SimpleIdentifier &&
          node.operator?.lexeme == '.' &&
          _isTypeLike(target.name) &&
          !_isTypeLike(method)) {
        // `Image.network(...)` where `Image` did not resolve to a variable.
        if (target.element == null || node.methodName.element == null) {
          return CtorCall._(node, target.name, method, node.argumentList);
        }
      }
    }
    return null;
  }

  /// The named argument called [name], or `null`.
  NamedArgument? namedArgument(String name) {
    for (final argument in arguments.arguments) {
      if (argument is NamedArgument && argument.name.lexeme == name) {
        return argument;
      }
    }
    return null;
  }

  /// Whether a named argument called [name] is passed.
  bool hasNamedArgument(String name) => namedArgument(name) != null;
}

bool _isTypeLike(String name) {
  if (name.isEmpty) return false;
  final first = name.codeUnitAt(0);
  return first >= 0x41 && first <= 0x5A; // A-Z
}

/// Whether [type] is, or extends, a class called [name].
///
/// Returns [ifUnknown] when the type is not resolved, so rules keep working
/// syntactically when the Flutter SDK is not available.
bool isTypeNamed(DartType? type, String name, {required bool ifUnknown}) {
  if (type is! InterfaceType) return ifUnknown;
  if (type.element.name == name) return true;
  for (final supertype in type.element.allSupertypes) {
    if (supertype.element.name == name) return true;
  }
  return false;
}

/// Whether [node] is a class that extends `State<...>` (directly by name, or
/// through a resolved superclass chain).
bool isStateClass(ClassDeclaration node) {
  final superclass = node.extendsClause?.superclass;
  if (superclass == null) return false;
  if (superclass.name.lexeme == 'State') return true;
  return isTypeNamed(superclass.type, 'State', ifUnknown: false);
}

/// The `build(BuildContext)` method enclosing [node], if [node] is evaluated
/// while building (that is, not inside a callback such as `onPressed`).
MethodDeclaration? enclosingBuildMethod(AstNode node) {
  var current = node.parent;
  while (current != null) {
    if (current is FunctionExpression && _isEventCallback(current)) {
      return null;
    }
    if (current is MethodDeclaration) {
      return isBuildMethod(current) ? current : null;
    }
    if (current is FunctionDeclaration && current.parent is CompilationUnit) {
      return null;
    }
    if (current is ClassDeclaration) return null;
    current = current.parent;
  }
  return null;
}

/// Whether [node] is a `Widget build(BuildContext context)` method.
bool isBuildMethod(MethodDeclaration node) {
  if (node.name.lexeme != 'build' || node.isStatic || node.isGetter) {
    return false;
  }
  final parameters = node.parameters?.parameters;
  return parameters != null && parameters.length == 1;
}

/// Whether [function] is passed as a callback that runs later, in response to
/// an event (`onPressed:`, `onTap:`, `onChanged:`, ...), rather than during
/// the build.
bool _isEventCallback(FunctionExpression function) {
  final parent = function.parent;
  if (parent is NamedArgument) {
    final name = parent.name.lexeme;
    return name.length > 2 &&
        name.startsWith('on') &&
        _isTypeLike(name.substring(2));
  }
  if (parent is ArgumentList) {
    // `addPostFrameCallback((_) {...})`, `Future.microtask(() {...})`, ...
    final invocation = parent.parent;
    if (invocation is MethodInvocation) {
      const deferred = {
        'addPostFrameCallback',
        'addListener',
        'listen',
        'then',
        'microtask',
        'delayed',
        'run',
        'scheduleMicrotask',
      };
      return deferred.contains(invocation.methodName.name);
    }
  }
  return false;
}

/// Whether [expression] builds a list whose length is only known at run
/// time: `xs.map(...).toList()`, `List.generate(...)`, or a list literal
/// containing a collection-`for` or a spread of such an expression.
bool isDynamicLengthList(Expression expression) {
  final e = expression.unParenthesized;
  if (e is MethodInvocation) {
    final name = e.methodName.name;
    if (name == 'toList' && e.target != null) {
      return _isIterableTransform(e.target!);
    }
    if (name == 'generate' &&
        e.target is SimpleIdentifier &&
        (e.target! as SimpleIdentifier).name == 'List') {
      return true;
    }
    if (name == 'map' || name == 'expand' || name == 'where') {
      return true;
    }
  }
  if (e is InstanceCreationExpression) {
    final ctor = e.constructorName;
    return ctor.type.name.lexeme == 'List' && ctor.name?.name == 'generate';
  }
  if (e is ListLiteral) {
    for (final element in e.elements) {
      if (element is ForElement) return true;
      if (element is SpreadElement && isDynamicLengthList(element.expression)) {
        return true;
      }
    }
  }
  return false;
}

bool _isIterableTransform(Expression target) {
  final t = target.unParenthesized;
  if (t is MethodInvocation) {
    const transforms = {'map', 'expand', 'where', 'take', 'skip', 'mapIndexed'};
    return transforms.contains(t.methodName.name);
  }
  return false;
}
