import 'package:test/test.dart';
import 'package:vania/src/view_engine/processor_engine/variables_processor.dart';

/// `@{…}` escapes its output; `@!{…}` and the `raw` filter opt out.
void main() {
  final processor = VariablesProcessor();

  String render(String template, Map<String, dynamic> data) =>
      processor.parse(template, data);

  group('@{…} escapes by default', () {
    test('a script payload is neutralised', () {
      final out = render('<p>@{bio}</p>', {
        'bio': "<script>alert('xss')</script>",
      });

      expect(out, isNot(contains('<script>')));
      expect(out, contains('&lt;script&gt;'));
    });

    test('attribute-breaking payloads are escaped', () {
      final out = render('<img alt="@{name}">', {
        'name': '" onerror="alert(1)',
      });

      expect(out, isNot(contains('onerror="alert(1)"')));
      expect(out, contains('&quot;'));
    });

    test('all five dangerous characters are covered', () {
      final out = render('@{v}', {'v': '''&<>"' '''});

      expect(out, contains('&amp;'));
      expect(out, contains('&lt;'));
      expect(out, contains('&gt;'));
      expect(out, contains('&quot;'));
      expect(out, contains('&#39;'));
    });

    test('nested-path and bracket values are escaped too', () {
      expect(
        render('@{user.bio}', {
          'user': {'bio': '<b>x</b>'},
        }),
        equals('&lt;b&gt;x&lt;&#47;b&gt;'),
      );
      expect(
        render('@{posts[0]}', {
          'posts': ['<i>y</i>'],
        }),
        equals('&lt;i&gt;y&lt;&#47;i&gt;'),
      );
    });

    test('values arriving through a filter chain are still escaped', () {
      expect(
        render('@{name | uppercase}', {'name': '<b>ali</b>'}),
        isNot(contains('<b>')),
      );
    });

    test('plain text passes through untouched', () {
      expect(render('Hello @{name}', {'name': 'Ali'}), equals('Hello Ali'));
    });
  });

  group('opting out of escaping', () {
    test('@!{…} emits raw markup', () {
      expect(
        render('@!{content}', {'content': '<b>bold</b>'}),
        equals('<b>bold</b>'),
      );
    });

    test('the raw filter emits raw markup', () {
      expect(
        render('@{content | raw}', {'content': '<b>bold</b>'}),
        equals('<b>bold</b>'),
      );
    });

    test('the escape filter is explicit but equivalent to the default', () {
      expect(
        render('@{content | escape}', {'content': '<b>x</b>'}),
        equals(render('@{content}', {'content': '<b>x</b>'})),
      );
    });

    test('data cannot smuggle in raw output on its own', () {
      // A value that merely *looks* like the raw marker must still be
      // escaped — opting out has to be a template decision, never a
      // data-driven one.
      final out = render('@{v}', {'v': '<b>x</b>'});
      expect(out, isNot(contains('<b>')));
    });
  });
}
