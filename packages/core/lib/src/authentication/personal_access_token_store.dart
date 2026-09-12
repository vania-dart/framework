// Backwards-compat shim. The single source of truth for the token store
// contract now lives in `lib/src/contract/http/personal_access_token_store.dart`
// (exported by `package:vania/vania.dart`). This file keeps existing
// imports of `package:vania/src/authentication/personal_access_token_store.dart`
// resolving to the same type.
export 'package:vania/src/contract/http/personal_access_token_store.dart';
