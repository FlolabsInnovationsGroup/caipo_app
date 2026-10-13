import 'package:flutter/material.dart';

/// Shared widgets reserved for R04. Phase 5 screens are not built.
class PlaceholderPanel extends StatelessWidget {
  const PlaceholderPanel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}
