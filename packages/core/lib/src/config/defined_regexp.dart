final ipRegExp = RegExp(
  r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
);
final alphaDashRegExp = RegExp(r'^[a-zA-Z-_]+$');

final alphaNumericRegExp = RegExp(r'^[a-zA-Z0-9]+$');

final alphaRegExp = RegExp(r'^[a-zA-Z]+$');

final emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

final uuidRegExp = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
