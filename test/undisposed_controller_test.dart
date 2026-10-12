import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_perf_lints/src/fixes/add_dispose_call.dart';
import 'package:flutter_perf_lints/src/fixes/text_edit.dart';
import 'package:flutter_perf_lints/src/rules/undisposed_controller.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'src/perf_rule_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UndisposedControllerTest);
  });

  group('planDisposeEdit', () {
    String fix(String code) {
      final unit = parseString(content: code).unit;
      final owner = unit.declarations.whereType<ClassDeclaration>().last;
      final field = findUndisposedFields(owner).single;
      final edit = planDisposeEdit(owner, field, content: code)!;
      return applyEdits(code, [edit]);
    }

    test('inserts before super.dispose()', () {
      expect(
        fix('''
class S extends State {
  final c = TextEditingController();

  @override
  void dispose() {
    super.dispose();
  }
}
'''),
        '''
class S extends State {
  final c = TextEditingController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }
}
''',
      );
    });

    test('creates dispose() when missing, cancel for nullable timers', () {
      expect(
        fix('''
class S extends State {
  Timer? _t;

  void initState() {
    _t = Timer.periodic(d, (_) {});
  }
}
'''),
        '''
class S extends State {
  Timer? _t;

  void initState() {
    _t = Timer.periodic(d, (_) {});
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}
''',
      );
    });
  });
}

@reflectiveTest
class UndisposedControllerTest extends PerfRuleTest {
  @override
  void setUp() {
    rule = UndisposedController();
    super.setUp();
  }

  Future<void> test_initializer_notDisposed() async {
    const code = r'''
import 'package:flutter/widgets.dart';

class W extends StatefulWidget {
  @override
  State<W> createState() => _S();
}

class _S extends State<W> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''';
    await assertLintsAt(code, ['_text']);
  }

  Future<void> test_initState_notDisposed() async {
    const code = r'''
import 'package:flutter/widgets.dart';
import 'package:stubs/stubs.dart';

class W extends StatefulWidget {
  @override
  State<W> createState() => _S();
}

class _S extends State<W> with TickerProviderStateMixin<W> {
  late AnimationController _anim;
  Timer? _timer;
  late final StreamSubscription<int> _sub;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this);
    _timer = Timer.periodic(Duration.zero, (_) {});
    _sub = Stream<int>().listen((_) {});
    _focus = FocusNode()..addListener(() {});
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''';
    await assertLintsAt(code, ['_anim', '_timer', '_sub', '_focus']);
  }

  Future<void> test_onlyRemoveListenerInDispose() async {
    const code = r'''
import 'package:flutter/widgets.dart';

class W extends StatefulWidget {
  @override
  State<W> createState() => _S();
}

class _S extends State<W> {
  final _notifier = ValueNotifier<int>(0);

  void _onChange() {}

  @override
  void dispose() {
    _notifier.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''';
    await assertLintsAt(code, ['_notifier']);
  }

  Future<void> test_allReleased() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:stubs/stubs.dart';

class W extends StatefulWidget {
  @override
  State<W> createState() => _S();
}

class _S extends State<W> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  late final PageController _page;
  Timer? _timer;
  late final StreamSubscription<int> _sub;

  @override
  void initState() {
    super.initState();
    _page = PageController();
    _timer = Timer(Duration.zero, () {});
    _sub = Stream<int>().listen((_) {});
  }

  void _release() {
    _sub.cancel();
  }

  @override
  void dispose() {
    for (final c in [_a, _b]) {
      c.dispose();
    }
    this._page.dispose();
    _timer?.cancel();
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''');
  }

  Future<void> test_controllerOwnedByParent() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

class W extends StatefulWidget {
  W(this.controller);
  final ScrollController controller;

  @override
  State<W> createState() => _S();
}

class _S extends State<W> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''');
  }

  Future<void> test_notAState() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

class Model {
  final controller = TextEditingController();
}
''');
  }
}
