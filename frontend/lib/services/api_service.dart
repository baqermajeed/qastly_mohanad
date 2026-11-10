import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/customer.dart';
import '../models/merchant.dart';
import '../models/user.dart';

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
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
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
    final res = await _client.post(
      Uri.parse('$_base/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'password': password,
      }),
    );
    final data = _decode(res);
    return LoginResult(
      token: data['access_token'] as String,
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<AppUser> getMe() async {
    final res = await _client.get(
      Uri.parse('$_base/api/auth/me'),
      headers: _jsonHeaders,
    );
    return AppUser.fromJson(_decode(res));
  }

  Future<void> logout() async {
    final res = await _client.post(
      Uri.parse('$_base/api/auth/logout'),
      headers: _jsonHeaders,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    _decode(res);
  }

  Future<DashboardData> getDashboard() async {
    final res = await _client.get(
      Uri.parse('$_base/api/dashboard'),
      headers: _jsonHeaders,
    );
    return DashboardData.fromJson(_decode(res));
  }

  Future<List<Customer>> getCustomers({
    CustomerStatus? status,
    String? merchantId,
  }) async {
    final params = <String, String>{
      if (status != null) 'status': status.name,
      if (merchantId != null && merchantId.isNotEmpty) 'merchant_id': merchantId,
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final res = await _client.get(
      Uri.parse('$_base/api/customers$query'),
      headers: _jsonHeaders,
    );
    final list = _decodeList(res);
    return list.map(Customer.fromJson).toList();
  }

  Future<Customer> getCustomer(String id) async {
    final res = await _client.get(
      Uri.parse('$_base/api/customers/$id'),
      headers: _jsonHeaders,
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
    final res = await _client.post(
      Uri.parse('$_base/api/customers'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    return Customer.fromJson(_decode(res));
  }

  Future<List<Merchant>> getMerchants() async {
    final res = await _client.get(
      Uri.parse('$_base/api/merchants'),
      headers: _jsonHeaders,
    );
    final list = _decodeList(res);
    return list.map(Merchant.fromJson).toList();
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
  }) async {
    final res = await _client.post(
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
      }),
    );
    return Merchant.fromJson(_decode(res));
  }

  Future<Merchant> confirmMerchantDues(String id) async {
    final res = await _client.post(
      Uri.parse('$_base/api/merchants/$id/confirm-dues'),
      headers: _jsonHeaders,
      body: jsonEncode({}),
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
      if (active != null) 'active': active,
    };
    final res = await _client.patch(
      Uri.parse('$_base/api/merchants/$id'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    return Merchant.fromJson(_decode(res));
  }

  Future<Customer> approveCustomer(String id) async {
    final res = await _client.post(
      Uri.parse('$_base/api/customers/$id/approve'),
      headers: _jsonHeaders,
      body: jsonEncode({}),
    );
    return Customer.fromJson(_decode(res));
  }

  Future<Customer> rejectCustomer(String id) async {
    final res = await _client.post(
      Uri.parse('$_base/api/customers/$id/reject'),
      headers: _jsonHeaders,
      body: jsonEncode({}),
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
    final res = await _client.patch(
      Uri.parse('$_base/api/customers/$id'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
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
    final res = await _client.post(
      Uri.parse('$_base/api/payments'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
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
    final res = await _client.patch(
      Uri.parse('$_base/api/payments/$paymentId'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    return Customer.fromJson(_decode(res));
  }

  Map<String, dynamic> _decode(http.Response res) {
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded as Map<String, dynamic>;
    }
    throw ApiException(_extractError(decoded, res.statusCode));
  }

  List<Map<String, dynamic>> _decodeList(http.Response res) {
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (decoded as List<dynamic>).cast<Map<String, dynamic>>();
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
