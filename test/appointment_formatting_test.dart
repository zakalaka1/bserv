import 'package:bserv/data/appointments/appointment_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPhoneNumber', () {
    test('saves every accepted input form as 999-999-9999', () {
      const accepted = ['4165550182', '416-555-0182', '416-5550182'];
      for (final input in accepted) {
        expect(formatPhoneNumber(input), '416-555-0182');
      }
    });

    test('trims surrounding whitespace', () {
      expect(formatPhoneNumber('  416-555-0182  '), '416-555-0182');
    });

    test('is idempotent', () {
      final once = formatPhoneNumber('4165550182');
      expect(formatPhoneNumber(once), once);
    });

    test('leaves input without ten digits trimmed but otherwise untouched', () {
      expect(formatPhoneNumber(''), '');
      expect(formatPhoneNumber('  41655  '), '41655');
    });
  });

  group('formatPostalCode', () {
    test('saves every accepted input form as A9A 9A9', () {
      const accepted = ['M5V2T6', 'm5v2t6', 'M5V 2T6', 'm5v 2t6'];
      for (final input in accepted) {
        expect(formatPostalCode(input), 'M5V 2T6');
      }
    });

    test('drops separators and uppercases', () {
      expect(formatPostalCode('  m5v-2t6 '), 'M5V 2T6');
    });

    test('is idempotent', () {
      final once = formatPostalCode('m5v2t6');
      expect(formatPostalCode(once), once);
    });

    test('leaves input without six characters trimmed and uppercased', () {
      expect(formatPostalCode(''), '');
      expect(formatPostalCode('  m5v '), 'M5V');
    });
  });
}
