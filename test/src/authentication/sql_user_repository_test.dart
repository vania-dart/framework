import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:vania/src/authentication/model/personal_access_token.dart';
import 'package:vania/src/authentication/sql_user_repository.dart';
import 'package:vania/vania.dart';

import 'sql_user_repository.mocks.dart';

@GenerateMocks([PersonalAccessTokens, QueryBuilder])
void main() {
  group('SqlUserRepository Tests', () {
    late MockPersonalAccessTokens mockPersonalAccessTokens;
    late SqlUserRepository repository;
    late MockQueryBuilder mockQuery;
    setUp(() {
      mockPersonalAccessTokens = MockPersonalAccessTokens();
      repository = SqlUserRepository(mockPersonalAccessTokens);
      mockQuery = MockQueryBuilder();
    });

    test('storeToken inserts the correct data', () async {
      when(mockPersonalAccessTokens.query()).thenReturn(mockQuery);
      when(mockQuery.insert({
        'name': 'default',
        'tokenable_id': 'user123',
        'token': md5.convert(utf8.encode('token123')),
        'created_at': DateTime.parse('2022-01-01T12:00:00Z'),
      })).thenAnswer((_) async => null);

      await repository.storeToken(
          name: 'default',
          userId: 'user123',
          token: 'token123',
          createdAt: DateTime.parse('2022-01-01T12:00:00Z'));

      verify(mockPersonalAccessTokens.query()).called(1);
      verify(mockQuery.insert({
        'name': 'default',
        'tokenable_id': 'user123',
        'token': md5.convert(utf8.encode(
            'token123')), // Here we assume the token is hashed inside the method
        'created_at': DateTime.parse('2022-01-01T12:00:00Z'),
      })).called(1);
    });

    test('findUserByToken queries with correct conditions', () async {
      when(mockPersonalAccessTokens.query()).thenReturn(mockQuery);
      when(mockQuery.where('token', '=', md5.convert(utf8.encode('token123'))))
          .thenReturn(mockQuery);
      when(mockQuery.whereNull('deleted_at')).thenReturn(mockQuery);
      when(mockQuery.first(['id'])).thenAnswer((_) async => {'id': 'user123'});

      var result = await repository.findUserByToken('token123');
      expect(result, contains('id'));

      verify(mockPersonalAccessTokens.query()).called(1);
      verify(mockQuery.where(
              'token', '=', md5.convert(utf8.encode('token123'))))
          .called(1);
      verify(mockQuery.whereNull('deleted_at')).called(1);
    });
    test('deleteTokenById updates the correct tokens', () async {
      when(mockPersonalAccessTokens.query()).thenReturn(mockQuery);
      when(mockQuery.where('tokenable_id', '=', 'user123'))
          .thenReturn(mockQuery);
      // Correctly specify named argument for the update call
      when(mockQuery
              .update({'deleted_at': DateTime.parse('2022-01-01T12:00:00Z')}))
          .thenAnswer((_) async => null);

      await repository.deleteTokenById(
          'user123', DateTime.parse('2022-01-01T12:00:00Z'));

      verify(mockPersonalAccessTokens.query()).called(1);
      verify(mockQuery.where('tokenable_id', '=', 'user123')).called(1);
      // Ensure the named argument matcher is used correctly
      verify(mockQuery.update(
        argThat(equals({'deleted_at': DateTime.parse('2022-01-01T12:00:00Z')})),
      )).called(1);
    });

    test('deleteTokenByToken updates the correct token', () async {
      final hashedToken = md5.convert(utf8.encode('token123'));

      when(mockPersonalAccessTokens.query()).thenReturn(mockQuery);
      when(mockQuery.where('token', '=', hashedToken)).thenReturn(mockQuery);
      // Correctly specify named argument for the update call
      when(mockQuery
              .update({'deleted_at': DateTime.parse('2022-01-01T12:00:00Z')}))
          .thenAnswer((_) async => null);

      await repository.deleteTokenByToken(
          'token123', DateTime.parse('2022-01-01T12:00:00Z'));

      verify(mockPersonalAccessTokens.query()).called(1);
      verify(mockQuery.where('token', '=', hashedToken)).called(1);
      // Ensure the named argument matcher is used correctly
      verify(mockQuery.update(
        argThat(equals({'deleted_at': DateTime.parse('2022-01-01T12:00:00Z')})),
      )).called(1);
    });
  });
}
