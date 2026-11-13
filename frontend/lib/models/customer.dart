import 'merchant.dart';

enum CustomerStatus { pending, active, inactive, completed, rejected }

CustomerStatus statusFromString(String value) {
  switch (value) {
    case 'pending':
      return CustomerStatus.pending;
    case 'rejected':
      return CustomerStatus.rejected;
    case 'inactive':
    case 'canceled':
    case 'cancelled':
      return CustomerStatus.inactive;
    case 'completed':
      return CustomerStatus.completed;
    case 'active':
    case 'paid':
    case 'late':
    default:
      return CustomerStatus.active;
  }
}

String statusLabel(CustomerStatus status) {
  switch (status) {
    case CustomerStatus.pending:
      return 'بانتظار الموافقة';
    case CustomerStatus.rejected:
      return 'مرفوضة';
    case CustomerStatus.active:
      return 'نشطة';
    case CustomerStatus.inactive:
      return 'غير نشطة';
    case CustomerStatus.completed:
      return 'مكتملة';
  }
}

int _resolveRemainingMonths({
  required double remainingAmount,
  required int monthsCount,
  required int paymentsCount,
  required int apiRemainingMonths,
}) {
  if (remainingAmount <= 0) return 0;
  final fromPayments = monthsCount - paymentsCount;
  if (fromPayments >= 0) {
    return fromPayments.clamp(0, monthsCount);
  }
  return apiRemainingMonths.clamp(0, monthsCount);
}

class PaymentRecord {
  PaymentRecord({
    required this.id,
    required this.amount,
    required this.paymentDate,
    this.note,
    this.method = 'auto',
    this.installmentNo,
  });

  final String id;
  final double amount;
  final DateTime paymentDate;
  final String? note;
  final String method;
  final int? installmentNo;

  bool get isCard => method == 'card';
  bool get isAuto => method == 'auto';

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(json['payment_date'] as String),
      note: json['note'] as String?,
      method: (json['method'] as String?) ?? 'auto',
      installmentNo: json['installment_no'] as int?,
    );
  }
}

