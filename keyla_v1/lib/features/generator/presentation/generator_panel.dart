import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/password_generator.dart';

/// The reusable generator UI (big password display, length slider, toggles,
/// regenerate, copy, "Use this password") shared by the full-screen
/// Generator screen and the bottom-sheet variant opened from Add/Edit.
class GeneratorPanel extends StatefulWidget {
  const GeneratorPanel({super.key, this.onUse});

  /// If provided, shows a "Use this password" button that returns the value.
  final ValueChanged<String>? onUse;

  @override
  State<GeneratorPanel> createState() => _GeneratorPanelState();
}

class _GeneratorPanelState extends State<GeneratorPanel> {
  GeneratorOptions _options = const GeneratorOptions();
  bool _passphraseMode = false;
  late String _value = PasswordGenerator.generate(_options);

  void _regenerate() {
    setState(() {
      _value = _passphraseMode ? PasswordGenerator.generatePassphrase() : PasswordGenerator.generate(_options);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  _value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _regenerate,
                tooltip: 'Regenerate',
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined),
                color: AppColors.primary,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Random')),
            ButtonSegment(value: true, label: Text('Passphrase')),
          ],
          selected: {_passphraseMode},
          onSelectionChanged: (s) {
            setState(() => _passphraseMode = s.first);
            _regenerate();
          },
        ),
        const SizedBox(height: 16),
        if (!_passphraseMode) ...[
          Text('Length: ${_options.length}', style: Theme.of(context).textTheme.bodyMedium),
          Slider(
            value: _options.length.toDouble(),
            min: 8,
            max: 64,
            divisions: 56,
            onChanged: (v) {
              setState(() => _options = _options.copyWith(length: v.round()));
              _regenerate();
            },
          ),
          _ToggleRow(
            label: 'Uppercase (A-Z)',
            value: _options.useUppercase,
            onChanged: (v) {
              setState(() => _options = _options.copyWith(useUppercase: v));
              _regenerate();
            },
          ),
          _ToggleRow(
            label: 'Lowercase (a-z)',
            value: _options.useLowercase,
            onChanged: (v) {
              setState(() => _options = _options.copyWith(useLowercase: v));
              _regenerate();
            },
          ),
          _ToggleRow(
            label: 'Numbers (0-9)',
            value: _options.useNumbers,
            onChanged: (v) {
              setState(() => _options = _options.copyWith(useNumbers: v));
              _regenerate();
            },
          ),
          _ToggleRow(
            label: 'Symbols (!@#\$...)',
            value: _options.useSymbols,
            onChanged: (v) {
              setState(() => _options = _options.copyWith(useSymbols: v));
              _regenerate();
            },
          ),
          _ToggleRow(
            label: 'Avoid ambiguous characters (I, l, 1, O, 0)',
            value: _options.avoidAmbiguous,
            onChanged: (v) {
              setState(() => _options = _options.copyWith(avoidAmbiguous: v));
              _regenerate();
            },
          ),
        ],
        if (widget.onUse != null) ...[
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => widget.onUse!(_value),
            child: const Text('Use this password'),
          ),
        ],
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      value: value,
      onChanged: onChanged,
    );
  }
}
