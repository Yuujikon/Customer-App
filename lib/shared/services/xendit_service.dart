import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class XenditService {
  static String get _secretKey {
    final envKey = dotenv.env['XENDIT_SECRET_KEY'] ?? '';
    if (envKey.isNotEmpty) return envKey;
    return 'xnd_development_RionwbHhYXD6gb2TwhpoNYqsJIiLNGMk9iktaOyxjvQybuRDvm2DfYCvRyPAJq';
  }

  static Map<String, String> get _headers {
    final bytes = utf8.encode('$_secretKey:');
    final base64Str = base64.encode(bytes);
    return {
      'Authorization': 'Basic $base64Str',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// Creates a Xendit Invoice and returns its ID and Checkout URL.
  static Future<Map<String, String>> createInvoice({
    required double amount,
    required String description,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required List<String> paymentMethods,
  }) async {
    if (_secretKey.isEmpty || _secretKey == 'mock') {
      return {
        'id': 'inv_mock_${DateTime.now().millisecondsSinceEpoch}',
        'url': 'https://httpbin.org/get?mock_payment=success',
      };
    }

    final url = Uri.parse('https://api.xendit.co/v2/invoices');

    final externalId = 'order_${DateTime.now().millisecondsSinceEpoch}';

    final body = jsonEncode({
      'external_id': externalId,
      'amount': amount,
      'payer_email': customerEmail,
      'description': description,
      'customer': {
        'given_names': customerName,
        'email': customerEmail,
        'mobile_number': customerPhone,
      },
      'payment_methods': paymentMethods.map((e) => e.toUpperCase()).toList(),
      'currency': 'PHP',
    });

    final response = await http.post(url, headers: _headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final id = data['id'];
      final invoiceUrl = data['invoice_url'];
      return {
        'id': id.toString(),
        'url': invoiceUrl.toString(),
      };
    } else {
      throw Exception('Failed to create Xendit Invoice: ${response.body}');
    }
  }

  /// Retrieves the Xendit Invoice and checks if it's paid.
  /// Returns the Payment Reference number if paid, otherwise returns null.
  static Future<String?> checkPaymentStatus(String invoiceId) async {
    if (invoiceId.startsWith('inv_mock_')) {
      return 'pay_mock_${DateTime.now().millisecondsSinceEpoch}';
    }

    final url = Uri.parse('https://api.xendit.co/v2/invoices/$invoiceId');

    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final status = data['status'];
      if (status == 'PAID' || status == 'SETTLED') {
        return invoiceId; // Return Xendit Invoice ID as reference
      }
      return null;
    } else {
      throw Exception('Failed to retrieve Xendit Invoice: ${response.body}');
    }
  }
}
