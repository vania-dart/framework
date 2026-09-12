## 1.0.0

First release. `vania_auth` is now the framework's only authentication surface —
the equivalent code was removed from `vania` core in 2.0.0.

- Requires `vania` 2.0.0.
- JWT guards, `Auth()`, personal access tokens, and an ORM-backed
  `PersonalAccessTokenStore` implementing core's single token contract.
- `Authenticate` and `RedirectIfAuthenticated` are concrete `Middleware`
  classes, so they drop into any `Router.get(...).middleware([...])` chain.
- `AuthServiceProvider` installs a request user resolver, so `req.user` keeps
  working even though core no longer knows what a user is.
- `Gate` re-exports core's registry, so `Auth().authorize()` and the global
  `can()` / `cannot()` helpers consult the same policies.

### Upgrading from Vania 1.x

Add this package, then import `Auth`, `Authenticate`, and
`RedirectIfAuthenticated` from `package:vania_auth/vania_auth.dart` instead of
`package:vania/vania.dart`.
