class DeviceApiEndpoints {
  DeviceApiEndpoints._();

  static const String apiStatus = '/status/';
  static const String deviceAuthChallenge = '/device/auth/challenge/';
  static const String deviceAuthToken = '/device/auth/token/';
  static const String deviceTokenRevoke = '/device/auth/revoke/';
  static const String deviceFcm = '/device/fcm/';
  static const String deviceFcmDeregister = '/device/fcm/deregister/';
  static const String deviceStatus = '/device/self/status/';
  static const String deviceLeaveGroup = '/device/leave-group/';
  static const String deviceGroups = '/device/groups/';
  static const String deviceGroupKeyEnvelope = '/device/group-key-envelopes/';
  static const String deviceListEncryptedImages = '/device/encrypted-images/';
  static const String deleteEncryptedImage = '/delete-encrypted-image/';

  static String deviceEncryptedImageBlob(String imageUuid) {
    return '/device/encrypted-images/$imageUuid/blob/';
  }
}