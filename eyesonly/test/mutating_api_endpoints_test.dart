import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:eyesonly/services/device/api_endpoints.dart';

import 'support/api_test_support.dart';

void main() {
  late http.Client client;

  setUpAll(() {
    client = http.Client();
  });

  tearDownAll(() {
    client.close();
  });

  test(
    'manager group endpoints create, update, list, and delete a temporary group',
    () async {
      final ManagerSession session = await loginManager(client);
      CreatedGroup? group;
      bool deletedGroup = false;

      try {
        group = await createTemporaryGroup(client, session);

        final List<Map<String, dynamic>> managerGroups = await getManagerGroups(
          client,
          session,
        );
        expect(
          managerGroups.any(
            (Map<String, dynamic> current) => current['uuid'] == group!.groupId,
          ),
          isTrue,
        );

        final List<Map<String, dynamic>> mainManagerGroups =
            await getMainManagerGroups(client, session);
        expect(
          mainManagerGroups.any(
            (Map<String, dynamic> current) => current['uuid'] == group!.groupId,
          ),
          isTrue,
        );

        await updateTemporaryGroup(
          client,
          session,
          groupId: group.groupId,
          contentKeyBytes: group.contentKeyBytes,
        );

        await deleteGroup(client, session, group.groupId);
        deletedGroup = true;
      } finally {
        if (!deletedGroup && group != null) {
          await tryDeleteGroup(client, session, group.groupId);
        }
      }
    },
    skip: managerMutationSkipReason,
  );

  test(
    'manager device-management endpoints register, envelope, add, list, and remove a temporary device',
    () async {
      final ManagerSession session = await loginManager(client);
      CreatedGroup? group;

      try {
        group = await createTemporaryGroup(client, session);
        final DeviceKeyMaterial device = await generateDeviceKeyMaterial(
          label: 'membership',
        );

        await registerDevice(client, session, device);
        await addDeviceToGroup(client, session, device, group.groupId);
        await createGroupKeyEnvelope(
          client,
          session,
          device: device,
          group: group,
        );

        final List<Map<String, dynamic>> devicesAfterAdd = await pollUntil(
          () async {
            final List<Map<String, dynamic>> devices = await getGroupDevices(
              client,
              session,
              group!.groupId,
            );
            if (
                devices.any((Map<String, dynamic> current) =>
                    current['device_identifier'] == device.deviceIdentifier)) {
              return devices;
            }
            return null;
          },
          description: 'temporary device to appear in group-devices',
        );

        expect(
          devicesAfterAdd.any((Map<String, dynamic> current) =>
              current['device_identifier'] == device.deviceIdentifier),
          isTrue,
        );

        await removeDeviceFromGroup(client, session, device, group.groupId);

        final List<Map<String, dynamic>> devicesAfterRemoval = await pollUntil(
          () async {
            final List<Map<String, dynamic>> devices = await getGroupDevices(
              client,
              session,
              group!.groupId,
            );
            if (
                devices.every((Map<String, dynamic> current) =>
                    current['device_identifier'] != device.deviceIdentifier)) {
              return devices;
            }
            return null;
          },
          description: 'temporary device to be removed from group-devices',
        );

        expect(
          devicesAfterRemoval.every((Map<String, dynamic> current) =>
              current['device_identifier'] != device.deviceIdentifier),
          isTrue,
        );
      } finally {
        if (group != null) {
          await tryDeleteGroup(client, session, group.groupId);
        }
      }
    },
    skip: managerMutationSkipReason,
  );

  test(
    'device endpoints authenticate, read state, upload and fetch media, leave the group, and revoke auth',
    () async {
      final ManagerSession session = await loginManager(client);
      CreatedGroup? group;

      try {
        group = await createTemporaryGroup(client, session);
        final DeviceKeyMaterial device = await generateDeviceKeyMaterial(
          label: 'device-api',
        );

        await registerDevice(client, session, device);
        await addDeviceToGroup(client, session, device, group.groupId);
        await createGroupKeyEnvelope(
          client,
          session,
          device: device,
          group: group,
        );

        final DeviceSession deviceSession = await authenticateDevice(
          client,
          device,
        );

        final http.Response selfStatusResponse = await client.get(
          apiUri(DeviceApiEndpoints.deviceStatus),
          headers: deviceJsonHeaders(deviceSession),
        );
        expect(selfStatusResponse.statusCode, 200);

        final Map<String, dynamic> selfStatus = decodeObject(selfStatusResponse);
        expect(selfStatus['device_identifier'], device.deviceIdentifier);
        expect(selfStatus['is_registered'], isTrue);

        final List<Map<String, dynamic>> groups = await getDeviceGroups(
          client,
          deviceSession,
        );
        expect(
          groups.any((Map<String, dynamic> current) => current['uuid'] == group!.groupId),
          isTrue,
        );

        final List<Map<String, dynamic>> keyEnvelopes = await getDeviceGroupKeyEnvelopes(
          client,
          deviceSession,
          <String>[group.groupId],
        );
        expect(
          keyEnvelopes.any((Map<String, dynamic> current) => current['group'] == group!.groupId),
          isTrue,
        );

        final Uint8List uploadedEncryptedBytes = await uploadEncryptedBlob(
          client,
          session,
          groupId: group.groupId,
          recipient: device,
        );

        final String imageUuid = await pollUntil(
          () async {
            final Map<String, dynamic> imageListResponse = await getEncryptedImages(
              client,
              deviceSession,
            );
            final String? currentImageUuid = findFirstImageUuidForGroup(
              imageListResponse,
              group!.groupId,
            );
            if (currentImageUuid != null) {
              return currentImageUuid;
            }
            return null;
          },
          description: 'uploaded image to appear in the device image feed',
        );

        final http.Response blobResponse = await client.get(
          apiUri(DeviceApiEndpoints.deviceEncryptedImageBlob(imageUuid)),
          headers: deviceBinaryHeaders(deviceSession),
        );
        expect(blobResponse.statusCode, 200);
        expect(blobResponse.bodyBytes, uploadedEncryptedBytes);

        await deleteEncryptedImage(
          client,
          deviceSession,
          groupId: group.groupId,
          imageUuid: imageUuid,
        );

        await pollUntil<bool>(
          () async {
            final Map<String, dynamic> imageListResponse = await getEncryptedImages(
              client,
              deviceSession,
            );
            final String? currentImageUuid = findFirstImageUuidForGroup(
              imageListResponse,
              group!.groupId,
            );
            return currentImageUuid == imageUuid ? null : true;
          },
          description: 'uploaded image to be removed from the device image feed',
        );

        final http.Response leaveGroupResponse = await postJson(
          client,
          DeviceApiEndpoints.deviceLeaveGroup,
          headers: deviceJsonHeaders(deviceSession),
          body: <String, dynamic>{'group': group.groupId},
        );
        expect(leaveGroupResponse.statusCode, 204);

        final List<Map<String, dynamic>> groupsAfterLeave = await pollUntil(
          () async {
            final List<Map<String, dynamic>> currentGroups = await getDeviceGroups(
              client,
              deviceSession,
            );
            if (
                currentGroups.every((Map<String, dynamic> current) =>
                    current['uuid'] != group!.groupId)) {
              return currentGroups;
            }
            return null;
          },
          description: 'temporary device to leave the temporary group',
        );
        expect(
          groupsAfterLeave.every(
            (Map<String, dynamic> current) => current['uuid'] != group!.groupId,
          ),
          isTrue,
        );

        final http.Response revokeResponse = await postJson(
          client,
          DeviceApiEndpoints.deviceTokenRevoke,
          headers: deviceJsonHeaders(deviceSession),
          body: const <String, dynamic>{},
        );
        expect(revokeResponse.statusCode, 204);

        final http.Response afterRevokeResponse = await client.get(
          apiUri(DeviceApiEndpoints.deviceStatus),
          headers: deviceJsonHeaders(deviceSession),
        );
        expect(afterRevokeResponse.statusCode, 401);
      } finally {
        if (group != null) {
          await tryDeleteGroup(client, session, group.groupId);
        }
      }
    },
    skip: managerMutationSkipReason,
  );
}