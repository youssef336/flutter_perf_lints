import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../utils.dart';

/// Flags expensive or blocking work done directly in `build`.
class AvoidHeavyWorkInBuild extends AnalysisRule {
  AvoidHeavyWorkInBuild()
    : super(
        name: 'avoid_heavy_work_in_build',
        description:
            'build() can run every frame; parsing, sorting, compiling regular '
            'expressions or blocking I/O there causes jank.',
      );

  static const LintCode code = LintCode(
    'avoid_heavy_work_in_build',
    "'{0}' runs on every rebuild of this widget.",
    correctionMessage:
        'Compute it once (initState, a field, a static final, or a provider) '
        'and read the result in build().',
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

/// Classes whose construction is expensive (pattern compilation, locale
/// data lookup).
const Set<String> _heavyTypes = {'RegExp', 'DateFormat', 'NumberFormat'};

/// Top-level functions that parse or serialise.
const Set<String> _heavyFunctions = {
  'jsonDecode',
  'jsonEncode',
  'base64Decode',
};

/// `json.decode(...)` style calls: target name -> methods.
const Map<String, Set<String>> _heavyStaticCalls = {
  'json': {'decode', 'encode'},
  'utf8': {'decode', 'encode'},
  'base64': {'decode', 'encode'},
};

/// Methods that are expensive on any receiver.
const Set<String> _heavyMethods = {
  'sort',
  'readAsStringSync',
  'readAsBytesSync',
  'readAsLinesSync',
  'writeAsStringSync',
  'writeAsBytesSync',
  'existsSync',
  'listSync',
  'statSync',
  'lengthSync',
};

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final call = CtorCall.of(node);
    if (call != null && _heavyTypes.contains(call.typeName)) {
      _reportCtor(call);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final call = CtorCall.of(node);
    if (call != null) {
      if (_heavyTypes.contains(call.typeName)) _reportCtor(call);
      return;
    }
    final name = node.methodName.name;
    final target = node.target;
    String? label;
    if (target == null && _heavyFunctions.contains(name)) {
      label = '$name()';
    } else if (target is SimpleIdentifier &&
        (_heavyStaticCalls[target.name]?.contains(name) ?? false)) {
      label = '${target.name}.$name()';
    } else if ((target != null || node.isCascaded) &&
        _heavyMethods.contains(name)) {
      label = '.$name()';
    }
    if (label == null || enclosingBuildMethod(node) == null) return;
    rule.reportAtOffset(
      node.methodName.offset,
      node.argumentList.end - node.methodName.offset,
      arguments: [label],
    );
  }

  void _reportCtor(CtorCall call) {
    final node = call.node;
    if (node is InstanceCreationExpression && node.isConst) return;
    if (enclosingBuildMethod(node) == null) return;
    final name = call.constructorName == null
        ? call.typeName
        : '${call.typeName}.${call.constructorName}';
    rule.reportAtOffset(
      call.headOffset,
      call.headEnd - call.headOffset,
      arguments: ['$name()'],
    );
  }
}
