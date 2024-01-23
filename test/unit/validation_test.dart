import 'package:test/test.dart';
import 'package:vania/src/http/validation/validator.dart';

void main() {
  group('Validation Test', () {
    test('Validation required Test', () {
      Validator validator = Validator(data: {'name': ''});
      validator.validate({'name': 'required'});
      expect(validator.errors['name'], 'The name is required');
    });

    test('Validation integer Test', () {
      Validator validator = Validator(data: {'age': 'String'});
      validator.validate({'age': 'integer'});
      expect(validator.errors['age'], 'The age must be an integer');
    });

    test('Validation not_in', () {
      Validator validator = Validator(data: {'status': 'active'});
      validator.validate({'status': 'not_in:active,pending'});
      expect(validator.errors['status'], 'The status field cannot be active');
    });

    test('Validation start_with', () {
      Validator validator = Validator(data: {'name': 'Vania'});
      validator.validate({'name': 'start_with:_va'});
      expect(validator.errors['name'], 'The name must start with _va');
    });

    test('Validation password confirmed', () {
      Validator validator = Validator(data: {
        'password': '12345678',
        'password_confirmation': '112233445566',
      });
      validator.validate(<String, String>{'password': 'confirmed'});
      expect(validator.errors['password'], 'The two password did not match');
    });

    test('Validation required if', () {
      Validator validator = Validator(data: {
        'username': '',
        'type': 'login',
      });
      validator.validate({'username': 'required_if:type,login'});
      expect(validator.errors['username'], 'The username is required');
    });
  });
}
