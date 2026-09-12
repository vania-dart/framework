---
sidebar_position: 3
---

# Tutorial: Build an E-Commerce API

This tutorial builds a product catalog and order management API. It covers complex relationships, transactions, pagination, and aggregate queries.

## 1. Create the Project

```bash
vania create shop_api
cd shop_api
dart pub add vania_mysql vania_auth
dart pub get
```

Set up `.env`, `bin/server.dart`, and `config/app.dart` as described in the [Blog API tutorial](blog-api.md).

## 2. Database Schema

Create these migrations:

### Categories

```dart
class CreateCategoriesTable extends Migration {
  @override
  Future<void> up() async {
    await create('categories', (Schema schema) {
      schema.id();
      schema.string('name', length: 100);
      schema.string('slug', length: 100).unique();
      schema.integer('parent_id').unsigned().nullable();
      schema.timeStamps();
    });
  }
}
```

### Products

```dart
class CreateProductsTable extends Migration {
  @override
  Future<void> up() async {
    await create('products', (Schema schema) {
      schema.id();
      schema.integer('category_id').unsigned().foreignKey('categories', 'id');
      schema.string('name', length: 255);
      schema.string('slug', length: 255).unique();
      schema.text('description').nullable();
      schema.decimal('price', precision: 10, scale: 2);
      schema.integer('stock').unsigned().defaultTo(0);
      schema.string('sku', length: 50).unique();
      schema.boolean('active').defaultTo(true);
      schema.timeStamps();
      schema.softDeletes();
    });
  }
}
```

### Orders and Order Items

```dart
class CreateOrdersTable extends Migration {
  @override
  Future<void> up() async {
    await create('orders', (Schema schema) {
      schema.id();
      schema.integer('user_id').unsigned().foreignKey('users', 'id');
      schema.string('order_number', length: 20).unique();
      schema.enumType('status', ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled']);
      schema.decimal('subtotal', precision: 10, scale: 2);
      schema.decimal('tax', precision: 10, scale: 2);
      schema.decimal('total', precision: 10, scale: 2);
      schema.text('shipping_address');
      schema.text('notes').nullable();
      schema.timeStamps();
    });

    await create('order_items', (Schema schema) {
      schema.id();
      schema.integer('order_id').unsigned().foreignKey('orders', 'id', onDelete: 'CASCADE');
      schema.integer('product_id').unsigned().foreignKey('products', 'id');
      schema.integer('quantity').unsigned();
      schema.decimal('unit_price', precision: 10, scale: 2);
      schema.decimal('total_price', precision: 10, scale: 2);
    });
  }
}
```

Run migrations:

```bash
vania migrate
```

## 3. Models

```dart
// lib/app/models/category.dart
class Category extends Model {
  @override
  List<String> get fillable => ['name', 'slug', 'parent_id'];

  @override
  void registerRelations() {
    hasMany('products', Product(), foreignKey: 'category_id');
    hasMany('children', Category(), foreignKey: 'parent_id');
    belongsTo('parent', Category(), foreignKey: 'parent_id');
  }
}
```

```dart
// lib/app/models/product.dart
class Product extends Model {
  @override
  List<String> get fillable => ['category_id', 'name', 'slug', 'description', 'price', 'stock', 'sku', 'active'];
  @override
  bool get softDeletes => true;

  @override
  void registerRelations() {
    belongsTo('category', Category(), foreignKey: 'category_id');
  }
}
```

```dart
// lib/app/models/order.dart
class Order extends Model {
  @override
  List<String> get fillable => ['user_id', 'order_number', 'status', 'subtotal', 'tax', 'total', 'shipping_address', 'notes'];

  @override
  void registerRelations() {
    belongsTo('customer', User(), foreignKey: 'user_id');
    hasMany('items', OrderItem(), foreignKey: 'order_id');
  }
}
```

