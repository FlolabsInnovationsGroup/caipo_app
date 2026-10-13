import 'api_client.dart';

class MemoryRepository {
  MemoryRepository(this._api);

  final FloBrainApi _api;

  Future<Map<String, dynamic>> graph() async => _object(await _api.send('GET', '/api/memory/graph/'));

  Future<Map<String, dynamic>> getNode(String id) async {
    return _object(await _api.send('GET', '/api/memory/nodes/$id/'));
  }

  Future<Map<String, dynamic>> updateNode(String id, Map<String, dynamic> patch) async {
    return _object(await _api.send('PATCH', '/api/memory/nodes/$id/', data: patch));
  }

  Future<Map<String, dynamic>> save(Map<String, dynamic> body) async {
    return _object(await _api.send('POST', '/api/memory/save/', data: body));
  }

  Map<String, dynamic> _object(dynamic response) {
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) return {'results': data};
    return const {};
  }
}
