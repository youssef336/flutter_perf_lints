import 'dart:async';

import 'package:flutter/material.dart';

/// undisposed_controller: the text controller and the timer are never
/// released (only the scroll controller is).
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _debounce = Timer(const Duration(milliseconds: 300), () {});
  }

  bool get _isTyping => _debounce?.isActive ?? false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _query,
      scrollController: _scroll,
      readOnly: _isTyping,
    );
  }
}
