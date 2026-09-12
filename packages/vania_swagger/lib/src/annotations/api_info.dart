class ApiInfo {
  final String title;
  final String version;
  final String description;
  final String? termsOfService;
  final ApiContact? contact;
  final ApiLicense? license;

  const ApiInfo({
    required this.title,
    this.version = '1.0.0',
    this.description = '',
    this.termsOfService,
    this.contact,
    this.license,
  });
}

class ApiContact {
  final String? name;
  final String? email;
  final String? url;

  const ApiContact({this.name, this.email, this.url});
}

class ApiLicense {
  final String name;
  final String? url;

  const ApiLicense({required this.name, this.url});
}
