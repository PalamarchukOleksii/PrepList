import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class SwissFoodApi {
  static const String _baseUrl =
      'https://api.webapp.prod.blv.foodcase-services.com/BLV_WebApp_WS';

  static const String _apiPath = '/webresources/BLV-api';

  final http.Client _client;

  SwissFoodApi({http.Client? client}) : _client = client ?? http.Client();

  Future<String> fetchVersion() async {
    final json = await _getJson('$_apiPath/versiondb');

    if (json is Map) {
      return (json['versiontext'] ?? json['idversion'] ?? 'unknown').toString();
    }

    return 'unknown';
  }

  Future<List<Map<String, dynamic>>> fetchFoodPage({
    required int offset,
    int limit = 100,
  }) async {
    final json = await _getJson(
      '$_apiPath/foods',
      query: {'lang': 'en', 'limit': '$limit', 'offset': '$offset'},
    );

    final items = _extractList(json);

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> fetchFoodDetails(int id) async {
    final json = await _getJson('$_apiPath/food/$id', query: {'lang': 'en'});

    if (json is! Map) {
      throw FormatException('Invalid food response for ID $id');
    }

    return Map<String, dynamic>.from(json);
  }

  Future<dynamic> _getJson(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);

    Object? lastError;

    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final response = await _client
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 30));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return jsonDecode(utf8.decode(response.bodyBytes));
        }

        if (response.statusCode == 429 || response.statusCode >= 500) {
          lastError = 'HTTP ${response.statusCode}: ${response.body}';
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
          continue;
        }

        throw Exception(
          'Swiss database returned HTTP ${response.statusCode}: '
          '${response.body}',
        );
      } on TimeoutException catch (error) {
        lastError = error;
      } catch (error) {
        if (attempt == 3) rethrow;
        lastError = error;
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }

    throw Exception('Swiss database request failed: $lastError');
  }

  List<dynamic> _extractList(dynamic json) {
    if (json is List) return json;

    if (json is Map) {
      for (final key in ['foods', 'items', 'data', 'results', 'content']) {
        final value = json[key];
        if (value is List) return value;
      }
    }

    throw const FormatException(
      'Could not find a food list in the Swiss database response.',
    );
  }

  void close() {
    _client.close();
  }
}
