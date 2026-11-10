class Merchant {
  Merchant({
    required this.id,
    required this.username,
    required this.fullName,
    required this.phone,
    required this.governorate,
    required this.address,
    required this.masterCard,
    required this.bankPercent,
    required this.platformPercent,
    required this.active,
    required this.customersCount,
    required this.totalAmounts,
    required this.bankAmounts,
    required this.platformAmounts,
    required this.financedAmounts,
    required this.paidAmounts,
    required this.remainingAmounts,
    required this.dueThisMonthAmount,
    required this.dueThisMonthCount,
    this.dueConfirmedThisMonth = false,
    this.dueCarriedAmount = 0,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String fullName;
  final String phone;
  final String governorate;
  final String address;
  final String masterCard;
  final double bankPercent;
  final double platformPercent;
  final bool active;
  final int customersCount;
  final double totalAmounts;
  final double bankAmounts;
  final double platformAmounts;
  final double financedAmounts;
  final double paidAmounts;
  final double remainingAmounts;
  final double dueThisMonthAmount;
  final int dueThisMonthCount;
  final bool dueConfirmedThisMonth;
  final double dueCarriedAmount;
  final DateTime createdAt;

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      phone: (json['phone'] as String?) ?? '',
      governorate: (json['governorate'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      masterCard: (json['master_card'] as String?) ?? '',
      bankPercent: (json['bank_percent'] as num).toDouble(),
      platformPercent: (json['platform_percent'] as num).toDouble(),
      active: json['active'] as bool? ?? true,
      customersCount: json['customers_count'] as int? ?? 0,
      totalAmounts: (json['total_amounts'] as num?)?.toDouble() ?? 0,
      bankAmounts: (json['bank_amounts'] as num?)?.toDouble() ?? 0,
      platformAmounts: (json['platform_amounts'] as num?)?.toDouble() ?? 0,
      financedAmounts: (json['financed_amounts'] as num?)?.toDouble() ?? 0,
      paidAmounts: (json['paid_amounts'] as num?)?.toDouble() ?? 0,
      remainingAmounts: (json['remaining_amounts'] as num?)?.toDouble() ?? 0,
      dueThisMonthAmount:
          (json['due_this_month_amount'] as num?)?.toDouble() ?? 0,
      dueThisMonthCount: json['due_this_month_count'] as int? ?? 0,
      dueConfirmedThisMonth:
          json['due_confirmed_this_month'] as bool? ?? false,
      dueCarriedAmount:
          (json['due_carried_amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
