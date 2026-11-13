class Investor {
  Investor({
    required this.id,
    required this.username,
    required this.fullName,
    required this.phone,
    required this.note,
    required this.active,
    required this.investmentsCount,
    required this.principalTotal,
    required this.interestTotal,
    required this.totalWithInterest,
    required this.paidAmount,
    required this.remainingAmount,
    required this.dueThisMonthAmount,
    required this.monthlyPayoutTotal,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String fullName;
  final String phone;
  final String note;
  final bool active;
  final int investmentsCount;
  final double principalTotal;
  final double interestTotal;
  final double totalWithInterest;
  final double paidAmount;
  final double remainingAmount;
  final double dueThisMonthAmount;
  final double monthlyPayoutTotal;
  final DateTime createdAt;

  factory Investor.fromJson(Map<String, dynamic> json) {
    return Investor(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      phone: (json['phone'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      active: json['active'] as bool? ?? true,
      investmentsCount: json['investments_count'] as int? ?? 0,
      principalTotal: (json['principal_total'] as num?)?.toDouble() ?? 0,
      interestTotal: (json['interest_total'] as num?)?.toDouble() ?? 0,
      totalWithInterest: (json['total_with_interest'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      dueThisMonthAmount:
          (json['due_this_month_amount'] as num?)?.toDouble() ?? 0,
      monthlyPayoutTotal:
          (json['monthly_payout_total'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

enum InvestmentStatus { active, completed, cancelled }

InvestmentStatus investmentStatusFrom(String? value) {
  switch (value) {
    case 'completed':
      return InvestmentStatus.completed;
    case 'cancelled':
      return InvestmentStatus.cancelled;
    default:
      return InvestmentStatus.active;
  }
}

String investmentStatusLabel(InvestmentStatus status) {
  switch (status) {
    case InvestmentStatus.active:
      return 'نشط';
    case InvestmentStatus.completed:
      return 'مكتمل';
    case InvestmentStatus.cancelled:
      return 'ملغى';
  }
}

class InvestorPayout {
  InvestorPayout({
    required this.id,
    required this.investmentId,
    required this.investorId,
    required this.amount,
    required this.installmentNo,
    required this.dueDate,
    required this.paid,
    this.paidAt,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String investmentId;
  final String investorId;
  final double amount;
  final int installmentNo;
  final DateTime dueDate;
  final bool paid;
  final DateTime? paidAt;
  final String? note;
  final DateTime createdAt;

  factory InvestorPayout.fromJson(Map<String, dynamic> json) {
    return InvestorPayout(
      id: json['id'] as String,
      investmentId: json['investment_id'] as String,
      investorId: json['investor_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      installmentNo: json['installment_no'] as int,
      dueDate: DateTime.parse(json['due_date'] as String),
      paid: json['paid'] as bool? ?? false,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Investment {
  Investment({
    required this.id,
    required this.investorId,
    this.investorName,
    required this.principal,
    required this.interestPercent,
    required this.interestAmount,
    required this.totalWithInterest,
    required this.monthsCount,
    required this.monthlyPayout,
    required this.startDate,
    required this.firstDueDate,
    required this.status,
    required this.note,
    required this.paidAmount,
    required this.remainingAmount,
    required this.remainingMonths,
    required this.dueThisMonthAmount,
    required this.payouts,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String investorId;
  final String? investorName;
  final double principal;
  final double interestPercent;
  final double interestAmount;
  final double totalWithInterest;
  final int monthsCount;
  final double monthlyPayout;
  final DateTime startDate;
  final DateTime firstDueDate;
  final InvestmentStatus status;
  final String note;
  final double paidAmount;
  final double remainingAmount;
  final int remainingMonths;
  final double dueThisMonthAmount;
  final List<InvestorPayout> payouts;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory Investment.fromJson(Map<String, dynamic> json) {
    final payoutsRaw = json['payouts'] as List<dynamic>? ?? const [];
    return Investment(
      id: json['id'] as String,
      investorId: json['investor_id'] as String,
      investorName: json['investor_name'] as String?,
      principal: (json['principal'] as num).toDouble(),
      interestPercent: (json['interest_percent'] as num).toDouble(),
      interestAmount: (json['interest_amount'] as num).toDouble(),
      totalWithInterest: (json['total_with_interest'] as num).toDouble(),
      monthsCount: json['months_count'] as int,
      monthlyPayout: (json['monthly_payout'] as num).toDouble(),
      startDate: DateTime.parse(json['start_date'] as String),
      firstDueDate: DateTime.parse(json['first_due_date'] as String),
      status: investmentStatusFrom(json['status'] as String?),
      note: (json['note'] as String?) ?? '',
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      remainingMonths: json['remaining_months'] as int? ?? 0,
      dueThisMonthAmount:
          (json['due_this_month_amount'] as num?)?.toDouble() ?? 0,
      payouts: payoutsRaw
          .map((e) => InvestorPayout.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
