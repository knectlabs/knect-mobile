import 'package:dio/dio.dart';

import '../../features/auth/domain/auth_models.dart';

typedef Json = Map<String, Object?>;

/// Typed reads over decoded API JSON; throw [ContractException] on mismatch.
extension JsonRead on Json {
  T _get<T>(String key) {
    final value = this[key];
    if (value is T) return value;
    throw ContractException('Unexpected "$key" in API response.');
  }

  String str(String key) => _get<String>(key);
  String? strOrNull(String key) => _get<String?>(key);
  int integer(String key) => _get<num>(key).toInt();
  int? intOrNull(String key) => _get<num?>(key)?.toInt();
  double? numOrNull(String key) => _get<num?>(key)?.toDouble();
  bool flag(String key) => _get<bool>(key);
  DateTime time(String key) => DateTime.parse(str(key));
  DateTime? timeOrNull(String key) {
    final value = strOrNull(key);
    return value == null ? null : DateTime.parse(value);
  }

  Json obj(String key) => Json.from(_get<Map>(key));
  Json? objOrNull(String key) {
    final value = _get<Map?>(key);
    return value == null ? null : Json.from(value);
  }

  List<Json> list(String key) =>
      _get<List>(key).map((item) => Json.from(item as Map)).toList();
}

/// `{data: {...}}` → the object, `{data: null}` → null.
Json? dataOrNull(Response<Object?> response) {
  final body = response.data;
  if (body is Map && body.containsKey('data')) {
    final data = body['data'];
    return data == null ? null : Json.from(data as Map);
  }
  throw const ContractException('Expected a {"data": ...} response.');
}

Json data(Response<Object?> response) =>
    dataOrNull(response) ??
    (throw const ContractException('Expected response data.'));

/// `{data: [...]}` → the items.
List<Json> dataList(Response<Object?> response) {
  final body = response.data;
  if (body is Map && body['data'] is List) {
    return (body['data'] as List)
        .map((item) => Json.from(item as Map))
        .toList();
  }
  throw const ContractException('Expected a {"data": [...]} response.');
}

/// `{id, name, code?}` references returned on many resources.
class Ref {
  const Ref({required this.id, required this.name, this.code});

  static Ref? from(Json? json) => json == null
      ? null
      : Ref(
          id: json.str('id'),
          name: json.str('name'),
          code: json['code'] as String?,
        );

  final String id;
  final String name;
  final String? code;
}
