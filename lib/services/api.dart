import 'package:cloud_functions/cloud_functions.dart';

class Api {
  Api({this.call});
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
  call;
  static Api shared = Api();
  Future<Map<String, dynamic>> run(
    String op, [
    Map<String, dynamic> payload = const {},
  ]) async {
    if (call != null) {
      return call!(op, payload);
    }
    final result = await FirebaseFunctions.instanceFor(region: 'asia-east1')
        .httpsCallable(
          'api',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
        )
        .call({'op': op, 'payload': payload});
    return Map<String, dynamic>.from(result.data as Map);
  }
}

Map<String, dynamic> jsonMap(dynamic v) =>
    Map<String, dynamic>.from(v as Map? ?? {});
List<Map<String, dynamic>> jsonRows(dynamic v) =>
    (v as List? ?? []).map(jsonMap).toList();
String errorText(Object e) => e is FirebaseFunctionsException
    ? (e.message ?? 'Дахин оролдоно уу.')
    : e is ArgumentError
    ? e.message.toString()
    : 'Холболтоо шалгаад дахин оролдоно уу.';
