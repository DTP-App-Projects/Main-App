import '../../../core/network/coerce.dart';

/// `GET /api/countries` — public, and the only source for the sign-up
/// country/city pickers. Cities are `countries` rows of `type=sub`.
class Country {
  final int id;
  final String name;
  final String currency;
  final double taxPercentage;
  final List<City> cities;

  const Country({
    required this.id,
    required this.name,
    required this.currency,
    required this.taxPercentage,
    required this.cities,
  });

  factory Country.fromJson(Map<String, dynamic> j) => Country(
        id: asInt(j['id']),
        name: unwrap(j['name']),
        currency: asStr(j['currency']),
        taxPercentage: asNum(j['tax_percentage']),
        cities: asList(j['cities'], City.fromJson),
      );
}

class City {
  final int id;
  final String name;

  const City({required this.id, required this.name});

  factory City.fromJson(Map<String, dynamic> j) =>
      City(id: asInt(j['id']), name: unwrap(j['name']));
}
