import 'dart:convert';

import 'package:flutter/material.dart';

/// avoid_heavy_work_in_build: parsing, regex compilation and sorting on
/// every rebuild.
class Receipt extends StatelessWidget {
  const Receipt({super.key, required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final digits = RegExp(r'\d+');
    final keys = data.keys.toList()..sort();
    return Text('${keys.first}: ${digits.hasMatch(json)}');
  }
}
