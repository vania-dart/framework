import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';

abstract class SeederFactory {
  final Random _random = Random();

  @mustBeOverridden
  Map<String, dynamic> definition();

  Map<String, dynamic> make([Map<String, dynamic>? attributes]) {
    final data = definition();
    if (attributes != null) {
      data.addAll(data);
    }

    return data;
  }

  List<Map<String, dynamic>> makeMany(int count,
      [Map<String, dynamic>? attributes]) {
    return List.generate(count, (index) => make(attributes));
  }

  Map<String, dynamic> create([Map<String, dynamic>? attributes]) {
    return make(attributes);
  }

  List<Map<String, dynamic>> createMany(int count,
      [Map<String, dynamic>? attributes]) {
    return makeMany(count, attributes);
  }

  int randomInt(int min, int max) {
    return min + _random.nextInt(max - min + 1);
  }

  double randomDouble(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }

  bool randomBool() {
    return _random.nextBool();
  }

  T randomElement<T>(List<T> list) {
    if (list.isEmpty) {
      stderr.write('List cannot be empty');
      exit(0);
    }
    return list[_random.nextInt(list.length)];
  }

  String randomString(
    int length, {
    bool includeNumbers = true,
    bool includeSymbols = false,
  }) {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

    String chars = letters;
    if (includeNumbers) chars += numbers;
    if (includeSymbols) chars += symbols;

    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(_random.nextInt(chars.length))));
  }

  String randomEmail() {
    final domains = [
      'gmail.com',
      'yahoo.com',
      'hotmail.com',
      'outlook.com',
      'aol.com',
      'icloud.com',
      'protonmail.com',
      'mail.com',
      'yandex.com',
      'zoho.com',
      'gmx.com',
      'live.com',
      'msn.com',
      'fastmail.com',
      'tutanota.com'
    ];
    final username =
        randomString(8, includeNumbers: true, includeSymbols: false)
            .toLowerCase();
    final domain = randomElement(domains);
    return '$username@$domain';
  }

  String randomName() {
    final firstNames = [
      'John',
      'Jane',
      'Michael',
      'Sarah',
      'David',
      'Emily',
      'Robert',
      'Jessica',
      'William',
      'Ashley',
      'James',
      'Amanda',
      'Christopher',
      'Stephanie',
      'Daniel',
      'Melissa',
      'Matthew',
      'Nicole',
      'Anthony',
      'Elizabeth',
      'Dorothy',
      'Jerry',
      'Helen',
      'Tyler',
      'Sandra',
      'Aaron',
      'Donna',
      'Jose',
      'Carol',
      'Henry',
      'Ruth',
      'Douglas',
      'Sharon',
      'Zachary',
      'Michelle',
      'Nathan',
      'Laura',
      'Peter',
      'Sarah',
      'Kyle',
      'Kimberly',
      'Noah',
      'Deborah',
      'Jeremy',
      'Dorothy',
      'Carl',
      'Lisa',
      'Arthur',
      'Nancy',
      'Lawrence',
      'Karen',
      'Sean',
      'Betty',
      'Christian',
      'Helen',
      'Austin',
      'Sandra',
      'Wayne',
      'Donna',
      'Louis',
      'Carol',
      'Philip',
      'Ruth',
      'Eugene',
      'Sharon',
      'Ralph',
      'Michelle',
      'Roy',
      'Laura',
      'Billy',
      'Emily',
      'Bruce',
      'Kimberly',
      'Willie',
      'Deborah',
      'Jordan',
      'Amy',
      'Mason',
      'Angela',
      'Ethan',
      'Brenda',
      'Liam',
      'Emma',
      'Noah',
      'Olivia',
      'Oliver',
      'Ava',
      'Elijah',
      'Sophia',
      'Lucas',
      'Isabella',
      'Logan',
      'Mia',
      'Owen',
      'Charlotte',
      'Aiden',
      'Amelia',
      'Carter',
      'Harper',
      'Sebastian',
      'Evelyn'
    ];
    final lastNames = [
      'Smith',
      'Johnson',
      'Williams',
      'Brown',
      'Jones',
      'Garcia',
      'Miller',
      'Davis',
      'Rodriguez',
      'Martinez',
      'Hernandez',
      'Lopez',
      'Gonzalez',
      'Wilson',
      'Anderson',
      'Thomas',
      'Taylor',
      'Moore',
      'Jackson',
      'Martin',
      'Thomas',
      'Taylor',
      'Moore',
      'Jackson',
      'Martin',
      'Lee',
      'Perez',
      'Thompson',
      'White',
      'Harris',
      'Sanchez',
      'Clark',
      'Ramirez',
      'Lewis',
      'Robinson',
      'Walker',
      'Young',
      'Allen',
      'King',
      'Wright',
      'Scott',
      'Torres',
      'Nguyen',
      'Hill',
      'Flores',
      'Green',
      'Adams',
      'Nelson',
      'Baker',
      'Hall',
      'Rivera',
      'Campbell',
      'Mitchell',
      'Carter',
      'Roberts',
      'Gomez',
      'Phillips',
      'Evans',
      'Turner',
      'Diaz',
      'Parker',
      'Cruz',
      'Edwards',
      'Collins',
      'Reyes',
      'Stewart',
      'Morris',
      'Morales',
      'Murphy',
      'Cook',
      'Rogers',
      'Gutierrez',
      'Ortiz',
      'Morgan',
      'Cooper',
      'Peterson',
      'Bailey',
      'Reed',
      'Kelly',
      'Howard',
      'Ramos',
      'Kim',
      'Cox',
      'Ward',
      'Richardson',
      'Watson',
      'Brooks',
      'Chavez',
      'Wood',
      'James',
      'Bennett',
      'Gray',
      'Mendoza',
      'Ruiz',
      'Hughes',
      'Price',
      'Alvarez',
      'Castillo',
      'Sanders',
      'Patel',
      'Myers',
      'Long',
      'Ross',
      'Foster',
      'Jimenez',
      'Powell',
      'Jenkins',
      'Perry',
      'Russell',
      'Sullivan',
      'Bell',
      'Coleman',
      'Butler',
      'Henderson',
      'Barnes',
      'Gonzales',
      'Fisher',
      'Vasquez',
      'Simmons',
      'Romero',
      'Jordan',
      'Patterson',
      'Alexander',
      'Hamilton',
      'Graham',
      'Reynolds'
    ];

    return '${randomElement(firstNames)} ${randomElement(lastNames)}';
  }

  String randomPhone() {
    return '+1${randomInt(100, 999)}${randomInt(100, 999)}${randomInt(1000, 9999)}';
  }

  DateTime randomDate(DateTime start, DateTime end) {
    final diff = end.difference(start).inDays;
    final randomDays = _random.nextInt(diff + 1);
    return start.add(Duration(days: randomDays));
  }

  DateTime randomPastDate([int maxDaysAgo = 365]) {
    final now = DateTime.now();
    final daysAgo = _random.nextInt(maxDaysAgo + 1);
    return now.subtract(Duration(days: daysAgo));
  }

  DateTime randomFutureDate([int maxDaysFromNow = 365]) {
    final now = DateTime.now();
    final daysFromNow = _random.nextInt(maxDaysFromNow + 1);
    return now.add(Duration(days: daysFromNow));
  }

  String randomUuid() {
    return '${randomString(8)}-${randomString(4)}-${randomString(4)}-${randomString(4)}-${randomString(12)}';
  }

  String randomText([int sentences = 3]) {
    final words = [
      'lorem',
      'ipsum',
      'dolor',
      'sit',
      'amet',
      'consectetur',
      'adipiscing',
      'elit',
      'sed',
      'do',
      'eiusmod',
      'tempor',
      'incididunt',
      'ut',
      'labore',
      'et',
      'dolore',
      'magna',
      'aliqua',
      'enim',
      'ad',
      'minim',
      'veniam',
      'quis',
      'nostrud',
      'exercitation',
      'ullamco',
      'laboris',
      'nisi',
      'aliquip',
      'ex',
      'ea',
      'commodo',
      'consequat',
      'duis',
      'aute',
      'irure',
      'in',
      'reprehenderit',
      'voluptate',
      'velit',
      'esse',
      'cillum',
      'fugiat',
      'nulla',
      'pariatur',
      'excepteur',
      'sint',
      'occaecat',
      'cupidatat',
      'non',
      'proident',
      'sunt',
      'culpa',
      'qui',
      'officia',
      'deserunt',
      'mollit',
      'anim',
      'id',
      'est',
      'laborum'
    ];

    final result = <String>[];
    for (int i = 0; i < sentences; i++) {
      final sentenceLength = randomInt(5, 15);
      final sentence =
          List.generate(sentenceLength, (_) => randomElement(words));
      sentence[0] = sentence[0][0].toUpperCase() + sentence[0].substring(1);
      result.add('${sentence.join(' ')}.');
    }

    return result.join(' ');
  }

  double randomPrice(
      [double min = 1.0, double max = 1000.0, int decimals = 2]) {
    return double.parse(randomDouble(min, max).toStringAsFixed(decimals));
  }

  String randomStatus([List<String>? statuses]) {
    statuses ??= ['active', 'inactive', 'pending', 'completed'];
    return randomElement(statuses);
  }
}
