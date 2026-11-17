import 'package:supabase_flutter/supabase_flutter.dart';

/// What the user may spend on AI this month, as the server enforces it.
class AiAllowance {
  const AiAllowance({
    required this.premium,
    required this.used,
    this.limit,
    this.premiumUntil,
  });

  /// No server to ask (tests, offline): free, nothing used.
  static const AiAllowance unknown = AiAllowance(premium: false, used: 0);

  factory AiAllowance.fromJson(Map<String, dynamic> json) => AiAllowance(
        premium: json['tier'] == 'premium',
        used: (json['used'] as num?)?.toInt() ?? 0,
        limit: (json['limit'] as num?)?.toInt(),
        premiumUntil: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      );

  final bool premium;
  final int used;

  /// Null until the gateway has enforced one this month.
  final int? limit;
  final DateTime? premiumUntil;

  /// 0..1, or null while the limit is unknown.
  double? get fraction =>
      limit == null || limit == 0 ? null : (used / limit!).clamp(0.0, 1.0);

  bool get exhausted => limit != null && used >= limit!;

  static Future<AiAllowance> fetch(SupabaseClient client) async {
    final Object? result = await client.rpc('my_ai_allowance');
    if (result is! Map) return unknown;
    return AiAllowance.fromJson(Map<String, dynamic>.from(result));
  }
}
