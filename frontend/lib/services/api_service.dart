import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/customer.dart';
import '../models/investor.dart';
import '../models/merchant.dart';
import '../models/page_result.dart';
import '../models/user.dart';
import 'connectivity_monitor.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LoginResult {
  const LoginResult({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class ApiService {
  ApiService({http.Client? client, ConnectivityMonitor? network})
      : _client = client ?? http.Client(),
        _network = network;

  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _client;
  final ConnectivityMonitor? _network;
  String? authToken;

  String get _base => AppConstants.apiBaseUrl;

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        if (authToken != null && authToken!.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      ),
    );
    final data = _decode(res);
    return LoginResult(
      token: data['access_token'] as String,
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<AppUser> getMe() async {
    final res = await _send(
      () => _client.get(
        Uri.parse('$_base/api/auth/me'),
        headers: _jsonHeaders,
      ),
    );
    return AppUser.fromJson(_decode(res));
  }

  Future<void> logout() async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/auth/logout'),
        headers: _jsonHeaders,
      ),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    _decode(res);
  }

  Future<DashboardData> getDashboard() async {
    final res = await _send(
      () => _client.get(
        Uri.parse('$_base/api/dashboard'),
        headers: _jsonHeaders,
      ),
    );
    return DashboardData.fromJson(_decode(res));
  }

  Future<PageResult<Customer>> getCustomers({
    CustomerStatus? status,
    String? merchantId,
    String? q,
    String? governorate,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool excludePending = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (status != null) 'status': status.name,
      if (merchantId != null && merchantId.isNotEmpty) 'merchant_id': merchantId,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (governorate != null && governorate.trim().isNotEmpty)
        'governorate': governorate.trim(),
      if (dateFrom != null) 'date_from': _dateParam(dateFrom),
      if (dateTo != null) 'date_to': _dateParam(dateTo),
      if (excludePending) 'exclude_pending': 'true',
    };
    final query = _query(params);
    final res = await _send(
      () => _client.get(
        Uri.parse('$_base/api/customers$query'),
        headers: _jsonHeaders,
      ),
    );
    return PageResult.fromJson(_decode(res), Customer.fromJson);
  }

  Future<Customer> getCustomer(String id) async {
    final res = await _send(
      () => _client.get(
        Uri.parse('$_base/api/customers/$id'),
        headers: _jsonHeaders,
      ),
    );
    return Customer.fromJson(_decode(res));
  }

  Future<Customer> createCustomer({
    required String name,
    required String phone,
    required String governorate,
    required double totalAmount,
    required int monthsCount,
    DateTime? registrationDate,
    String? mastercardNumber,
    String? nationalId,
  }) async {
    final body = {
      'name': name,
      'phone': phone,
      'governorate': governorate,
      'total_amount': totalAmount,
      'months_count': monthsCount,
      if (registrationDate != null)
        'registration_date': registrationDate.toIso8601String().split('T').first,
      if (mastercardNumber != null) 'mastercard_number': mastercardNumber,
      if (nationalId != null) 'national_id': nationalId,
    };
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/customers'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );
    return Customer.fromJson(_decode(res));
  }

  Future<PageResult<Merchant>> getMerchants({
    String? q,
    String? governorate,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (governorate != null && governorate.trim().isNotEmpty)
        'governorate': governorate.trim(),
    };
    final query = _query(params);
    final res = await _send(
      () => _client.get(
        Uri.parse('$_base/api/merchants$query'),
        headers: _jsonHeaders,
      ),
    );
    return PageResult.fromJson(_decode(res), Merchant.fromJson);
  }

  Future<Merchant> getMerchant(String id) async {
    final res = await _send(
      () => _client.get(
        Uri.parse('$_base/api/merchants/$id'),
        headers: _jsonHeaders,
      ),
    );
    return Merchant.fromJson(_decode(res));
  }

  Future<Merchant> createMerchant({
    required String username,
    required String password,
    required String fullName,
    required String phone,
    required String governorate,
    required String address,
    required String masterCard,
    required double bankPercent,
    required double platformPercent,
    double investorPercent = 0,
  }) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/merchants'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'username': username,
          'password': password,
          'full_name': fullName,
          'phone': phone,
          'governorate': governorate,
          'address': address,
          'master_card': masterCard,
          'bank_percent': bankPercent,
          'platform_percent': platformPercent,
          'investor_percent': investorPercent,
        }),
      ),
    );
    return Merchant.fromJson(_decode(res));
  }

  Future<Merchant> confirmMerchantDues(String id) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/merchants/$id/confirm-dues'),
        headers: _jsonHeaders,
        body: jsonEncode({}),
      ),
    );
    return Merchant.fromJson(_decode(res));
  }

  Future<Merchant> updateMerchant({
    required String id,
    String? fullName,
    String? phone,
    String? governorate,
    String? address,
    String? masterCard,
    String? password,
    double? bankPercent,
    double? platformPercent,
    double? investorPercent,
    bool? active,
  }) async {
    final body = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (governorate != null) 'governorate': governorate,
      if (address != null) 'address': address,
      if (masterCard != null) 'master_card': masterCard,
      if (password != null && password.isNotEmpty) 'password': password,
      if (bankPercent != null) 'bank_percent': bankPercent,
      if (platformPercent != null) 'platform_percent': platformPercent,
      if (investorPercent != null) 'investor_percent': investorPercent,
      if (active != null) 'active': active,
    };
    final res = await _send(
      () => _client.patch(
        Uri.parse('$_base/api/merchants/$id'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );
    return Merchant.fromJson(_decode(res));
  }

  Future<PageResult<Investor>> getInvestors({
    String? q,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };
    final query = _query(params);
    final res = await _send(
      () => _client.get(
        Uri.parse('$_base/api/investors$query'),
        headers: _jsonHeaders,
      ),
    );
    return PageResult.fromJson(_decode(res), Investor.fromJson);
  }

  Future<Investor> getInvestor(String id) async {
    final res = await _send(
      () => _client.get(
        Uri.parse('$_base/api/investors/$id'),
        headers: _jsonHeaders,
      ),
    );
    return Investor.fromJson(_decode(res));
  }

  Future<Investor> createInvestor({
    required String username,
    required String password,
    required String fullName,
    required String phone,
    required String masterCard,
    String note = '',
  }) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/investors'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'username': username,
          'password': password,
          'full_name': fullName,
          'phone': phone,
          'master_card': masterCard,
          'note': note,
        }),
      ),
    );
    return Investor.fromJson(_decode(res));
  }

  Future<Investor> updateInvestor({
    required String id,
    String? fullName,
    String? phone,
    String? masterCard,
    String? password,
    String? note,
    bool? active,
  }) async {
    final body = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (masterCard != null) 'master_card': masterCard,
      if (password != null && password.isNotEmpty) 'password': password,
      if (note != null) 'note': note,
      if (active != null) 'active': active,
    };
    final res = await _send(
      () => _client.patch(
        Uri.parse('$_base/api/investors/$id'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );
    return Investor.fromJson(_decode(res));
  }

  Future<PageResult<Investment>> getInvestments({
    String? investorId,
    InvestmentStatus? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (investorId != null && investorId.isNotEmpty) 'investor_id': investorId,
      if (status != null) 'status': status.name,
    };
    final query = _query(params);
    final res = await _send(
      () => _client.get(
        Uri.parse('$_base/api/investments$query'),
        headers: _jsonHeaders,
      ),
    );
    return PageResult.fromJson(_decode(res), Investment.fromJson);
  }

  Future<Investment> getInvestment(String id) async {
    final res = await _send(
      () => _client.get(
        Uri.parse('$_base/api/investments/$id'),
        headers: _jsonHeaders,
      ),
    );
    return Investment.fromJson(_decode(res));
  }

  Future<Investment> createInvestment({
    required String investorId,
    required double principal,
    required double interestPercent,
    required int monthsCount,
    DateTime? startDate,
    String note = '',
  }) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/investments'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'investor_id': investorId,
          'principal': principal,
          'interest_percent': interestPercent,
          'months_count': monthsCount,
          if (startDate != null)
            'start_date': startDate.toIso8601String().split('T').first,
          'note': note,
        }),
      ),
    );
    return Investment.fromJson(_decode(res));
  }

  Future<Investment> confirmInvestmentPayouts(String investmentId) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/investments/$investmentId/confirm-payouts'),
        headers: _jsonHeaders,
        body: jsonEncode({}),
      ),
    );
    return Investment.fromJson(_decode(res));
  }

  Future<Investment> confirmPayout(String payoutId) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/investments/payouts/$payoutId/confirm'),
        headers: _jsonHeaders,
        body: jsonEncode({}),
      ),
    );
    return Investment.fromJson(_decode(res));
  }

  Future<Investment> cancelInvestment(String id) async {
    final res = await _send(
      () => _client.patch(
        Uri.parse('$_base/api/investments/$id'),
        headers: _jsonHeaders,
        body: jsonEncode({'status': 'cancelled'}),
      ),
    );
    return Investment.fromJson(_decode(res));
  }

  Future<Customer> approveCustomer(String id) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/customers/$id/approve'),
        headers: _jsonHeaders,
        body: jsonEncode({}),
      ),
    );
    return Customer.fromJson(_decode(res));
  }

  Future<Customer> rejectCustomer(String id) async {
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/customers/$id/reject'),
        headers: _jsonHeaders,
        body: jsonEncode({}),
      ),
    );
    return Customer.fromJson(_decode(res));
  }

  Future<Customer> updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? governorate,
    String? mastercardNumber,
    String? nationalId,
    CustomerStatus? status,
    String? confirmPassword,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (governorate != null) 'governorate': governorate,
      if (mastercardNumber != null) 'mastercard_number': mastercardNumber,
      if (nationalId != null) 'national_id': nationalId,
      if (status != null) 'status': status.name,
      if (confirmPassword != null && confirmPassword.isNotEmpty)
        'confirm_password': confirmPassword,
    };
    final res = await _send(
      () => _client.patch(
        Uri.parse('$_base/api/customers/$id'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );
    return Customer.fromJson(_decode(res));
  }

  Future<Customer> addPayment({
    required String customerId,
    double? amount,
    DateTime? paymentDate,
    String? note,
    String? method,
  }) async {
    final body = {
      'customer_id': customerId,
      'amount': ?amount,
      if (paymentDate != null)
        'payment_date': paymentDate.toIso8601String().split('T').first,
      if (note != null && note.isNotEmpty) 'note': note,
      if (method != null) 'method': method,
    };
    final res = await _send(
      () => _client.post(
        Uri.parse('$_base/api/payments'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );
    return Customer.fromJson(_decode(res));
  }

  Future<Customer> updatePayment({
    required String paymentId,
    double? amount,
    DateTime? paymentDate,
    String? note,
    String? method,
  }) async {
    final body = <String, dynamic>{
      if (amount != null) 'amount': amount,
      if (paymentDate != null)
        'payment_date': paymentDate.toIso8601String().split('T').first,
      if (note != null) 'note': note,
      if (method != null) 'method': method,
    };
    final res = await _send(
      () => _client.patch(
        Uri.parse('$_base/api/payments/$paymentId'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      ),
    );
    return Customer.fromJson(_decode(res));
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final res = await request().timeout(_timeout);
      _network?.markServerReachable();
      return res;
    }     on TimeoutException {
      _network?.markServerUnreachable();
      throw ApiException('انتهت مهلة الاتصال بالخادم');
    } on http.ClientException {
      _network?.markServerUnreachable();
      throw ApiException('تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى');
    } on ApiException {
      rethrow;
    } catch (e) {
      if (_looksLikeNetworkFailure(e)) {
        _network?.markServerUnreachable();
        throw ApiException(
          'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى',
        );
      }
      rethrow;
    }
  }

  bool _looksLikeNetworkFailure(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('socket') ||
        text.contains('failed host lookup') ||
        text.contains('connection') ||
        text.contains('network') ||
        text.contains('timed out');
  }

  String _dateParam(DateTime value) {
    final d = DateTime(value.year, value.month, value.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _query(Map<String, String> params) {
    if (params.isEmpty) return '';
    return '?${params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
  }

  Map<String, dynamic> _decode(http.Response res) {
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded as Map<String, dynamic>;
    }
    throw ApiException(_extractError(decoded, res.statusCode));
  }

  String _extractError(dynamic decoded, int statusCode) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'].toString();
        }
        return first.toString();
      }
    }
    return 'خطأ في الاتصال بالخادم ($statusCode)';
  }
}
