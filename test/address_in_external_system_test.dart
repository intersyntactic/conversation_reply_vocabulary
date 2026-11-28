import 'package:is_conversation_vocabulary/is_conversation_vocabulary.dart';
import 'package:test/test.dart';

AddressInExternalSystem _address(String s) => AddressInExternalSystem.parse(s)!;

void main() {
  group('AddressInExternalSystem.parse', () {
    for (final valid in [
      'teams:19:abc@thread.v2',
      'slack:C123',
      'whats-app2:+61400000000',
    ]) {
      test('reads $valid', () {
        expect(AddressInExternalSystem.parse(valid)?.value, valid);
      });
    }

    for (final invalid in [
      '',
      'slack',
      'slack:',
      ':C123',
      'Slack:C123',
      '1slack:C123',
      'sl_ack:C123',
      'slack:C 123',
      'slack:C123\n',
      'slack:Ç123',
    ]) {
      test('refuses ${Uri.encodeComponent(invalid)}', () {
        expect(AddressInExternalSystem.parse(invalid), isNull);
      });
    }
  });

  test('equal by value, and prints as its value', () {
    expect(_address('slack:C1'), _address('slack:C1'));
    expect(_address('slack:C1').hashCode, _address('slack:C1').hashCode);
    expect(_address('slack:C1'), isNot(_address('slack:C2')));
    expect('${_address('slack:C1')}', 'slack:C1');
  });

  group('missionAddress', () {
    test('is the containing address when there is one', () {
      expect(
        missionAddress(
          address: _address('slack:C1/1700000000.000100'),
          containingAddress: _address('slack:C1'),
        ),
        _address('slack:C1'),
      );
    });

    test('is the address itself when it sits inside none', () {
      expect(
        missionAddress(
          address: _address('teams:19:a@chat'),
          containingAddress: null,
        ),
        _address('teams:19:a@chat'),
      );
    });
  });
}
