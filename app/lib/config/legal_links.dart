import 'dart:ui' show Locale;

/// The project's public pages (`site/` in the repository, on GitHub Pages):
/// what the stores require the app to link to — the privacy policy, and the
/// terms next to every subscription offer.
const String kWebsiteUrl = 'https://mikexkllr.github.io/100days/';

/// The privacy policy, in German for German readers.
Uri privacyPolicyUri(Locale locale) => Uri.parse(
    '$kWebsiteUrl${locale.languageCode == 'de' ? 'datenschutz' : 'privacy'}.html');

/// The terms of use, in German for German readers.
Uri termsUri(Locale locale) =>
    Uri.parse('$kWebsiteUrl${locale.languageCode == 'de' ? 'agb' : 'terms'}.html');
