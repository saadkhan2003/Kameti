import 'package:flutter_test/flutter_test.dart';
import 'package:committee_app/core/utils/code_generator.dart';

void main() {
  group('CodeGenerator', () {
    test('generateCommitteeCode returns a 6-digit string', () {
      final code = CodeGenerator.generateCommitteeCode();
      expect(code, isA<String>());
      expect(code.length, 6);
      expect(int.tryParse(code), isNotNull);
    });

    test('generateMemberCode returns formatted string (NAME-DIGITS)', () {
      final code = CodeGenerator.generateMemberCode('Farhan');
      // Should be FAR-XXXX
      expect(code, startsWith('FAR-'));
      expect(code.length, 8); // FAR (3) + '-' (1) + 4 digits (4) = 8
    });

    test('generateMemberCode handles short names', () {
      final code = CodeGenerator.generateMemberCode('Jo');
      expect(code, startsWith('JO-'));
      expect(code.length, 7); // JO (2) + '-' (1) + 4 digits (4) = 7
    });

    test('generateMemberCode cleans name from special characters', () {
      final code = CodeGenerator.generateMemberCode('J. Doe');
      // "J. Doe" -> "JDOE" -> "JDO-XXXX"
      expect(code, startsWith('JDO-'));
    });
  });
}
