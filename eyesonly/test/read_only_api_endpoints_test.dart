import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:eyesonly/services/device/api_endpoints.dart';
import 'package:eyesonly/services/manager/api_endpoints.dart';

import 'support/api_test_support.dart';

void main() {
  late http.Client client;

  setUpAll(() {
    client = http.Client();
  });

  tearDownAll(() {
    client.close();
  });

  test('GET /status/ returns health response', () async {
    final http.Response response = await client.get(apiUri(DeviceApiEndpoints.apiStatus));

    expect(response.statusCode, 200);

    final Map<String, dynamic> body = decodeObject(response);
    expect(body['status'], 'ok');
    expect(body['organization'], anyOf(isNull, isA<String>()));
  }, skip: apiIntegrationSkipReason);

  test(
    'manager auth endpoints login, refresh, and logout work',
    () async {
      final ManagerSession session = await loginManager(client);

      final http.Response refreshResponse = await postJson(
        client,
        ManagerApiEndpoints.refreshToken,
        body: <String, dynamic>{'refresh': session.refreshToken},
      );

      expect(refreshResponse.statusCode, anyOf(200, 201));

      final Map<String, dynamic> refreshBody = decodeObject(refreshResponse);
      final String refreshedAccessToken =
          (refreshBody['access'] as String?)?.trim() ?? '';
      expect(refreshedAccessToken, isNotEmpty);

      final http.Response logoutResponse = await postJson(
        client,
        ManagerApiEndpoints.tokenLogout,
        body: <String, dynamic>{'refresh': session.refreshToken},
      );

      expect(logoutResponse.statusCode, anyOf(200, 204));
    },
    skip: managerAuthSkipReason,
  );

  test(
    'manager read endpoints return lists for the authenticated manager',
    () async {
      final ManagerSession session = await loginManager(client);

      final List<Map<String, dynamic>> managerGroups = await getManagerGroups(
        client,
        session,
      );
      final List<Map<String, dynamic>> mainManagerGroups =
          await getMainManagerGroups(client, session);

      expect(managerGroups, isA<List<Map<String, dynamic>>>());
      expect(mainManagerGroups, isA<List<Map<String, dynamic>>>());
    },
    skip: managerAuthSkipReason,
  );
}