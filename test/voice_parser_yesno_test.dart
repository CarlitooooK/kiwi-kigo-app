import 'package:flutter_test/flutter_test.dart';
import 'package:kiwi_kigo/features/voice/data/voice_parser.dart';

void main() {
  group('VoiceParser.yesNo', () {
    test('"incorrecto" is NO (not confused with "correcto")', () {
      expect(VoiceParser.yesNo('incorrecto'), isFalse);
      expect(VoiceParser.yesNo('es incorrecto'), isFalse);
      expect(VoiceParser.yesNo('no, incorrecto'), isFalse);
    });

    test('"correcto" is YES', () {
      expect(VoiceParser.yesNo('correcto'), isTrue);
      expect(VoiceParser.yesNo('sí, correcto'), isTrue);
    });

    test('plain yes/no', () {
      expect(VoiceParser.yesNo('sí'), isTrue);
      expect(VoiceParser.yesNo('si'), isTrue);
      expect(VoiceParser.yesNo('no'), isFalse);
    });

    test('phrases', () {
      expect(VoiceParser.yesNo('así es'), isTrue);
      expect(VoiceParser.yesNo('está bien'), isTrue);
      expect(VoiceParser.yesNo('está mal'), isFalse);
      expect(VoiceParser.yesNo('equivocado'), isFalse);
    });

    test('unclear returns null', () {
      expect(VoiceParser.yesNo('tal vez'), isNull);
      expect(VoiceParser.yesNo('no sé'), isFalse); // contains "no"
    });
  });

  group('VoiceParser.phone', () {
    test('digits said as words → 10 digits', () {
      expect(VoiceParser.phone('dos dos uno ocho tres ocho cero cuatro cinco uno'),
          '2218380451');
    });

    test('numerals with spaces/dashes', () {
      expect(VoiceParser.phone('221 838 0451'), '2218380451');
      expect(VoiceParser.phone('mi número es 2218380451'), '2218380451');
    });

    test('drops leading country code, keeps last 10', () {
      expect(VoiceParser.phone('52 221 838 0451'), '2218380451');
    });

    test('too short / invalid → null', () {
      expect(VoiceParser.phone('uno dos tres'), isNull);
      expect(VoiceParser.phone('hola'), isNull);
    });
  });
}
