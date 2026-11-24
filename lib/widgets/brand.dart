import 'package:flutter/material.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Image.asset('assets/logo.png', height: 30, color: cs.onSurface),
      const SizedBox(width: 8),
      const Text('PenTube', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
    ]);
  }
}
