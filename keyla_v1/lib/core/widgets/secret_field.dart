import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// A masked text field with a reveal toggle, per spec §8.3 and the
/// accessibility requirement that masked fields announce
/// "password, hidden, double-tap to reveal".
class SecretField extends StatefulWidget {
  const SecretField({
    super.key,
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      value: _revealed ? 'visible' : 'hidden',
      hint: 'double-tap the eye icon to ${_revealed ? 'hide' : 'reveal'}',
      child: TextField(
        controller: widget.controller,
        obscureText: !_revealed,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        textInputAction: widget.textInputAction,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: IconButton(
            icon: Icon(_revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            tooltip: _revealed ? 'Hide' : 'Reveal',
            onPressed: () => setState(() => _revealed = !_revealed),
          ),
        ),
      ),
    );
  }
}
