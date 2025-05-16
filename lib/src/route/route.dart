import 'package:meta/meta.dart';
import 'router.dart';

class Route {
  String? get prefix => null;
  @mustBeOverridden
  @mustCallSuper
  void register() {
    Router.basePrefix(prefix);
  }
}
