import 'dart:convert';

/// Serves a GraphiQL 3 UI backed by the app's `/graphql` endpoint.
///
/// Uses the real GraphiQL bundle from unpkg (offline dev without internet
/// falls back to a minimal home-rolled UI via [renderMinimal]). Includes a
/// subscription client wired to the app's `/graphql/ws` endpoint so
/// subscriptions work with clicks, not just POSTs.
class GraphiQLPage {
  const GraphiQLPage._();

  static String render({
    required String endpoint,
    String? subscriptionsEndpoint,
  }) {
    final subs = subscriptionsEndpoint == null
        ? 'null'
        : jsonEncode(subscriptionsEndpoint);
    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Vania GraphQL</title>
  <link rel="stylesheet" href="https://unpkg.com/graphiql@3/graphiql.min.css" />
  <style>html,body,#graphiql{height:100%;margin:0}</style>
</head>
<body>
  <div id="graphiql">Loading&hellip;</div>
  <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
  <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
  <script crossorigin src="https://unpkg.com/graphql-ws@5/umd/graphql-ws.min.js"></script>
  <script crossorigin src="https://unpkg.com/graphiql@3/graphiql.min.js"></script>
  <script>
    const endpoint = ${jsonEncode(endpoint)};
    const subsEndpoint = $subs;
    const wsUrl = subsEndpoint
      ? (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + subsEndpoint
      : null;
    const wsClient = wsUrl && window.graphqlWs
      ? window.graphqlWs.createClient({ url: wsUrl })
      : null;
    const fetcher = GraphiQL.createFetcher({
      url: endpoint,
      wsClient: wsClient || undefined,
    });
    ReactDOM.createRoot(document.getElementById('graphiql'))
      .render(React.createElement(GraphiQL, { fetcher }));
  </script>
</body>
</html>
''';
  }

  /// A minimal, dependency-free fallback UI. Same textarea + pre layout as
  /// the previous package versions; kept for offline dev.
  static String renderMinimal({required String endpoint}) {
    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Vania GraphQL (minimal)</title>
  <style>
    body { margin: 0; font-family: system-ui, sans-serif; background: #101418; color: #e7edf3; }
    main { display: grid; grid-template-columns: 1fr 1fr; min-height: 100vh; }
    textarea, pre { box-sizing: border-box; width: 100%; height: calc(100vh - 72px); margin: 0; padding: 20px; border: 0; outline: 0; font: 14px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; }
    textarea { background: #151b22; color: #e7edf3; resize: none; }
    pre { background: #0b0f14; overflow: auto; white-space: pre-wrap; }
    header { height: 72px; display: flex; align-items: center; justify-content: space-between; padding: 0 16px; background: #17202a; border-bottom: 1px solid #263241; }
    button { border: 0; background: #3ca6ff; color: #04121f; font-weight: 700; padding: 10px 16px; cursor: pointer; }
  </style>
</head>
<body>
  <header>
    <strong>Vania GraphQL (minimal)</strong>
    <button id="run">Run</button>
  </header>
  <main>
    <textarea id="query">query {
  __typename
}</textarea>
    <pre id="result"></pre>
  </main>
  <script>
    const endpoint = ${jsonEncode(endpoint)};
    const button = document.getElementById('run');
    const query = document.getElementById('query');
    const result = document.getElementById('result');
    async function run() {
      button.disabled = true;
      try {
        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {'content-type': 'application/json', 'accept': 'application/json'},
          body: JSON.stringify({query: query.value})
        });
        const json = await response.json();
        result.textContent = JSON.stringify(json, null, 2);
      } catch (error) {
        result.textContent = String(error);
      } finally {
        button.disabled = false;
      }
    }
    button.addEventListener('click', run);
  </script>
</body>
</html>
''';
  }
}