```dart
// lib/app/models/order_item.dart
class OrderItem extends Model {
  @override
  List<String> get fillable => ['order_id', 'product_id', 'quantity', 'unit_price', 'total_price'];
  @override
  bool get timestamps => false;

  @override
  void registerRelations() {
    belongsTo('product', Product(), foreignKey: 'product_id');
  }
}
```

## 4. Product Controller

```dart
// lib/app/http/controllers/product_controller.dart
class ProductController extends Controller {
  Future<Response> index(Request req) async {
    var query = Product().query.where('active', '=', true);

    // Filter by category
    final categoryId = req.query('category_id');
    if (categoryId != null) {
      query = query.where('category_id', '=', int.parse(categoryId));
    }

    // Search by name
    final search = req.query('search');
    if (search != null) {
      query = query.whereLike('name', '%$search%');
    }

    // Price range
    final minPrice = req.query('min_price');
    final maxPrice = req.query('max_price');
    if (minPrice != null && maxPrice != null) {
      query = query.whereBetween('price', [double.parse(minPrice), double.parse(maxPrice)]);
    }

    // Sort
    final sortBy = req.query('sort', 'created_at');
    final sortDir = req.query('dir', 'desc');
    query = query.orderBy(sortBy, sortDir);

    final products = await query.include('category:id,name').paginate(
      perPage: int.parse(req.query('per_page', '20')),
      page: int.parse(req.query('page', '1')),
    );

    return Response.json(products);
  }

  Future<Response> show(int id) async {
    final product = await Product().query
        .include('category')
        .findOrFail(id);
    return Response.json(product);
  }

  Future<Response> store(Request req) async {
    req.validate({
      'name': 'required|string|max_length:255',
      'category_id': 'required|integer',
      'price': 'required|numeric|min:0',
      'stock': 'required|integer|min:0',
      'sku': 'required|string|unique:products',
    });

    final name = req.input('name') as String;

    final product = await Product().query.create({
      'category_id': req.input('category_id'),
      'name': name,
      'slug': name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      'description': req.input('description'),
      'price': req.input('price'),
      'stock': req.input('stock'),
      'sku': req.input('sku'),
      'active': true,
    });

    return Response.json(product, 201);
  }

  Future<Response> update(Request req, int id) async {
    req.validate({
      'price': 'numeric|min:0',
      'stock': 'integer|min:0',
    });

    await Product().query.where('id', '=', id).update(
      req.only(['name', 'description', 'price', 'stock', 'active']),
    );

    return Response.json({'message': 'Updated'});
  }

  Future<Response> destroy(int id) async {
    await Product().query.where('id', '=', id).delete();
    return Response.json({'message': 'Deleted'});
  }
}

final ProductController productController = ProductController();
```

## 5. Order Controller with Transactions

