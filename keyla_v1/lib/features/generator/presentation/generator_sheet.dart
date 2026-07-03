import 'package:flutter/material.dart';

import 'generator_panel.dart';

/// Bottom-sheet variant of the generator, opened from the Add/Edit
/// credential form's "Generate" button (spec §9.5).
Future<String?> showGeneratorSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Generate a password', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            GeneratorPanel(onUse: (value) => Navigator.of(context).pop(value)),
          ],
        ),
      ),
    ),
  );
}
