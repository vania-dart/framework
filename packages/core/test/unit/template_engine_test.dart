import 'dart:async';

import 'package:test/test.dart';
import 'package:vania/src/view_engine/template_engine.dart';

void main() {
  group('TemplateEngine concurrency', () {
    test(
      'concurrent renders do not bleed sessionErrors across requests',
      () async {
        const tpl = "{@ error('name') @}";

        Future<String> renderWithErrors(Map<String, String> errs) async {
          return TemplateEngine.runInRequestZone(
            errors: errs,
            body: () async {
              await Future<void>.delayed(const Duration(milliseconds: 5));
              return TemplateEngine().renderString(tpl);
            },
          );
        }

        final results = await Future.wait([
          renderWithErrors({'name': 'AAA'}),
          renderWithErrors({'name': 'BBB'}),
        ]);
        expect(results, containsAll(['AAA', 'BBB']));
      },
    );

    test(
      'errors set inside one zone are invisible to an outer render call',
      () async {
        const tpl = "{@ error('name') @}";
        await TemplateEngine.runInRequestZone(
          errors: {'name': 'INNER'},
          body: () async {
            expect(TemplateEngine().renderString(tpl), equals('INNER'));
          },
        );
        expect(TemplateEngine().renderString(tpl), equals(''));
      },
    );
  });
}
