class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.phone,
    required this.fullName,
    required this.role,
    required this.accountId,
    required this.accountNumber,
  });

  final String accessToken;
  final String userId;
  final String phone;
  final String fullName;
  final String role;
  final String accountId;
  final String accountNumber;

  factory AuthSession.fromLoginJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final account = (json['account'] as Map?)?.cast<String, dynamic>() ?? {};

    return AuthSession(
      accessToken: json['accessToken']?.toString() ?? '',
      userId: user['id']?.toString() ?? '',
      phone: user['phone']?.toString() ?? '',
      fullName: user['fullName']?.toString() ?? '',
      role: user['role']?.toString() ?? '',
      accountId: account['id']?.toString() ?? '',
      accountNumber: account['accountNumber']?.toString() ?? '',
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'userId': userId,
      'phone': phone,
      'fullName': fullName,
      'role': role,
      'accountId': accountId,
      'accountNumber': accountNumber,
    };
  }

  bool get isValid => accessToken.isNotEmpty && userId.isNotEmpty;
}
