import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/models.dart';

/// USDA FoodData Central lookup, proxied through the coach server so keys stay
/// server-side. Fails gracefully on any network error.
class UsdaService {
  UsdaService(this.baseUrl);
  String baseUrl;

  Future<List<Food>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final uri = Uri.parse('$baseUrl/usda/search').replace(queryParameters: {'query': q});
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final results = (body['results'] as List?) ?? const [];
      return results.map<Food>((r) {
        final m = (r as Map).cast<String, dynamic>();
        final desc = (m['description'] ?? 'Food').toString();
        final brand = m['brand']?.toString();
        final name = (brand != null && brand.isNotEmpty) ? '$desc · $brand' : desc;
        return Food(
          name: name,
          cal: (m['cal'] as num?)?.toDouble() ?? 0,
          protein: (m['protein'] as num?)?.toDouble() ?? 0,
          carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
          fat: (m['fat'] as num?)?.toDouble() ?? 0,
          fiber: (m['fiber'] as num?)?.toDouble() ?? 0,
          custom: true,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
