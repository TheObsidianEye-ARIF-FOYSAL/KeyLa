import 'dart:math';

class GeneratorOptions {
  const GeneratorOptions({
    this.length = 20,
    this.useUppercase = true,
    this.useLowercase = true,
    this.useNumbers = true,
    this.useSymbols = true,
    this.avoidAmbiguous = true,
  });

  final int length;
  final bool useUppercase;
  final bool useLowercase;
  final bool useNumbers;
  final bool useSymbols;
  final bool avoidAmbiguous;

  GeneratorOptions copyWith({
    int? length,
    bool? useUppercase,
    bool? useLowercase,
    bool? useNumbers,
    bool? useSymbols,
    bool? avoidAmbiguous,
  }) {
    return GeneratorOptions(
      length: length ?? this.length,
      useUppercase: useUppercase ?? this.useUppercase,
      useLowercase: useLowercase ?? this.useLowercase,
      useNumbers: useNumbers ?? this.useNumbers,
      useSymbols: useSymbols ?? this.useSymbols,
      avoidAmbiguous: avoidAmbiguous ?? this.avoidAmbiguous,
    );
  }
}

const _ambiguous = 'Il1O0';
const _lower = 'abcdefghijklmnopqrstuvwxyz';
const _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _numbers = '0123456789';
const _symbols = r'!@#$%^&*()-_=+[]{}<>?/.,~';

const _wordlist = [
  'orbit', 'maple', 'quartz', 'ember', 'harbor', 'violet', 'granite', 'meadow',
  'copper', 'lunar', 'cobalt', 'canyon', 'summit', 'willow', 'ripple', 'cinder',
  'falcon', 'juniper', 'plume', 'onyx', 'delta', 'marble', 'sable', 'tundra',
  'zephyr', 'ash', 'coral', 'briar', 'flint', 'grove', 'ivory', 'moss',
];

/// Cryptographically-random password/passphrase generation. Uses
/// `Random.secure()` (backed by the platform CSPRNG), never a seeded/
/// predictable RNG, since generated output becomes a real vault secret.
class PasswordGenerator {
  const PasswordGenerator._();

  static String generate(GeneratorOptions options) {
    var pool = '';
    if (options.useLowercase) pool += _lower;
    if (options.useUppercase) pool += _upper;
    if (options.useNumbers) pool += _numbers;
    if (options.useSymbols) pool += _symbols;
    if (pool.isEmpty) pool = _lower;
    if (options.avoidAmbiguous) {
      pool = pool.split('').where((c) => !_ambiguous.contains(c)).join();
    }

    final rand = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < options.length; i++) {
      buffer.write(pool[rand.nextInt(pool.length)]);
    }
    return buffer.toString();
  }

  static String generatePassphrase({int words = 5, String separator = '-'}) {
    final rand = Random.secure();
    return List.generate(words, (_) => _wordlist[rand.nextInt(_wordlist.length)]).join(separator);
  }
}
