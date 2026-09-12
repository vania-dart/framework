---
sidebar_position: 7
---

# Views & Templates

Vania includes a template engine with a clean, directive-based syntax. Templates are plain HTML files with embedded directives for variables, control flow, layouts, and more.

## Rendering a View

From a controller, use the `view()` helper:

```dart
import 'package:vania/http/response.dart';

Future<Response> welcome() async {
  return view('welcome', {'name': 'Alice', 'role': 'admin'});
}
```

This looks for the file `views/welcome.html` in your project root, processes it through the template engine, and returns an HTML response.

## Variables

Output variables with double curly braces:

```html
<h1>Hello, {{ name }}</h1>
<p>Your role is {{ role }}</p>
```

Variables are automatically escaped. To output raw HTML, the template engine processes the variables as-is from the passed data map.

## Control Structures

### If Statements

```html
@if(role == 'admin')
  <p>Welcome, administrator.</p>
@elseif(role == 'editor')
  <p>Welcome, editor.</p>
@else
  <p>Welcome, visitor.</p>
@endif
```

### Switch Statements

```html
@switch(status)
  @case('active')
    <span class="badge green">Active</span>
    @break
  @case('inactive')
    <span class="badge gray">Inactive</span>
    @break
  @default
    <span class="badge">Unknown</span>
@endswitch
```

### Loops

```html
@for(item in items)
  <li>{{ item.name }} - {{ item.price }}</li>
@endfor
```

## Layouts and Sections

### Defining a Layout

Create a layout file at `views/layouts/app.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <title>@yield('title') - My App</title>
  @yield('head')
</head>
<body>
  <nav><!-- navigation --></nav>

  <main>
    @yield('content')
  </main>

  <footer><!-- footer --></footer>
  @yield('scripts')
</body>
</html>
```

### Extending a Layout

In a child template:

```html
@extends('layouts/app')

@section('title')
  Dashboard
@endsection

@section('content')
  <h1>Dashboard</h1>
  <p>Hello, {{ name }}</p>
@endsection

@section('scripts')
  <script src="/js/dashboard.js"></script>
@endsection
```

## Includes

Pull in a partial template:

```html
@include('partials/sidebar')
@include('partials/alert', {'type': 'success', 'message': 'Saved!'})
```

## CSRF Protection

In forms, include the CSRF token field:

```html
<form method="POST" action="/submit">
  @csrf
  <input type="text" name="title">
  <button type="submit">Submit</button>
</form>
```

Or get the raw token value:

```html
<meta name="csrf-token" content="@csrfToken">
```

## Assets

Reference static assets from the `public/` directory:

```html
<link rel="stylesheet" href="@asset('css/app.css')">
<script src="@asset('js/app.js')"></script>
<img src="@asset('images/logo.png')">
```

## Old Input

After a validation redirect, display the previously submitted value:

```html
<input type="text" name="email" value="@old('email')">
```

## Session Data

Access session values in templates:

```html
@if(session('flash_message'))
  <div class="alert">{{ session('flash_message') }}</div>
@endif
```

## Error Display

Show validation errors for a specific field:

```html
@error('email')
  <span class="error">{{ message }}</span>
@enderror
```

## Comments

Template comments are stripped from the output:

```html
{{-- This comment will not appear in the rendered HTML --}}
```

## Translations

If localization is configured:

```html
<p>@translate('welcome.greeting')</p>
```

## Named Routes in Templates

Generate URLs for named routes:

```html
<a href="@route('user.show', {'id': 42})">View Profile</a>
```
