import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryLog {
  final String id;
  final String storeId;
  final String productId;
  final String productName;
  final double changeAmount;
  final double previousQuantity;
  final double newQuantity;
  final String reason;
  final DateTime timestamp;

  InventoryLog({
    required this.id,
    required this.storeId,
    required this.productId,
    required this.productName,
    required this.changeAmount,
    required this.previousQuantity,
    required this.newQuantity,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'productId': productId,
      'productName': productName,
      'changeAmount': changeAmount,
      'previousQuantity': previousQuantity,
      'newQuantity': newQuantity,
      'reason': reason,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory InventoryLog.fromMap(Map<String, dynamic> map, String id) {
    return InventoryLog(
      id: id,
      storeId: map['storeId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      changeAmount: (map['changeAmount'] as num? ?? 0.0).toDouble(),
      previousQuantity: (map['previousQuantity'] as num? ?? 0.0).toDouble(),
      newQuantity: (map['newQuantity'] as num? ?? 0.0).toDouble(),
      reason: map['reason'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
