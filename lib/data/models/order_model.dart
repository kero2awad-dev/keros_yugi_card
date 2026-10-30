enum OrderStatus {
  pending,
  confirmed,
  preparing,
  shipped,
  completed,
  cancelled
}

class YugiOrder {
  final String id;
  final String userId;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final List<OrderItem> items;

  YugiOrder({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.items = const [],
  });

  factory YugiOrder.fromJson(Map<String, dynamic> json) {
    return YugiOrder(
      id: json['id'],
      userId: json['user_id'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: _parseStatus(json['status']),
      createdAt: DateTime.parse(json['created_at']),
      items: (json['order_items'] as List?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  static OrderStatus _parseStatus(String status) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => OrderStatus.pending,
    );
  }
}

class OrderItem {
  final String id;
  final String? collectionName;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    this.collectionName,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      collectionName: json['collection_name'],
      quantity: json['quantity'] ?? 1,
      price: (json['price'] as num).toDouble(),
    );
  }
}
