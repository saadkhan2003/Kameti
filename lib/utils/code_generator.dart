import 'dart:math';

class CodeGenerator {
  static final Random _random = Random.secure();

  /// Generate a 6-digit committee code
  static String generateCommitteeCode() {
    return List.generate(6, (_) => _random.nextInt(10)).join();
  }

  /// Generate a member code (NAME-4DIGITS)
  static String generateMemberCode(String memberName) {
    final cleanName = memberName
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .substring(0, memberName.length > 3 ? 3 : memberName.length);
    final digits = List.generate(4, (_) => _random.nextInt(10)).join();
    return '$cleanName-$digits';
  }
}
