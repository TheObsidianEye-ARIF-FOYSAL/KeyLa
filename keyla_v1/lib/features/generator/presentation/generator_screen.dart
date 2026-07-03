import 'package:flutter/material.dart';

import 'generator_panel.dart';

class GeneratorScreen extends StatelessWidget {
  const GeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password generator')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: GeneratorPanel(),
      ),
    );
  }
}
