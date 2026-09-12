class ApiSchema {
  final String name;
  final String? description;
  final String type;
  final List<ApiProperty> properties;
  final dynamic example;
  final List<Type> oneOf;
  final List<Type> anyOf;
  final List<Type> allOf;
  final bool nullable;
  final Map<String, dynamic> extensions;

  const ApiSchema({
    this.name = '',
    this.description,
    this.type = 'object',
    this.properties = const [],
    this.example,
    this.oneOf = const [],
    this.anyOf = const [],
    this.allOf = const [],
    this.nullable = false,
    this.extensions = const {},
  });
}

class ApiProperty {
  final String name;
  final String? description;
  final String? type;
  final String? format;
  final bool required;
  final dynamic example;
  final List<dynamic>? examples;
  final List<String>? enumValues;
  final String? ref;
  final bool isArray;
  final ApiProperty? items;
  final bool nullable;
  final bool deprecated;
  final bool readOnly;
  final bool writeOnly;
  final dynamic defaultValue;
  final num? minimum;
  final num? maximum;
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final Map<String, dynamic> extensions;

  const ApiProperty({
    this.name = '',
    this.description,
    this.type,
    this.format,
    this.required = false,
    this.example,
    this.examples,
    this.enumValues,
    this.ref,
    this.isArray = false,
    this.items,
    this.nullable = false,
    this.deprecated = false,
    this.readOnly = false,
    this.writeOnly = false,
    this.defaultValue,
    this.minimum,
    this.maximum,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.extensions = const {},
  });

  ApiProperty copyWith({
    String? name,
    String? description,
    String? type,
    String? format,
    bool? required,
    dynamic example,
    List<dynamic>? examples,
    List<String>? enumValues,
    String? ref,
    bool? isArray,
    ApiProperty? items,
    bool? nullable,
    bool? deprecated,
    bool? readOnly,
    bool? writeOnly,
    dynamic defaultValue,
    num? minimum,
    num? maximum,
    int? minLength,
    int? maxLength,
    String? pattern,
    Map<String, dynamic>? extensions,
  }) {
    return ApiProperty(
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      format: format ?? this.format,
      required: required ?? this.required,
      example: example ?? this.example,
      examples: examples ?? this.examples,
      enumValues: enumValues ?? this.enumValues,
      ref: ref ?? this.ref,
      isArray: isArray ?? this.isArray,
      items: items ?? this.items,
      nullable: nullable ?? this.nullable,
      deprecated: deprecated ?? this.deprecated,
      readOnly: readOnly ?? this.readOnly,
      writeOnly: writeOnly ?? this.writeOnly,
      defaultValue: defaultValue ?? this.defaultValue,
      minimum: minimum ?? this.minimum,
      maximum: maximum ?? this.maximum,
      minLength: minLength ?? this.minLength,
      maxLength: maxLength ?? this.maxLength,
      pattern: pattern ?? this.pattern,
      extensions: extensions ?? this.extensions,
    );
  }
}

class ApiExtension {
  final String key;
  final dynamic value;

  const ApiExtension({required this.key, required this.value});
}
