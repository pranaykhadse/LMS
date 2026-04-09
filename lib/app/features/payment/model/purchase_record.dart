import 'dart:convert';

/// Represents a completed purchase stored locally on the device.
/// Used to track which courses the user has bought.
class PurchaseRecord {
  final String productId;
  final int courseId;
  final DateTime purchasedAt;
  final String transactionId;

  PurchaseRecord({
    required this.productId,
    required this.courseId,
    required this.purchasedAt,
    required this.transactionId,
  });

  PurchaseRecord copyWith({
    String? productId,
    int? courseId,
    DateTime? purchasedAt,
    String? transactionId,
  }) =>
      PurchaseRecord(
        productId: productId ?? this.productId,
        courseId: courseId ?? this.courseId,
        purchasedAt: purchasedAt ?? this.purchasedAt,
        transactionId: transactionId ?? this.transactionId,
      );

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) => PurchaseRecord(
        productId: json['product_id'] as String,
        courseId: json['course_id'] as int,
        purchasedAt: DateTime.parse(json['purchased_at'] as String),
        transactionId: json['transaction_id'] as String,
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'course_id': courseId,
        'purchased_at': purchasedAt.toIso8601String(),
        'transaction_id': transactionId,
      };

  /// Deserialize a JSON list string to a list of [PurchaseRecord].
  static List<PurchaseRecord> listFromRawJson(String raw) {
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PurchaseRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Serialize a list of [PurchaseRecord] to a JSON string.
  static String listToRawJson(List<PurchaseRecord> records) {
    return jsonEncode(records.map((r) => r.toJson()).toList());
  }

  @override
  String toString() =>
      'PurchaseRecord(courseId: $courseId, transactionId: $transactionId)';
}
