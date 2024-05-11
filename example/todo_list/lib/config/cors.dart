import 'package:vania/vania.dart';

CORSConfig cors = CORSConfig(
  /// Enabled
  /// -------------------------------
  /// A boolean to enable or disable CORS integration.
  /// Setting to true will enable the CORS for all HTTP request.
  enabled: true,

  /// Origin
  /// -------------------------------
  /// Set a list of origins to be allowed for `Access-Control-Allow-Origin`.
  /// The value can be one of the following:
  /// Array       : An array of allowed origins.
  /// String      : Comma separated list of allowed origins.
  /// String (*)  : A wildcard (*) to allow all request origins.
  origin: '*',

  /// Methods
  /// -------------------------------
  /// Set a list of origins to be allowed for `Access-Control-Request-Method`.
  /// The value can be one of the following:
  /// Array       : An array of request methods.
  /// String      : Comma separated list of request methods.
  /// String (*)  : A wildcard (*) to allow all request methods.
  methods: '*',

  /// Headers
  /// -------------------------------
  /// Set a list of origins to be allowed for `Access-Control-Allow-Headers`.
  /// The value can be one of the following:
  /// Array       : An array of allowed headers.
  /// String      : Comma separated list of allowed headers.
  /// String (*)  : A wildcard (*) to allow all request headers.
  headers: '*',

  /// Expose Headers
  /// -------------------------------
  /// Set a list of origins to be allowed for `Access-Control-Expose-Headers`.
  /// The value can be one of the following:
  /// Array       : An array of expose headers.
  /// String      : Comma separated list of expose headers.
  exposeHeaders: <String>[
    'cache-control',
    'content-language',
    'content-type',
    'expires',
    'last-modified',
    'pragma',
  ],

  /// Credentials
  /// -------------------------------
  /// Toggle `Access-Control-Allow-Credentials` header.
  credentials: true,

  /// MaxAge
  /// -------------------------------
  /// Define `Access-Control-Max-Age` header in seconds.
  maxAge: 90,
);