```dart
// lib/app/http/controllers/order_controller.dart
import 'package:vania/vania.dart';
import 'package:vania/database.dart';
import 'package:vania/http/controller.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';

class OrderController extends Controller {
  Future<Response> index(Request req) async {
    final orders = await Order().query
        .where('user_id', '=', req.user?['id'])
        .include('items')
        .orderByDesc('created_at')
        .paginate(perPage: 10);

    return Response.json(orders);
  }

  Future<Response> show(Request req, int id) async {
    final order = await Order().query
        .where('user_id', '=', req.user?['id'])
        .include('items')
        .findOrFail(id);

    return Response.json(order);
  }

  Future<Response> store(Request req) async {
    req.validate({
      'items': 'required|array',
      'items.*.product_id': 'required|integer',
      'items.*.quantity': 'required|integer|min:1',
      'shipping_address': 'required|string',
    });

    final items = req.input('items') as List;

    // Verify stock and calculate totals
    double subtotal = 0;
    final orderItems = <Map<String, dynamic>>[];

    for (var item in items) {
      final product = await Product().query.findOrFail(item['product_id']);
      final quantity = item['quantity'] as int;

      if (product['stock'] < quantity) {
        return Response.json({
          'message': 'Insufficient stock for ${product['name']}',
        }, 400);
      }

      final unitPrice = (product['price'] as num).toDouble();
      final totalPrice = unitPrice * quantity;
      subtotal += totalPrice;

      orderItems.add({
        'product_id': product['id'],
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
      });
    }

    final tax = subtotal * 0.1;
    final total = subtotal + tax;

    // Use a transaction to ensure atomicity
    final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

    await DB.transaction((db) async {
      // Create the order
      final orderId = await db.table('orders').insertGetId({
        'user_id': req.user?['id'],
        'order_number': orderNumber,
        'status': 'pending',
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'shipping_address': req.input('shipping_address'),
        'notes': req.input('notes'),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Create order items and deduct stock
      for (var item in orderItems) {
        await db.table('order_items').insert({
          'order_id': orderId,
          ...item,
        });

        await db.table('products')
            .where('id', '=', item['product_id'])
            .decrement('stock', item['quantity']);
      }

      return true; // commit
    });

    final order = await Order().query
        .where('order_number', '=', orderNumber)
        .include('items')
        .first();

    return Response.json(order, 201);
  }

  Future<Response> cancel(Request req, int id) async {
    final order = await Order().query
        .where('user_id', '=', req.user?['id'])
        .findOrFail(id);

    if (order['status'] != 'pending') {
      return Response.json({'message': 'Only pending orders can be cancelled'}, 400);
    }

    await DB.transaction((db) async {
      // Restore stock
      final items = await db.table('order_items').where('order_id', '=', id).get();
      for (var item in items) {
        await db.table('products')
            .where('id', '=', item['product_id'])
            .increment('stock', item['quantity']);
      }

      await db.table('orders').where('id', '=', id).update({'status': 'cancelled'});
      return true;
    });

    return Response.json({'message': 'Order cancelled'});
  }

  Future<Response> stats(Request req) async {
    final totalOrders = await Order().query
        .where('user_id', '=', req.user?['id'])
        .count();

    final totalSpent = await Order().query
        .where('user_id', '=', req.user?['id'])
        .where('status', '!=', 'cancelled')
        .sum('total');

    return Response.json({
      'total_orders': totalOrders,
      'total_spent': totalSpent,
    });
  }
}

final OrderController orderController = OrderController();
```

## 6. Routes

```dart
class ApiRoute implements Route {
  @override
  void register() {
    Router.basePrefix('api');

    // Auth
    Router.post('/register', authController.register);
    Router.post('/login', authController.login);

    // Public product catalog
    Router.get('/products', productController.index);
    Router.get('/products/{id}', productController.show).whereInt('id');
    Router.get('/categories', categoryController.index);

    // Protected routes
    Router.group(() {
      // Admin: product management
      Router.post('/products', productController.store);
      Router.put('/products/{id}', productController.update).whereInt('id');
      Router.delete('/products/{id}', productController.destroy).whereInt('id');

      // Orders
      Router.get('/orders', orderController.index);
      Router.post('/orders', orderController.store);
      Router.get('/orders/{id}', orderController.show).whereInt('id');
      Router.patch('/orders/{id}/cancel', orderController.cancel).whereInt('id');
      Router.get('/orders/stats', orderController.stats);
    }, middleware: [Authenticate()]);
  }
}
```

## 7. Test It

Start the server and create some test data:

```bash
# Create a category
curl -X POST http://localhost:8000/api/categories \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Electronics","slug":"electronics"}'

# Create a product
curl -X POST http://localhost:8000/api/products \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Dart SDK Book","category_id":1,"price":49.99,"stock":100,"sku":"DART-001"}'

# Browse products with filters
curl "http://localhost:8000/api/products?search=dart&min_price=10&max_price=100&sort=price&dir=asc"

# Place an order
curl -X POST http://localhost:8000/api/orders \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "items": [{"product_id":1,"quantity":2}],
    "shipping_address": "123 Dart Street"
  }'

# View order stats
curl http://localhost:8000/api/orders/stats \
  -H "Authorization: Bearer TOKEN"
```

This gives you a working e-commerce backend with product catalog filtering, stock management, transactional order placement, order cancellation with stock restoration, and spending statistics.
