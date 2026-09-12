---
sidebar_position: 6
---

# Validation

Vania provides three approaches to request validation: string-based rules, fluent field validation, and chain-based validation objects. All three throw a `ValidationException` on failure, which the framework catches and returns as a structured error response.

## String-Based Rules

The quickest way to validate. Pass a map of field names to pipe-delimited rule strings:

```dart
req.validate({
  'name': 'required|string|max_length:100',
  'email': 'required|email|unique:users',
  'age': 'required|integer|between:18,120',
  'password': 'required|min_length:8|confirmed',
});
```

### Available Rules

| Rule | Description | Example |
|------|-------------|---------|
| `required` | Field must be present and non-empty | `'required'` |
| `string` | Must be a string | `'string'` |
| `numeric` | Must be numeric | `'numeric'` |
| `integer` | Must be an integer | `'integer'` |
| `double` | Must be a double | `'double'` |
| `boolean` | Must be a boolean | `'boolean'` |
| `email` | Valid email format | `'email'` |
| `url` | Valid URL format | `'url'` |
| `uuid` | Valid UUID format | `'uuid'` |
| `ip` | Valid IP address | `'ip'` |
| `date` | Valid date | `'date'` |
| `alpha` | Letters only | `'alpha'` |
| `alpha_dash` | Letters, numbers, dashes, underscores | `'alpha_dash'` |
| `alpha_numeric` | Letters and numbers | `'alpha_numeric'` |
| `json` | Valid JSON string | `'json'` |
| `array` | Must be a list | `'array'` |
| `min_length:n` | Minimum string length | `'min_length:8'` |
| `max_length:n` | Maximum string length | `'max_length:255'` |
| `length_between:min,max` | String length range | `'length_between:3,50'` |
| `min:n` | Minimum numeric value | `'min:0'` |
| `max:n` | Maximum numeric value | `'max:100'` |
| `between:min,max` | Numeric value range | `'between:1,100'` |
| `greater_than:n` | Greater than value | `'greater_than:0'` |
| `less_than:n` | Less than value | `'less_than:1000'` |
| `in:a,b,c` | Value must be in list | `'in:draft,published,archived'` |
| `not_in:a,b,c` | Value must not be in list | `'not_in:admin,root'` |
| `confirmed` | Field must have matching `{field}_confirmation` | `'confirmed'` |
| `start_with:prefix` | Must start with string | `'start_with:http'` |
| `end_with:suffix` | Must end with string | `'end_with:.com'` |
| `unique:table` | Must not exist in DB table | `'unique:users'` |
| `unique:table,column` | Check specific column | `'unique:users,email'` |
| `file` | Must be an uploaded file | `'file'` |
| `image` | Must be an image file | `'image'` |
| `reg_exp:pattern` | Must match regex | `'reg_exp:^[A-Z]{2}[0-9]{4}$'` |
| `required_if:field,value` | Required when another field equals value | `'required_if:type,premium'` |
| `required_if_not:field,value` | Required when another field doesn't equal value | `'required_if_not:type,free'` |

### Nested Validation

Use dot notation for nested objects and `*` for array items:

```dart
req.validate({
  'address.street': 'required|string',
  'address.city': 'required|string',
  'address.zip': 'required|string|min_length:5',
  'tags': 'required|array',
  'tags.*': 'string|max_length:50',
  'items.*.name': 'required|string',
  'items.*.quantity': 'required|integer|min:1',
});
```

### Custom Error Messages

Override the default error messages:

```dart
req.validate({
  'email': 'required|email',
  'password': 'required|min_length:8',
}, {
  'email.required': 'We need your email address.',
  'email.email': 'That does not look like a valid email.',
  'password.min_length': 'Password must be at least 8 characters.',
});
```

## Fluent Field Validation

A type-safe alternative using method chaining:

```dart
req.validate([
  FieldValidation('name').required().string().maxLength(100),
  FieldValidation('email').required().email().unique('users'),
  FieldValidation('age').required().integer().between(18, 120),
  FieldValidation('password').required().minLength(8).confirmed(),
]);
```

Each method on `FieldValidation` accepts an optional custom message parameter:

```dart
FieldValidation('email')
    .required(message: 'Email is required')
    .email(message: 'Invalid email format')
    .unique('users', message: 'This email is already registered');
```

## Chain-Based Validation

For more complex validation logic, use `Validation` objects with explicit `ValidationRule` instances:

```dart
import 'package:vania/http/request.dart';

req.validate([
  Validation(
    field: 'email',
    rules: [IsRequired(), IsEmail(), MaxLength(255)],
  ),
  Validation(
    field: 'role',
    rules: [IsRequired(), InArray(['admin', 'editor', 'viewer'])],
  ),
]);
```

Available rule classes include: `IsRequired`, `IsEmail`, `IsUrl`, `IsUuid`, `IsIp`, `IsString`, `IsInteger`, `IsDouble`, `IsBoolean`, `IsDate`, `IsAlpha`, `IsAlphaNumeric`, `IsAlphaDash`, `MinVal`, `MaxVal`, `Between`, `GreaterThan`, `LessThan`, `MinLength`, `MaxLength`, `LengthBetween`, `InArray`, `NotInArray`, `Confirmed`, `StartWith`, `EndWith`, `IsFile`, `IsImage`, `IsJson`, `IsArray`, `RequiredIf`, `RequiredIfNot`.

## Form Validation Objects

For reusable validation, create a dedicated form validation class:

```dart
import 'package:vania/http/form_validation.dart';

class CreatePostValidation extends FormValidation {
  @override
  Map<String, String> rules() => {
    'title': 'required|string|max_length:255',
    'body': 'required|string',
    'category_id': 'required|integer',
  };

  @override
  Map<String, String> messages() => {
    'title.required': 'Every post needs a title.',
    'body.required': 'The post body cannot be empty.',
  };

  @override
  bool authorize() => true;
}
```

Use it in your controller:

```dart
Future<Response> store(Request req) async {
  req.validate(CreatePostValidation());

  // Validation passed
  final post = await Post().query.create(req.only(['title', 'body', 'category_id']));
  return Response.json(post, 201);
}
```

The `authorize()` method can return `false` to reject the request with a 403 before validation runs.

## Custom Validation Rules

Define rules with custom logic:

```dart
req.setCustomRule([
  CustomValidationRule(
    ruleName: 'strong_password',
    message: 'Password must contain uppercase, lowercase, number, and special character.',
    fn: (data, value, param) async {
      if (value is! String) return false;
      return RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$')
          .hasMatch(value);
    },
  ),
]);

req.validate({
  'password': 'required|strong_password',
});
```

## Validation Error Response

When validation fails, the framework returns a `422` response with this structure:

```json
{
  "message": "Validation failed",
  "errors": {
    "email": ["The email field is required."],
    "password": ["The password must be at least 8 characters."]
  }
}
```

For HTML requests (web routes), the user is redirected back with errors and old input available in the session.
