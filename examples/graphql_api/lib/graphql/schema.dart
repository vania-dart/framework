import 'package:vania_graphql/vania_graphql.dart';

/// In-memory data the schema resolves against.
final List<Map<String, dynamic>> _books = [
  {'id': 1, 'title': 'The Hobbit', 'author': 'J.R.R. Tolkien'},
  {'id': 2, 'title': 'Dune', 'author': 'Frank Herbert'},
  {'id': 3, 'title': 'Neuromancer', 'author': 'William Gibson'},
];

/// `type Book { id: Int, title: String, author: String }`.
/// Each field reads from the parent map exposed as `context.rootValue`.
final GraphQLObjectType _bookType = objectType(
  'Book',
  fields: [
    vaniaField<int, int>(
      'id',
      graphQLInt,
      resolve: (context, _) => (context.rootValue as Map)['id'] as int,
    ),
    vaniaField<String, String>(
      'title',
      graphQLString,
      resolve: (context, _) => (context.rootValue as Map)['title'] as String,
    ),
    vaniaField<String, String>(
      'author',
      graphQLString,
      resolve: (context, _) => (context.rootValue as Map)['author'] as String,
    ),
  ],
);

/// Builds the schema:
///
/// ```graphql
/// type Query {
///   hello: String
///   books: [Book]
///   book(id: Int!): Book
/// }
/// ```
GraphQLSchema buildSchema() {
  return graphQLSchema(
    queryType: objectType(
      'Query',
      fields: [
        vaniaField<String, String>(
          'hello',
          graphQLString,
          resolve: (_, _) => 'Hello from Vania GraphQL',
        ),
        vaniaField(
          'books',
          listOf(_bookType),
          resolve: (_, _) => _books,
        ),
        vaniaField(
          'book',
          _bookType,
          inputs: [GraphQLFieldInput('id', graphQLInt.nonNullable())],
          resolve: (_, arguments) {
            final id = arguments['id'];
            for (final book in _books) {
              if (book['id'] == id) return book;
            }
            return null;
          },
        ),
      ],
    ),
  );
}
