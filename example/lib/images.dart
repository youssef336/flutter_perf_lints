import 'package:flutter/material.dart';

/// image_without_cache_size: a 4000px photo decoded to show a 48px avatar.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.network(url, width: 48, height: 48),
        CircleAvatar(backgroundImage: NetworkImage(url)),
      ],
    );
  }
}
