import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/order.dart';
import 'order_service.dart';
import 'inventory_service.dart';

class PaymentService with ChangeNotifier {
  final OrderService orderService;
  final InventoryService inventoryService;

  PaymentService(this.orderService, this.inventoryService);

  // Supported payment methods
  static const List<String> paymentMethods = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'Digital Wallet',
    'Other',
  ];

  // Process a payment for an order
  Future<void> processPayment({
    required Order order,
    required String method,
    String? transactionId,
    double? amount,
  }) async {
    try {
      // Here you would integrate with a real payment gateway if needed
      // For now, we simulate a successful payment
      order.copyWith(
        paymentMethod: method,
        paymentStatus: PaymentStatus.paid,
        paymentTransactionId: transactionId ?? 'TXN${DateTime.now().millisecondsSinceEpoch}',
      );
      await orderService.updateOrderStatus(order.id, OrderStatus.completed);
      
      // TODO: Update inventory after successful payment
      // await inventoryService.updateInventoryOnOrderCompletion(updatedOrder);
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during process payment: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during process payment: $e');
      }
      
      debugPrint('Payment processed for order: ${order.orderNumber}');
    } catch (e) {
      debugPrint('Payment failed: $e');
      // Optionally update order/payment status to failed
      // ...
      rethrow;
    }
  }

  // Refund a payment
  Future<void> refundPayment(Order order) async {
    try {
      // Simulate refund logic
      order.copyWith(
        paymentStatus: PaymentStatus.refunded,
      );
      await orderService.updateOrderStatus(order.id, OrderStatus.refunded);
      // Optionally update payment info in DB
      // ...
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during refund payment: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during refund payment: $e');
      }
      
      debugPrint('Payment refunded for order: ${order.orderNumber}');
    } catch (e) {
      debugPrint('Refund failed: $e');
      rethrow;
    }
  }
} 