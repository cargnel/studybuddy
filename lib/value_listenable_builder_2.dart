import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> valueListenable1;
  final ValueListenable<B> valueListenable2;
  final Widget Function(BuildContext context, A value1, B value2, Widget? child) builder;
  final Widget? child;

  const ValueListenableBuilder2({
    super.key,
    required this.valueListenable1,
    required this.valueListenable2,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: valueListenable1,
      builder: (context, value1, _) {
        return ValueListenableBuilder<B>(
          valueListenable: valueListenable2,
          builder: (context, value2, _) {
            return builder(context, value1, value2, child);
          },
        );
      },
    );
  }
}