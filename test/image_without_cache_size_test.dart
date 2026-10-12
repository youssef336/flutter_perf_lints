import 'package:flutter_perf_lints/src/rules/image_without_cache_size.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'src/perf_rule_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ImageWithoutCacheSizeTest);
  });
}

@reflectiveTest
class ImageWithoutCacheSizeTest extends PerfRuleTest {
  @override
  void setUp() {
    rule = ImageWithoutCacheSize();
    super.setUp();
  }

  Future<void> test_imageConstructors_withoutCacheSize() async {
    const code = r'''
import 'package:flutter/widgets.dart';

List<Widget> f(Object file) => [
  Image.network('https://x/y.png', width: 40),
  Image.asset('assets/a.png'),
  Image.file(file),
];
''';
    await assertLintsAt(code, ['Image.network', 'Image.asset', 'Image.file']);
  }

  Future<void> test_networkImage_notResized() async {
    const code = r'''
import 'package:flutter/widgets.dart';

Widget f() => Image(image: NetworkImage('https://x/y.png'));
''';
    await assertLintsAt(code, ['NetworkImage']);
  }

  Future<void> test_withCacheSize() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

List<Widget> f(Object file) => [
  Image.network('https://x/y.png', cacheWidth: 120),
  Image.asset('assets/a.png', cacheHeight: 64),
  Image.file(file, cacheWidth: 10, cacheHeight: 10),
];
''');
  }

  Future<void> test_networkImage_resized() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

List<ImageProvider<Object>> f() => [
  ResizeImage(NetworkImage('https://x/a.png'), width: 100),
  ResizeImage.resizeIfNeeded(100, null, NetworkImage('https://x/b.png')),
];
''');
  }
}
