enum HttpRequestMethod {
  get,
  post,
  put,
  patch,
  delete,
  purge,
  options,
  copy,
  view,
  link,
  unlink,
  lock,
  unlock,
  propfind,

  /// A safe, idempotent query carried in the request content (RFC 10008).
  query,
}
