import 'package:flutter/material.dart';

/// avoid_setstate_large_subtree: toggling one switch rebuilds the whole form.
class SettingsForm extends StatefulWidget {
  const SettingsForm({super.key});

  @override
  State<SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<SettingsForm> {
  final List<bool> _values = List.filled(14, false);

  void _toggle(int index, bool value) {
    setState(() => _values[index] = value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Option 0'),
            value: _values[0],
            onChanged: (v) => _toggle(0, v),
          ),
          SwitchListTile(
            title: const Text('Option 1'),
            value: _values[1],
            onChanged: (v) => _toggle(1, v),
          ),
          SwitchListTile(
            title: const Text('Option 2'),
            value: _values[2],
            onChanged: (v) => _toggle(2, v),
          ),
          SwitchListTile(
            title: const Text('Option 3'),
            value: _values[3],
            onChanged: (v) => _toggle(3, v),
          ),
          SwitchListTile(
            title: const Text('Option 4'),
            value: _values[4],
            onChanged: (v) => _toggle(4, v),
          ),
          SwitchListTile(
            title: const Text('Option 5'),
            value: _values[5],
            onChanged: (v) => _toggle(5, v),
          ),
          SwitchListTile(
            title: const Text('Option 6'),
            value: _values[6],
            onChanged: (v) => _toggle(6, v),
          ),
          SwitchListTile(
            title: const Text('Option 7'),
            value: _values[7],
            onChanged: (v) => _toggle(7, v),
          ),
          SwitchListTile(
            title: const Text('Option 8'),
            value: _values[8],
            onChanged: (v) => _toggle(8, v),
          ),
          SwitchListTile(
            title: const Text('Option 9'),
            value: _values[9],
            onChanged: (v) => _toggle(9, v),
          ),
          SwitchListTile(
            title: const Text('Option 10'),
            value: _values[10],
            onChanged: (v) => _toggle(10, v),
          ),
          SwitchListTile(
            title: const Text('Option 11'),
            value: _values[11],
            onChanged: (v) => _toggle(11, v),
          ),
          SwitchListTile(
            title: const Text('Option 12'),
            value: _values[12],
            onChanged: (v) => _toggle(12, v),
          ),
          SwitchListTile(
            title: const Text('Option 13'),
            value: _values[13],
            onChanged: (v) => _toggle(13, v),
          ),
        ],
      ),
    );
  }
}
