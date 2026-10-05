import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

/// One of the employee's own reimbursement claims. The amount is a decimal
/// string (e.g. `"500000.00"`); the client never does money math.
class ReimbursementClaim {
  ReimbursementClaim.fromJson(Json json)
      : id = json.str('id'),
        category = json.str('category'),
        amount = json.str('amount'),
        currency = json.str('currency'),
        expenseDate = json.str('expenseDate'),
        description = json.str('description'),
        receiptUrl = json.strOrNull('receiptUrl'),
        status = json.str('status'),
        decisionNote = json.strOrNull('decisionNote'),
        approvalId = json.strOrNull('approvalId'),
        submittedAt = json.time('submittedAt'),
        decidedAt = json.timeOrNull('decidedAt');

  final String id;
  final String category;
  final String amount;
  final String currency;
  final String expenseDate;
  final String description;
  final String? receiptUrl;
  final String status;
  final String? decisionNote;
  final String? approvalId;
  final DateTime submittedAt;
  final DateTime? decidedAt;

  bool get isPending => status == 'PENDING';
}

/// Access to the employee's own reimbursement claims. Approval is driven by the
/// generic approval engine, so this exposes only submit / list / cancel.
class ReimbursementRepository {
  ReimbursementRepository(this._api);

  final ApiClient _api;

  Future<List<ReimbursementClaim>> list() async => dataList(
        await _api.dio
            .get('/reimbursements/me', queryParameters: {'limit': 50}),
      ).map(ReimbursementClaim.fromJson).toList();

  Future<void> submit({
    required String category,
    required num amount,
    required String expenseDate,
    required String description,
    String? currency,
    String? receiptUrl,
  }) =>
      _api.dio.post('/reimbursements', data: {
        'category': category,
        'amount': amount,
        'expenseDate': expenseDate,
        'description': description,
        if (currency != null) 'currency': currency,
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
      });

  Future<void> cancel(String id) => _api.dio.post('/reimbursements/$id/cancel');

  /// Uploads a receipt image and returns its URL (`POST /files/images`).
  Future<String> uploadReceipt(String path) async {
    final extension = path.split('.').last.toLowerCase();
    final subtype = switch (extension) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpeg',
    };
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        path,
        contentType: DioMediaType('image', subtype),
      ),
    });
    return data(await _api.dio.post('/files/images', data: form)).str('url');
  }
}
