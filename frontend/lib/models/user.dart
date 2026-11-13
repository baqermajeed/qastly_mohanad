class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    this.role = 'merchant',
    this.bankPercent,
    this.platformPercent,
    this.investorPercent,
    this.active = true,
  });

  final String id;
  final String username;
  final String fullName;
  final String role;
  final double? bankPercent;
  final double? platformPercent;
  final double? investorPercent;
  final bool active;

  bool get isAdmin => role == 'admin';
  bool get isMerchant => role == 'merchant';
  bool get isInvestor => role == 'investor';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      role: (json['role'] as String?) ?? 'merchant',
      bankPercent: (json['bank_percent'] as num?)?.toDouble(),
      platformPercent: (json['platform_percent'] as num?)?.toDouble(),
      investorPercent: (json['investor_percent'] as num?)?.toDouble(),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'role': role,
        'bank_percent': bankPercent,
        'platform_percent': platformPercent,
        'investor_percent': investorPercent,
        'active': active,
      };
}