class Customer {
  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.governorate,
    this.mastercardNumber = '',
    this.nationalId = '',
    required this.totalAmount,
    required this.monthsCount,
    required this.registrationDate,
    required this.monthlyPayment,
    required this.paidAmount,
    required this.remainingAmount,
    required this.remainingMonths,
    required this.status,
    required this.whatsappUrl,
    this.merchantId = '',
    this.merchantName,
    this.bankPercent = 0,
    this.platformPercent = 0,
    this.investorPercent = 0,
    this.bankAmount = 0,
    this.platformAmount = 0,
    this.investorAmount = 0,
    this.financedAmount = 0,
    this.paymentsCount = 0,
    this.firstDueDate,
    this.nextDueDate,
    this.payments = const [],
  });

  final String id;
  final String merchantId;
  final String? merchantName;
  final String name;
  final String phone;
  final String governorate;
  final String mastercardNumber;
  final String nationalId;
  final double totalAmount;
  final int monthsCount;
  final DateTime registrationDate;
  final double bankPercent;
  final double platformPercent;
  final double investorPercent;
  final double bankAmount;
  final double platformAmount;
  final double investorAmount;
  final double financedAmount;
  final double monthlyPayment;
  final double paidAmount;
  final double remainingAmount;
  final int remainingMonths;
  final int paymentsCount;
  final DateTime? firstDueDate;
  final DateTime? nextDueDate;
  final CustomerStatus status;
  final String whatsappUrl;
  final List<PaymentRecord> payments;

  factory Customer.fromJson(Map<String, dynamic> json) {
    final paymentsJson = json['payments'] as List<dynamic>? ?? [];
    return Customer(
      id: json['id'] as String,
      merchantId: (json['merchant_id'] as String?) ?? '',
      merchantName: json['merchant_name'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String,
      governorate: json['governorate'] as String,
      mastercardNumber: (json['mastercard_number'] as String?) ?? '',
      nationalId: (json['national_id'] as String?) ?? '',
      totalAmount: (json['total_amount'] as num).toDouble(),
      monthsCount: json['months_count'] as int,
      registrationDate: DateTime.parse(json['registration_date'] as String),
      bankPercent: (json['bank_percent'] as num?)?.toDouble() ?? 0,
      platformPercent: (json['platform_percent'] as num?)?.toDouble() ?? 0,
      investorPercent: (json['investor_percent'] as num?)?.toDouble() ?? 0,
      bankAmount: (json['bank_amount'] as num?)?.toDouble() ?? 0,
      platformAmount: (json['platform_amount'] as num?)?.toDouble() ?? 0,
      investorAmount: (json['investor_amount'] as num?)?.toDouble() ?? 0,
      financedAmount: (json['financed_amount'] as num?)?.toDouble() ?? 0,
      monthlyPayment: (json['monthly_payment'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num).toDouble(),
      remainingAmount: (json['remaining_amount'] as num).toDouble(),
      // API القديم كان يرجع ceil(مبلغ/قسط) فيصير 37 لخطة 36 بسبب تقريب القسط.
      // الأشهر المتبقية = الأقساط غير المدفوعة، وبحد أقصى طول الخطة.
      remainingMonths: _resolveRemainingMonths(
        remainingAmount: (json['remaining_amount'] as num).toDouble(),
        monthsCount: json['months_count'] as int,
        paymentsCount: json['payments_count'] as int? ?? 0,
        apiRemainingMonths: json['remaining_months'] as int,
      ),
      paymentsCount: json['payments_count'] as int? ?? 0,
      firstDueDate: json['first_due_date'] == null
          ? null
          : DateTime.parse(json['first_due_date'] as String),
      nextDueDate: json['next_due_date'] == null
          ? null
          : DateTime.parse(json['next_due_date'] as String),
      status: statusFromString(json['status'] as String),
      whatsappUrl: json['whatsapp_url'] as String,
      payments: paymentsJson
          .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DashboardStats {
  DashboardStats({
    required this.totalCustomers,
    required this.completedCount,
    required this.remainingCount,
    required this.lateCount,
    required this.totalAmounts,
    required this.paidAmounts,
    required this.remainingAmounts,
    this.pendingCount = 0,
    this.bankAmounts = 0,
    this.platformAmounts = 0,
    this.investorCommissionAmounts = 0,
    this.financedAmounts = 0,
    this.merchantsCount = 0,
    this.dueThisMonthAmount = 0,
    this.dueThisMonthCount = 0,
    this.investorsCount = 0,
    this.investmentsCount = 0,
    this.investorPrincipalTotal = 0,
    this.investorTotalWithInterest = 0,
    this.investorPaidAmount = 0,
    this.investorRemainingAmount = 0,
    this.investorDueThisMonthAmount = 0,
  });

  final int totalCustomers;
  final int completedCount;
  final int remainingCount;
  final int lateCount;
  final int pendingCount;
  final double totalAmounts;
  final double paidAmounts;
  final double remainingAmounts;
  final double bankAmounts;
  final double platformAmounts;
  final double investorCommissionAmounts;
  final double financedAmounts;
  final int merchantsCount;
  final double dueThisMonthAmount;
  final int dueThisMonthCount;
  final int investorsCount;
  final int investmentsCount;
  final double investorPrincipalTotal;
  final double investorTotalWithInterest;
  final double investorPaidAmount;
  final double investorRemainingAmount;
  final double investorDueThisMonthAmount;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalCustomers: json['total_customers'] as int,
      completedCount: json['completed_count'] as int,
      remainingCount: json['remaining_count'] as int,
      lateCount: json['late_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      totalAmounts: (json['total_amounts'] as num).toDouble(),
      paidAmounts: (json['paid_amounts'] as num).toDouble(),
      remainingAmounts: (json['remaining_amounts'] as num).toDouble(),
      bankAmounts: (json['bank_amounts'] as num?)?.toDouble() ?? 0,
      platformAmounts: (json['platform_amounts'] as num?)?.toDouble() ?? 0,
      investorCommissionAmounts:
          (json['investor_commission_amounts'] as num?)?.toDouble() ?? 0,
      financedAmounts: (json['financed_amounts'] as num?)?.toDouble() ?? 0,
      merchantsCount: json['merchants_count'] as int? ?? 0,
      dueThisMonthAmount:
          (json['due_this_month_amount'] as num?)?.toDouble() ?? 0,
      dueThisMonthCount: json['due_this_month_count'] as int? ?? 0,
      investorsCount: json['investors_count'] as int? ?? 0,
      investmentsCount: json['investments_count'] as int? ?? 0,
      investorPrincipalTotal:
          (json['investor_principal_total'] as num?)?.toDouble() ?? 0,
      investorTotalWithInterest:
          (json['investor_total_with_interest'] as num?)?.toDouble() ?? 0,
      investorPaidAmount:
          (json['investor_paid_amount'] as num?)?.toDouble() ?? 0,
      investorRemainingAmount:
          (json['investor_remaining_amount'] as num?)?.toDouble() ?? 0,
      investorDueThisMonthAmount:
          (json['investor_due_this_month_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DashboardData {
  DashboardData({
    required this.stats,
    required this.customers,
    this.merchants = const [],
    this.role = 'merchant',
  });

  final DashboardStats stats;
  final List<Customer> customers;
  final List<Merchant> merchants;
  final String role;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final customersJson = json['customers'] as List<dynamic>? ?? [];
    final merchantsJson = json['merchants'] as List<dynamic>? ?? [];
    return DashboardData(
      stats: DashboardStats.fromJson(json['stats'] as Map<String, dynamic>),
      customers: customersJson
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList(),
      merchants: merchantsJson
          .map((e) => Merchant.fromJson(e as Map<String, dynamic>))
          .toList(),
      role: (json['role'] as String?) ?? 'merchant',
    );
  }
}
