class ManagerApiEndpoints {
  ManagerApiEndpoints._();

  static const String token = '/token/';
  static const String refreshToken = '/token/refresh/';
  static const String tokenLogout = '/token/logout/';
  static const String registerDevice = '/main-manager/register-device/';
  static const String createGroup = '/main-manager/create-group/';
  static const String createGroupKeyEnvelope = '/main-manager/create-group-key-envelope/';
  static const String updateGroup = '/main-manager/update-group/';
  static const String deleteGroup = '/main-manager/delete-group/';
  static const String addDeviceToGroup = '/main-manager/add-device-to-group/';
  static const String removeDeviceFromGroup = '/main-manager/remove-device-from-group/';
  static const String managerGroups = '/manager/groups/';
  static const String managerGroupDevices = '/manager/group-devices/';
  static const String managerDevices = '/manager/devices/';
  static const String mainManagerGroups = '/main-manager/groups/';
  static const String mainManagerGroupDevices = '/main-manager/group-devices/';
  static const String managerUploadEncryptedBlob = '/manager/upload-encrypted-blob/';
  static const String managerNotifyGroup = '/manager/notify-group/';
  static const String deviceFcm = '/device/fcm/';
  static const String deviceFcmDeregister = '/device/fcm/deregister/';
}