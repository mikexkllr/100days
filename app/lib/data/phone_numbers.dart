/// Phone numbers from an address book into E.164 (`+491512345678`), the
/// form the server compares. Numbers written without a country code are
/// read as numbers of [countryCode] — the phone's own region — the way the
/// phone itself would dial them.
String? toE164(String raw, {required String countryCode}) {
  var digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('00')) digits = '+${digits.substring(2)}';
  if (!digits.startsWith('+')) {
    final String? prefix = kCallingCodes[countryCode.toUpperCase()];
    if (prefix == null) return null;
    // A national number drops its trunk prefix 0 behind the country code.
    digits = '+$prefix${digits.startsWith('0') ? digits.substring(1) : digits}';
  }
  final String rest = digits.substring(1).replaceAll('+', '');
  if (!RegExp(r'^[1-9]\d{6,14}$').hasMatch(rest)) return null;
  return '+$rest';
}

/// Calling codes of the regions the app is most used in; contacts written
/// without a country code in other regions are skipped rather than guessed.
const Map<String, String> kCallingCodes = <String, String>{
  'DE': '49',
  'AT': '43',
  'CH': '41',
  'NL': '31',
  'BE': '32',
  'LU': '352',
  'FR': '33',
  'IT': '39',
  'ES': '34',
  'PT': '351',
  'PL': '48',
  'CZ': '420',
  'DK': '45',
  'SE': '46',
  'NO': '47',
  'FI': '358',
  'IE': '353',
  'GB': '44',
  'US': '1',
  'CA': '1',
  'AU': '61',
  'NZ': '64',
  'TR': '90',
};
