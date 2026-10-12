import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Cart {
  const Cart({this.count = 0, this.total = 0});

  final int count;
  final double total;
}

class CartNotifier extends Notifier<Cart> {
  @override
  Cart build() => const Cart();
}

final cartProvider = NotifierProvider<CartNotifier, Cart>(CartNotifier.new);

/// prefer_riverpod_select: rebuilds when `total` changes although only
/// `count` is shown.
class CounterBadge extends ConsumerWidget {
  const CounterBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Badge(label: Text('${cart.count}'));
  }
}
