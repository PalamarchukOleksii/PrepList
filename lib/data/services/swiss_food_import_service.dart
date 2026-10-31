import 'package:preplist/data/api/swiss_food_api.dart';
import 'package:preplist/features/foods/repositories/food_repository.dart';

typedef ImportProgress = void Function(int completed, int total);

class SwissFoodImportService {
  final SwissFoodApi api;
  final FoodRepository repository;

  SwissFoodImportService({SwissFoodApi? api, FoodRepository? repository})
    : api = api ?? SwissFoodApi(),
      repository = repository ?? FoodRepository.instance;

  Future<void> importDatabase({required ImportProgress onProgress}) async {
    final version = await api.fetchVersion();

    const pageSize = 100;
    var offset = 0;

    final foodList = <Map<String, dynamic>>[];

    while (true) {
      final page = await api.fetchFoodPage(offset: offset, limit: pageSize);

      foodList.addAll(page);

      if (page.length < pageSize) break;

      offset += pageSize;
    }

    if (foodList.isEmpty) {
      throw Exception('The Swiss database returned no foods.');
    }

    final ids = foodList.map(_extractId).whereType<int>().toList();

    if (ids.isEmpty) {
      throw Exception('No food IDs were found in the API response.');
    }

    final records = <Map<String, dynamic>>[];
    var completed = 0;

    onProgress(0, ids.length);

    // A limited number of concurrent requests.
    const workerCount = 5;
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;

        if (index >= ids.length) return;

        final id = ids[index];
        final details = await api.fetchFoodDetails(id);

        final record = _parseFood(details, id);

        if (record != null) {
          records.add(record);
        }

        completed++;
        onProgress(completed, ids.length);
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));

    if (records.isEmpty) {
      throw Exception('No valid food records were downloaded.');
    }

    await repository.replaceAllFoods(foods: records, version: version);
  }

  int? _extractId(Map<String, dynamic> food) {
    final value = food['id'] ?? food['DBID'] ?? food['dbid'] ?? food['foodid'];

    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic>? _parseFood(Map<String, dynamic> food, int fallbackId) {
    final id = _extractId(food) ?? fallbackId;

    final name = _extractName(food);

    if (name.isEmpty) return null;

    final synonyms = _extractSynonyms(food);
    final values = food['values'];

    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    if (values is List) {
      for (final item in values) {
        if (item is! Map) continue;

        final value = _toDouble(item['value']);
        if (value == null) continue;

        final component = item['component'];
        final componentMap = component is Map ? component : <String, dynamic>{};

        final componentName =
            '${componentMap['name'] ?? item['componentname'] ?? ''}'
                .toLowerCase();

        final componentCode = '${componentMap['code'] ?? item['code'] ?? ''}'
            .toLowerCase();

        final unit = '${item['unit'] ?? componentMap['unit'] ?? ''}'
            .toLowerCase();

        final searchable = '$componentName $componentCode';

        if (_matches(searchable, ['protein', 'proteins', 'prot'])) {
          protein = value;
        } else if (_matches(searchable, [
          'carbohydrate',
          'carbohydrates',
          'available carbohydrate',
          'carb',
          'cho',
        ])) {
          carbs = value;
        } else if (_matches(searchable, [
          'fat',
          'total fat',
          'lipid',
          'lipids',
        ])) {
          fat = value;
        } else if (_matches(searchable, ['energy', 'ener'])) {
          calories = unit.contains('kj') ? value / 4.184 : value;
        }
      }
    }

    return {
      'external_id': id,
      'name': name,
      'synonyms': synonyms.join('|'),
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  String _extractName(Map<String, dynamic> food) {
    final direct = food['name'];

    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final names = food['names'];

    if (names is List) {
      for (final item in names) {
        if (item is String && item.trim().isNotEmpty) {
          return item.trim();
        }

        if (item is Map) {
          final value = item['name'] ?? item['value'];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString().trim();
          }
        }
      }
    }

    if (names is Map) {
      final english = names['en'];
      if (english != null) return english.toString();
    }

    return '';
  }

  List<String> _extractSynonyms(Map<String, dynamic> food) {
    final value = food['synonyms'] ?? food['synonymes'];

    if (value is List) {
      return value
          .map((item) {
            if (item is Map) {
              return (item['name'] ?? item['value'] ?? '').toString();
            }
            return item.toString();
          })
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    return [];
  }

  bool _matches(String text, List<String> terms) {
    return terms.any((term) => text.contains(term));
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;

    return double.tryParse(value.toString().replaceAll(',', '.'));
  }
}
