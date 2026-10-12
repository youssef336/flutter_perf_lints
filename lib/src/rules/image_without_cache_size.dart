import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../utils.dart';

/// Flags images that are decoded at full resolution.
class ImageWithoutCacheSize extends AnalysisRule {
  ImageWithoutCacheSize()
    : super(
        name: 'image_without_cache_size',
        description:
            'Images should be decoded at the size they are displayed, using '
            'cacheWidth / cacheHeight or ResizeImage.',
      );

  static const LintCode code = LintCode(
    'image_without_cache_size',
    "'{0}' decodes the image at full resolution, which wastes memory and "
        'raster-thread time when it is displayed smaller.',
    correctionMessage: '{1}',
  );

  static const String _imageCorrection =
      'Pass cacheWidth and/or cacheHeight (display size x devicePixelRatio).';

  static const String _providerCorrection =
      'Wrap the provider in ResizeImage(..., width: ..., height: ...).';

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

const Set<String> _imageConstructors = {'network', 'asset', 'file', 'memory'};

const Set<String> _providerTypes = {'NetworkImage', 'FileImage', 'MemoryImage'};

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
    if (call.typeName == 'Image' &&
        _imageConstructors.contains(call.constructorName)) {
      if (call.hasNamedArgument('cacheWidth') ||
          call.hasNamedArgument('cacheHeight')) {
        return;
      }
      _report(call, ImageWithoutCacheSize._imageCorrection);
      return;
    }
    if (_providerTypes.contains(call.typeName) &&
        call.constructorName == null &&
        !_isWrappedInResize(call.node)) {
      _report(call, ImageWithoutCacheSize._providerCorrection);
    }
  }

  void _report(CtorCall call, String correction) {
    final name = call.constructorName == null
        ? call.typeName
        : '${call.typeName}.${call.constructorName}';
    rule.reportAtOffset(
      call.headOffset,
      call.headEnd - call.headOffset,
      arguments: [name, correction],
    );
  }

  /// `ResizeImage(NetworkImage(url), ...)` or
  /// `ResizeImage.resizeIfNeeded(w, h, NetworkImage(url))`.
  bool _isWrappedInResize(Expression node) {
    var parent = node.parent;
    if (parent is NamedArgument) parent = parent.parent;
    if (parent is! ArgumentList) return false;
    final outer = CtorCall.of(parent.parent);
    if (outer != null && outer.typeName == 'ResizeImage') return true;
    final invocation = parent.parent;
    return invocation is MethodInvocation &&
        invocation.methodName.name == 'resizeIfNeeded';
  }
}
