import 'package:vania_grpc/vania_grpc.dart';

Future<void> main() async {
  VaniaGrpcServer().register(GrpcHealthService());
  await VaniaGrpcServer().serve(
    const GrpcConfig(host: '127.0.0.1', port: 50051),
  );

  print('gRPC server listening on ${VaniaGrpcServer().port}');
}
