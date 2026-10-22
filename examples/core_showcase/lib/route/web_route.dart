import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:vania/route.dart';
import 'package:vania/vania.dart'
    show
        InternalServerError,
        PageExpiredException,
        destroyAllSessions,
        regenerateSession,
        setSession;

import '../app/middleware.dart';

/// Pages: sessions, CSRF, forms, flash messages and error pages.
class WebRoute extends Route {
  @override
  void register() {
    super.register();

    // The page that runs the browser checks.
    Router.get('/console', () => view('console'));

    // A form: CSRF token, validation errors, old input, a flash message.
    Router.get('/form', () => view('form'));
    Router.post('/form', (Request req) async {
      await req.validate({'name': 'required', 'email': 'required|email'});
      return Response.back('status', 'Saved — thank you!');
    });

    // Signing in moves the session to a new id.
    Router.get(
      '/login',
      (Request req) => view('login', {'sid': _sessionId(req)}),
    );
    Router.post('/login', (Request req) async {
      await regenerateSession();
      await setSession('logged_in', true);
      return Response.redirect('/dashboard');
    });
    Router.get(
      '/dashboard',
      (Request req) => view('dashboard', {'sid': _sessionId(req)}),
    ).middleware([SessionGuard()]);
    Router.post('/logout', () async {
      await destroyAllSessions();
      return Response.redirect('/login');
    });

    // State-changing routes behind CSRF protection.
    Router.delete('/items/{id}', (int id) => Response.json({'deleted': id}));
    Router.post('/webhooks/stripe', () => Response.json({'received': true}));
    Router.post('/webhooks-admin/purge', () => Response.json({'purged': true}));

    // Error pages, each with its own status.
    Router.get('/boom', () => throw InternalServerError(message: 'x'));
    Router.get('/expired', () => throw PageExpiredException());

    Router.get('/back', () => Response.back());
  }

  /// The session id the browser sent with this request.
  static String _sessionId(Request req) =>
      req.cookie<String>('showcase_session') ?? '(none yet)';
}
