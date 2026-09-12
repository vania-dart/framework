import 'dart:async';
import 'package:vania/src/ioc_container.dart';
import 'package:vania/src/http/session/flash_messages.dart';

import 'package:vania/src/view_engine/processor_engine/abs_processor.dart';
import 'package:vania/src/view_engine/processor_engine/variables_processor.dart';

import 'processor_engine/assets_processor.dart';
import 'processor_engine/comment_processor.dart';
import 'processor_engine/csrf_processor.dart';
import 'processor_engine/csrf_token_processor.dart';
import 'processor_engine/error_processor.dart';
import 'processor_engine/if_statement_processor.dart';
import 'processor_engine/extends_processor.dart';
import 'processor_engine/for_loop_processor.dart';
import 'processor_engine/include_processor.dart';
import 'processor_engine/old_processor.dart';
import 'processor_engine/route_processor.dart';
import 'processor_engine/section_processor.dart';
import 'processor_engine/session_processor.dart';
import 'processor_engine/switch_cases_processor.dart';
import 'processor_engine/translate_processor.dart';
import 'template_reader.dart';

class _TemplateProcessingPipeline {
  final List<AbsProcessor> _processors;

  const _TemplateProcessingPipeline(this._processors);

  String run(String content, Map<String, dynamic> data) {
    for (final processor in _processors) {
      content = processor.parse(content, data);
    }
    return content;
  }
}

class TemplateEngine {
  TemplateEngine.createDefault();

  factory TemplateEngine() => IoCContainer().resolveOrDefault<TemplateEngine>(
    TemplateEngine.createDefault,
  );

  final SectionProcessor _sectionProcessor = SectionProcessor();

  late final _TemplateProcessingPipeline _pipeline =
      _TemplateProcessingPipeline([
        ExtendsProcessor(),
        _sectionProcessor,
        ErrorProcessor(),
        SessionProcessor(),
        ForLoopProcessor(),
        SwitchCasesProcessor(),
        IfStatementProcessor(),
        VariablesProcessor(),
        CsrfProcessor(),
        CsrfTokenProcessor(),
        OldProcessor(),
        TranslateProcessor(),
        CommentProcessor(),
        RouteProcessor(),
        AssetsProcessor(),
        IncludeProcessor(),
      ]);

  /// Validation errors for the current request.
  @Deprecated('Use FlashMessages().errors instead.')
  Map<String, dynamic> get sessionErrors => FlashMessages().errors;

  /// Submitted input for the current request, used to repopulate forms.
  @Deprecated('Use FlashMessages().old instead.')
  Map<String, dynamic> get formData => FlashMessages().old;

  /// Flash messages for the current request.
  @Deprecated('Use FlashMessages().messages instead.')
  Map<String, dynamic> get sessions => FlashMessages().messages;

  /// Runs [body] with a fresh, isolated set of flash/error/old buckets.
  @Deprecated('Use FlashMessages.runIsolated instead.')
  static Future<T> runInRequestZone<T>({
    required Future<T> Function() body,
    Map<String, dynamic>? errors,
    Map<String, dynamic>? flash,
    Map<String, dynamic>? oldInput,
  }) => FlashMessages.runIsolated(
    body: body,
    errors: errors,
    flash: flash,
    oldInput: oldInput,
  );

  String render(String template, [Map<String, dynamic>? data]) {
    final templateContent = FileTemplateReader().read(template);
    final rendered = renderString(templateContent, data);
    FlashMessages().clear();
    return rendered;
  }

  /// Renders a template string with the provided data context.
  String renderString(String templateContent, [Map<String, dynamic>? data]) {
    final merged = <String, dynamic>{
      ...?data,
      ..._sectionProcessor.parseChildSections(templateContent),
    };
    return _pipeline.run(templateContent, merged);
  }
}
