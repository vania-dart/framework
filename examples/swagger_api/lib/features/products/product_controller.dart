import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:swagger_api/features/products/product_repository.dart';

class ProductController extends Controller {
  Future<Response> index(Request req) async {
    return Response.json({
      'data': productRepository.all().map((p) => p.toJson()).toList(),
    });
  }

  Future<Response> show(Request req, int id) async {
    final product = productRepository.find(id);
    if (product == null) {
      return Response.json({'message': 'Not found'}, 404);
    }
    return Response.json(product.toJson());
  }

  Future<Response> store(Request req) async {
    await req.validate({
      'name': 'required|string|max_length:255',
      'price_cents': 'required|numeric',
    });
    final product = productRepository.create(
      req.input('name') as String,
      int.parse(req.input('price_cents').toString()),
    );
    return Response.json(product.toJson(), 201);
  }

  Future<Response> destroy(Request req, int id) async {
    if (!productRepository.delete(id)) {
      return Response.json({'message': 'Not found'}, 404);
    }
    return Response.json({'message': 'Deleted'});
  }
}

final ProductController productController = ProductController();
