import 'package:vania_grpc/vania_grpc.dart';
import 'package:grpc_greeter/greeter/hello_messages.dart';

/// The greeting rule, kept as a pure function so it can be tested without a
/// gRPC call.
String greetingFor(String name) =>
    'Hello, ${name.trim().isEmpty ? 'World' : name.trim()}!';

/// `service greeter.Greeter { rpc SayHello(HelloRequest) returns (HelloResponse) }`
///
/// A `grpc` [Service] wired by hand — the same shape codegen would produce.
class GreeterService extends Service {
  GreeterService() {
    $addMethod(
      ServiceMethod<HelloRequest, HelloResponse>(
        'SayHello',
        sayHello,
        false, // client streaming
        false, // server streaming
        HelloRequest.fromBuffer,
        (response) => response.writeToBuffer(),
      ),
    );
  }

  @override
  String get $name => 'greeter.Greeter';

  Future<HelloResponse> sayHello(
    ServiceCall call,
    Future<HelloRequest> request,
  ) async {
    final req = await request;
    return HelloResponse(message: greetingFor(req.name));
  }
}
