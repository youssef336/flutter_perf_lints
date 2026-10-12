import 'package:flutter/material.dart';

/// prefer_list_builder: every row is built up front, even off screen.
class ContactList extends StatelessWidget {
  const ContactList({super.key, required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: ListView(
            children: names.map((name) => ListTile(title: Text(name))).toList(),
          ),
        ),
        SingleChildScrollView(
          child: Column(children: [for (final name in names) Text(name)]),
        ),
      ],
    );
  }
}
