import 'dart:convert';

String mimeTypeForAuthFile(String fileName) {
  final lowerName = fileName.toLowerCase();
  if (lowerName.endsWith('.pdf')) return 'application/pdf';
  if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) return 'image/jpeg';
  if (lowerName.endsWith('.png')) return 'image/png';
  if (lowerName.endsWith('.webp')) return 'image/webp';
  if (lowerName.endsWith('.heic')) return 'image/heic';
  if (lowerName.endsWith('.heif')) return 'image/heif';
  return 'application/octet-stream';
}

dynamic decodeAuthJson(String body) {
  if (body.trim().isEmpty) return null;
  try { return jsonDecode(body); } on FormatException { return null; }
}

String englishAuthApiMessage(dynamic decoded, String fallback) {
  final message = decoded is Map ? decoded['message']?.toString() : null;
  switch (message) {
    case 'Amount must be greater than zero': return 'Amount must be greater than zero';
    case 'Minimum withdrawal amount is ₹100': return 'Minimum withdrawal amount is ₹100';
    case 'Withdrawal amount cannot have more than two decimal places': return 'Withdrawal amount can have at most two decimal places';
    case 'Withdrawal amount exceeds the limit': return 'Withdrawal amount exceeds the supported limit';
    case 'Provide either UPI ID or complete bank details': return 'Please provide complete withdrawal details';
    case 'Insufficient cash balance': return 'Insufficient cash balance';
    case 'Insufficient available balance': return 'Part of your balance is currently frozen';
    case 'Insufficient available balance after pending withdrawals': return 'Available balance is reserved by pending withdrawals';
    case 'Account not found':
    case '未找到账户': return 'Trading account not found';
    default: return message == null || RegExp(r'[\u4e00-\u9fff]').hasMatch(message) ? fallback : message;
  }
}

class TwoFactorRequiredException implements Exception { const TwoFactorRequiredException(); }

class AuthException implements Exception {
  const AuthException(this._message, {this.code, this.requestId});
  final String _message;
  final String? code;
  final String? requestId;
  String get message => RegExp(r'[\u3400-\u9fff]').hasMatch(_message) ? 'Unable to complete this request. Please try again.' : _message;
  @override String toString() => message;
}

class KycRequiredException implements Exception { const KycRequiredException(this.token); final String token; }
