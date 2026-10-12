import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'animated_opacity.dart';
import 'counter_badge.dart';
import 'heavy_build.dart';
import 'images.dart';
import 'lists.dart';
import 'search_page.dart';
import 'settings_form.dart';

void main() => runApp(const ProviderScope(child: ExampleApp()));

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          children: const [
            SearchPage(),
            Avatar(url: 'https://example.com/a.png'),
            ContactList(names: ['Ada', 'Grace']),
            Pulse(),
            CounterBadge(),
            SettingsForm(),
            Receipt(json: '{"total": 3}'),
          ],
        ),
      ),
    );
  }
}
