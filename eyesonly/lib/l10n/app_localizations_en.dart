// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsDeviceLock => 'Device Lock';

  @override
  String get settingsDeviceLockSubtitle =>
      'Require face, fingerprint, or device code';

  @override
  String get settingsPushNotifications => 'Push Notifications';

  @override
  String get settingsPushNotificationsSubtitle =>
      'Receive notifications when new pictures are uploaded';

  @override
  String get settingsDarkMode => 'Dark Mode';

  @override
  String get settingsDarkModeSubtitle => 'Use a darker appearance at night';

  @override
  String get settingsManagerMode => 'Manager Mode';

  @override
  String get settingsManagerModeSubtitle => 'Enable manager mode features';

  @override
  String get settingsOrganizations => 'Organizations';

  @override
  String get settingsNoOrganizations => 'No organizations yet';

  @override
  String get settingsNoOrganizationsSubtitle =>
      'Add an organization to connect this device.';

  @override
  String get settingsAddOrganization => 'Add Organization';

  @override
  String get settingsManagerSettings => 'Manager Settings';

  @override
  String get settingsManagerOrganization => 'Manager Organization';

  @override
  String get settingsManagerAddOrgFirst =>
      'Add an organization first to select a manager server.';

  @override
  String get settingsDeleteImageCache => 'Delete Encrypted Image Cache';

  @override
  String get settingsDeleteImageCacheSubtitle =>
      'Remove locally cached encrypted image blobs';

  @override
  String get settingsResetApp => 'Reset App';

  @override
  String get settingsResetAppSubtitle =>
      'Remove local keys, tokens, organizations, and app settings';

  @override
  String get settingsAppVersion => 'App Version';

  @override
  String get settingsRemoveOrganizationTitle => 'Remove Organization';

  @override
  String settingsRemoveOrganizationContent(String name) {
    return 'Do you want to remove $name from this device?\n\nThis only removes the local organization entry.';
  }

  @override
  String get settingsDeleteCache => 'Delete Cache';

  @override
  String get settingsDeleteImageCacheDialogTitle =>
      'Delete Encrypted Image Cache';

  @override
  String get settingsDeleteImageCacheDialogContent =>
      'Delete all locally cached encrypted image blobs from this device?\n\nThe next time you open Photos, encrypted blobs will be fetched again and decrypted when viewed.';

  @override
  String get settingsImageCacheDeleted => 'Image cache deleted.';

  @override
  String settingsImageCacheDeleteFailed(String error) {
    return 'Could not delete image cache: $error';
  }

  @override
  String get settingsAddOrgFirst => 'Add an organization first.';

  @override
  String get settingsResetAppDialogTitle => 'Reset App';

  @override
  String get settingsResetAppDialogContent =>
      'Warning: Resetting the app will remove local keys, tokens, installation identity, organizations, cached images, and app settings. This action cannot be undone.\n\nAre you sure you want to continue?';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsDeviceLockNotAvailable =>
      'No device authentication is available on this device.';

  @override
  String get settingsDeviceLockNotEnabled => 'Device lock was not enabled.';

  @override
  String settingsPushNotificationsFailed(String error) {
    return 'Could not update push notifications: $error';
  }

  @override
  String get settingsAppVersionValue => '1.0.0';

  @override
  String get appTitle => 'Eyes Only';

  @override
  String get unlockReason => 'Unlock Eyes Only';

  @override
  String get lockNoAuthAvailable => 'No device authentication is available.';

  @override
  String get lockUnlockRequired => 'Unlock required to continue.';

  @override
  String get lockAuthFailed => 'Device authentication failed.';

  @override
  String get appLockedTitle => 'Eyes Only is locked';

  @override
  String get appLockedMessage =>
      'Use face, fingerprint, or your device code to continue.';

  @override
  String get unlocking => 'Unlocking...';

  @override
  String get unlock => 'Unlock';

  @override
  String get homeMenu => 'Menu';

  @override
  String get homeTabPhotos => 'Photos';

  @override
  String get homeTabGroups => 'Groups';

  @override
  String get homeTabAccount => 'Account';

  @override
  String get homeTabLogIn => 'Log In';

  @override
  String get homeTabSettings => 'Settings';

  @override
  String get homeTabAbout => 'About';

  @override
  String get managerServerNotSet => 'Manager server URL is not set.';

  @override
  String get notifyWhenImagesLoading =>
      'This group cannot be notified until its images finish loading.';

  @override
  String notificationSent(int count) {
    return 'Notification sent to $count devices.';
  }

  @override
  String notificationSentWithSkipped(int notified, int skipped) {
    return 'Notification sent to $notified devices. $skipped were skipped.';
  }

  @override
  String get imageDeleted => 'Image deleted.';

  @override
  String get homeTakePicture => 'Take Picture';

  @override
  String get homeSendMessageToGroup => 'Send Message to Group';

  @override
  String get homeRetry => 'Retry';

  @override
  String get homeNoImages => 'Currently there are no images for you';

  @override
  String get homeNoGroupsYet => 'You are not in any groups yet.';

  @override
  String get homeJoinGroup => 'Join Group';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get groupsRefresh => 'Refresh';

  @override
  String get groupsCreateGroup => 'Create Group';

  @override
  String groupsError(Object message) {
    return 'Error: $message';
  }

  @override
  String get groupsAddOrganizationToSeeGroups =>
      'Add an organization to see its groups here.';

  @override
  String get groupsNoGroups => 'No groups';

  @override
  String get groupsJoinGroup => 'Join Group';

  @override
  String get groupsLeaveGroup => 'Leave Group';

  @override
  String get groupsShareOrganization => 'Share Organization';

  @override
  String groupsFallbackName(Object shortId) {
    return 'Group $shortId';
  }

  @override
  String groupsServerTimeoutWithUrl(Object apiUrl) {
    return 'Could not reach $apiUrl within 10 seconds.';
  }

  @override
  String get groupsServerTimeout =>
      'Could not reach the server within 10 seconds.';

  @override
  String get homeApiUnreachable =>
      'Could not reach the API. Please check your connection and try again.';

  @override
  String get homeLoadingImages => 'Loading images...';

  @override
  String get homeLookingForNewPhotos => 'Looking for new photos...';

  @override
  String get homeDownloadingNewImages => 'Downloading new images...';

  @override
  String get homeNoNewImagesFound => 'No new images found.';

  @override
  String get homeUnknownDay => 'Unknown day';

  @override
  String get homeDeleteImageTitle => 'Delete Image';

  @override
  String get homeDeleteImageConfirm =>
      'Delete this image from the server for this group? This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get homeCollapseCaption => 'Collapse caption';

  @override
  String get homeShowCaption => 'Show caption';

  @override
  String get homeDeleteImageTooltip => 'Delete image';

  @override
  String get failedToDecryptImage => 'Failed to decrypt image';

  @override
  String get captureNoCameraAvailable =>
      'No camera is available on this device.';

  @override
  String get captureFlashModeFailed =>
      'Could not change flash mode. Please try again.';

  @override
  String get captureTakePhotoFailed =>
      'Could not take photo. Please try again.';

  @override
  String get pictureDeleted => 'Picture deleted.';

  @override
  String get flashAuto => 'Flash Auto';

  @override
  String get flashOn => 'Flash On';

  @override
  String get flashOff => 'Flash Off';

  @override
  String get retryCamera => 'Retry Camera';

  @override
  String get switchCamera => 'Switch Camera';

  @override
  String get sendTitle => 'Send';

  @override
  String sendSuccess(int count) {
    return 'Encrypted image sent to $count devices.';
  }

  @override
  String get sendAddTextLabel => 'Add text';

  @override
  String get sendAddTextHint => 'Add optional text for this image';

  @override
  String get sendDelete => 'Delete';

  @override
  String get sendSending => 'Sending...';

  @override
  String get sendFailedTryAgain => 'Sending failed. Please try again.';

  @override
  String get sendSend => 'Send';

  @override
  String get sendSelectExpirationTitle => 'Select deletion time';

  @override
  String get close => 'Close';

  @override
  String get sendPhotoExpiration => 'Will be deleted at';

  @override
  String get expiresToday => 'Will be deleted today';

  @override
  String get createGroupTitle => 'Create Group';

  @override
  String get createGroupHeading => 'New Group';

  @override
  String get createGroupNameLabel => 'Name';

  @override
  String get createGroupNameRequired => 'Name is required';

  @override
  String get createGroupCreating => 'Creating...';

  @override
  String get createGroupSuccess => 'Group created successfully.';

  @override
  String get createGroupCreatorNotLinkedError =>
      'Creator device was not linked to the new group.';

  @override
  String get createGroupNoLoggedInManagerError =>
      'No logged-in manager account found for device registration.';

  @override
  String get createGroupNoUuidError =>
      'Group was created but server returned no UUID.';

  @override
  String get joinGroupPageTitle => 'Join Group';

  @override
  String get joinGroupQrInstruction =>
      'Have a main manager scan this QR code and choose the group.';

  @override
  String get joinGroupQrWhatIsSharedTitle => 'What is shared?';

  @override
  String get joinGroupQrWhatIsSharedBody =>
      'This QR code shares the organization server URL, this installation identifier, and this device public key data so a main manager can register the device and add it to a selected group.';

  @override
  String joinGroupQrInstallationId(Object installationId) {
    return 'Installation Identifier: $installationId';
  }

  @override
  String get aboutInstallationIdentifier => 'Installation Identifier';

  @override
  String get aboutHiddenValue => 'Hidden';

  @override
  String get aboutHideIdentifier => 'Hide Identifier';

  @override
  String get aboutShowIdentifier => 'Show Identifier';

  @override
  String get accountNotLoggedIn => 'Not logged in';

  @override
  String get accountLoggingOut => 'Logging Out...';

  @override
  String get accountLogOut => 'Log Out';

  @override
  String get shareOrganizationQrInstruction =>
      'Have the other device scan this QR code to add this organization.';

  @override
  String get groupPushFixedMessageIntro =>
      'The notification message is fixed for privacy reasons:';

  @override
  String get selectCaptureNoManagerGroups =>
      'You are not a manager for any groups yet.';

  @override
  String get loginRegisterThisDeviceTitle => 'Register This Device';

  @override
  String get loginRegisterThisDeviceContent =>
      'This device is not registered yet. On your already-registered manager device, tap \"Register Manager Device\" and scan the QR code shown here.';

  @override
  String get loginLater => 'Later';

  @override
  String get loginShowQrCode => 'Show QR Code';

  @override
  String get loginServerUrlNotSet =>
      'Server URL is not set. Configure it in Settings.';

  @override
  String get loginSuccessful => 'Login successful';

  @override
  String get loginFailedTryAgain => 'Login failed. Please try again.';

  @override
  String get loginManagerTitle => 'Manager Login';

  @override
  String get loginOnlyMessage =>
      'This app supports login only. Registration is disabled.';

  @override
  String get loginUsernameLabel => 'Username';

  @override
  String get loginUsernameRequired => 'Username is required';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginPasswordRequired => 'Password is required';

  @override
  String get loginLoggingIn => 'Logging In...';

  @override
  String get scanQrTitle => 'Scan QR Code';

  @override
  String get scanQrInstruction =>
      'Scan the manager\'s organization QR code to fill the API URL.';

  @override
  String get scanQrInvalidJson =>
      'The scanned QR code did not contain valid JSON data.';

  @override
  String get addOrganizationApiUrlLabel => 'API URL';

  @override
  String get addOrganizationApiUrlHint => 'https://api.example.com';

  @override
  String get addOrganizationApiUrlRequired => 'API URL is required';

  @override
  String get addOrganizationApiUrlInvalid => 'Enter a valid http or https URL';

  @override
  String get addOrganizationApiUrlDuplicate =>
      'This API URL has already been added';

  @override
  String get addOrganizationChecking => 'Checking organization...';

  @override
  String get addOrganizationCheckAction => 'Check Organization';

  @override
  String get addOrganizationConfirmPrompt => 'Add this organization?';

  @override
  String get addOrganizationAdd => 'Add';

  @override
  String get addOrganizationCancel => 'Cancel';

  @override
  String get addOrganizationInvalidQr =>
      'The scanned QR code did not contain a valid API URL.';

  @override
  String get addOrganizationUnreachable =>
      'Could not reach the server. Please check the URL and your network connection.';

  @override
  String get addOrganizationTimeout =>
      'Could not reach the server within 10 seconds.';

  @override
  String addOrganizationUnexpectedStatus(int statusCode) {
    return 'Server returned an unexpected status ($statusCode). Please check the URL.';
  }

  @override
  String get groupAddScanDeviceTitle => 'Scan Device';

  @override
  String get groupAddScanDeviceInstruction =>
      'Scan the device QR code to capture its installation identifier and public key.';

  @override
  String get groupAddServerUrlMismatchTitle => 'Server URL mismatch';

  @override
  String get groupAddServerUrlMismatchBody =>
      'The scanned device is registered to a different server address than the one you are currently managing. This may be normal if the same server is reachable at multiple addresses (e.g. emulator vs. physical device on the same network).';

  @override
  String get groupAddCurrentServerLabel => 'Current server:';

  @override
  String get groupAddDeviceServerLabel => 'Device server:';

  @override
  String get groupAddServerUrlMismatchWarning =>
      'Only continue if you are sure both addresses point to the same server.';

  @override
  String get groupAddCancel => 'Cancel';

  @override
  String get groupAddAddAnyway => 'Add anyway';

  @override
  String groupAddAddedMember(Object name, Object groupName) {
    return 'Added $name to $groupName.';
  }

  @override
  String get groupAddStatusReady => 'Ready';

  @override
  String get groupAddStatusRequired => 'Required';

  @override
  String get groupAddDeviceTitle => 'Add Device';

  @override
  String get groupAddNameLabel => 'Name';

  @override
  String get groupAddNameHint => 'Enter a name for this device';

  @override
  String get groupAddNameRequired => 'Name is required';

  @override
  String get groupAddDeviceLabel => 'Device';

  @override
  String get groupAddScanDeviceAction => 'Scan Device';

  @override
  String get groupAddAddingDevice => 'Adding Device...';

  @override
  String get groupAddDeviceAction => 'Add Device';

  @override
  String get groupAddNotJoinCode =>
      'The scanned QR code is not a device join code.';

  @override
  String get groupAddMissingManagerRequestData =>
      'The scanned QR code is missing manager request data.';

  @override
  String get groupAddMissingRegisterData =>
      'The scanned QR code is missing register-device data.';

  @override
  String get groupAddMissingRequiredData =>
      'The scanned QR code is missing required device data.';

  @override
  String get groupAddManagerDeviceTitle => 'Add Manager Device';

  @override
  String get groupAddManagerInstruction =>
      'Scan the QR code shown on the other manager\'s device (Groups → Join Group) while they are logged in as a manager.';

  @override
  String get groupAddManagerDeviceAction => 'Add Manager Device';

  @override
  String get groupAddManagerScanTitle => 'Scan Manager Device';

  @override
  String get groupAddManagerScanInstruction =>
      'On the other manager\'s device, go to Groups → Join Group and scan the QR code shown there.';

  @override
  String get groupAddManagerServerUrlMismatchBody =>
      'The scanned device reports a different server address. This may be normal if both addresses point to the same server (e.g. emulator vs. physical device).';

  @override
  String get groupAddManagerMissingOwnerUser =>
      'This QR code does not include a manager account. Make sure the other manager is logged in before showing the QR code.';

  @override
  String get registerManagerDeviceTitle => 'Register Manager Device';

  @override
  String get registerManagerDeviceInstruction =>
      'Scan the QR code shown on the second manager device (Groups → Join Group) to register it as an additional device for your account.';

  @override
  String get registerManagerDeviceGenerating => 'Generating...';

  @override
  String get registerManagerDeviceGenerateQrCode => 'Generate QR Code';

  @override
  String get registerManagerDeviceServerUrlMismatchTitle =>
      'Server URL mismatch';

  @override
  String get registerManagerDeviceServerUrlMismatchBody =>
      'The scanned device is registered to a different server address. This may be normal if both addresses point to the same server (e.g. emulator vs. physical device on the same network).';

  @override
  String get registerManagerDeviceCurrentServerLabel => 'Current server:';

  @override
  String get registerManagerDeviceDeviceServerLabel => 'Device server:';

  @override
  String get registerManagerDeviceServerUrlMismatchWarning =>
      'Only continue if you are sure both addresses point to the same server.';

  @override
  String get registerManagerDeviceCancel => 'Cancel';

  @override
  String get registerManagerDeviceContinue => 'Continue';

  @override
  String get registerManagerDeviceSuccess => 'Device registered successfully.';

  @override
  String get registerManagerDeviceScanned => 'Device scanned';

  @override
  String get registerManagerDeviceScanRequired => 'Scan required';

  @override
  String get registerManagerDeviceScanDeviceQr => 'Scan Device QR';

  @override
  String get registerManagerDeviceRegistering => 'Registering...';

  @override
  String get registerManagerDeviceRegisterAction => 'Register Device';

  @override
  String get registerManagerDeviceScanInstruction =>
      'On the second device, go to Groups → Join Group and scan that QR code here.';

  @override
  String get registerManagerDeviceNotJoinCode =>
      'The scanned QR code is not a device join code.';

  @override
  String get registerManagerDeviceMissingManagerRequestData =>
      'The scanned QR code is missing manager request data.';

  @override
  String get registerManagerDeviceMissingRegisterData =>
      'The scanned QR code is missing register-device data.';

  @override
  String get registerManagerDeviceMissingRequiredData =>
      'The scanned QR code is missing required device data.';

  @override
  String get groupDetailDecryptionFailed => 'Decryption failed';

  @override
  String groupDetailRemovedFromGroup(Object ownerName) {
    return 'Removed $ownerName from the group.';
  }

  @override
  String get groupDetailRemoveDeviceTitle => 'Remove Device?';

  @override
  String groupDetailRemoveDevicePrompt(Object ownerName) {
    return 'Remove $ownerName from this group?';
  }

  @override
  String get groupDetailCancel => 'Cancel';

  @override
  String get groupDetailRemoveAction => 'Remove';

  @override
  String get groupDetailLeaveGroupTitle => 'Leave Group?';

  @override
  String groupDetailLeaveGroupPrompt(Object groupName) {
    return 'Do you really want to leave $groupName?\n\nOnly a manager can re-add you to this group.';
  }

  @override
  String get groupDetailLeaveAction => 'Leave';

  @override
  String get groupDetailDeleteGroupTitle => 'Delete Group?';

  @override
  String groupDetailDeleteGroupPrompt(Object groupName) {
    return 'Do you really want to delete $groupName?\n\nThis action cannot be undone.';
  }

  @override
  String get groupDetailDeleteGroupAction => 'Delete Group';

  @override
  String groupDetailNotificationSent(int notifiedCount) {
    return 'Notification sent to $notifiedCount devices.';
  }

  @override
  String groupDetailNotificationSentSkipped(
    int notifiedCount,
    int skippedCount,
  ) {
    return 'Notification sent to $notifiedCount devices. $skippedCount were skipped.';
  }

  @override
  String get groupsRefreshTooltip => 'Refresh';

  @override
  String get groupDetailAddMember => 'Add Member';

  @override
  String get groupDetailShowInstallationIdentifiers =>
      'Show installation identifiers';

  @override
  String get groupDetailNoDevicesInGroup => 'No devices in this group.';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Eyes Only';

  @override
  String get onboardingOrganizationUnreachable =>
      'Could not reach the server. Please check the URL and your network connection.';

  @override
  String get onboardingOrganizationInvalidQr =>
      'The scanned QR code did not contain a valid organization API URL.';

  @override
  String onboardingUnexpectedStatus(int statusCode) {
    return 'Server returned an unexpected status ($statusCode). Please check the URL.';
  }

  @override
  String get onboardingTimeout =>
      'Could not reach the server within 10 seconds.';

  @override
  String get onboardingCompleteOrganizationFirst =>
      'Complete organization setup first.';

  @override
  String get onboardingWaitingForAdminAssignment =>
      'Waiting for admin assignment before next step.';

  @override
  String get onboardingStep1Title => 'Step 1: Connect your organization';

  @override
  String get onboardingStep1Body =>
      'Enter your organization API URL. We will verify it before continuing.';

  @override
  String get onboardingOrganizationApiUrlLabel => 'Organization API URL';

  @override
  String get onboardingOrganizationApiUrlHint => 'https://api.example.com';

  @override
  String get onboardingApiUrlRequired => 'API URL is required';

  @override
  String get onboardingApiUrlInvalid => 'Enter a valid http or https URL';

  @override
  String get onboardingScanOrganizationQrAction => 'Scan organization QR code';

  @override
  String get onboardingCheckingOrganization => 'Checking organization...';

  @override
  String get onboardingCheckOrganizationAction => 'Check organization';

  @override
  String get onboardingContinueWithOrganizationPrompt =>
      'Continue with this organization?';

  @override
  String get onboardingContinueAction => 'Continue';

  @override
  String get onboardingCancelAction => 'Cancel';

  @override
  String get onboardingStep2Title => 'Step 2: Join your first group';

  @override
  String get onboardingStep2Body =>
      'Show this QR code to your organization admin. We will keep checking until this device is assigned to a group.';

  @override
  String get onboardingMembershipConfirmed => 'Group membership confirmed.';

  @override
  String get onboardingWaitingForAdminAssignmentShort =>
      'Waiting for admin assignment...';

  @override
  String get onboardingWhatIsSharedTitle => 'What is shared?';

  @override
  String get onboardingWhatIsSharedBody =>
      'This QR code shares the organization server URL, this installation identifier, and this device public key data so a main manager can register the device and add it to a selected group.';

  @override
  String onboardingInstallationIdentifier(Object installationId) {
    return 'Installation Identifier: $installationId';
  }

  @override
  String get onboardingIAmMainManagerAction => 'I am a manager';

  @override
  String get onboardingBackAction => 'Back';

  @override
  String get onboardingStep3Title => 'Step 3: Push notifications';

  @override
  String get onboardingStep3Body =>
      'Do you want to receive push notifications for new group images?';

  @override
  String get onboardingPushPrivacyBody =>
      'If enabled, this device communicates with Google Firebase servers only to receive notification events. Image content is not sent to Firebase.';

  @override
  String get onboardingPushPermissionBody =>
      'On Android 12 and lower, the system usually does not show a notification permission popup. On Android 13+ and iOS, the OS may ask for permission.';

  @override
  String get onboardingApplying => 'Applying...';

  @override
  String get onboardingEnableNotificationsAction => 'Enable notifications';

  @override
  String get onboardingNotNowAction => 'Not now';

  @override
  String get onboardingScanOrganizationQrTitle => 'Scan Organization QR Code';

  @override
  String get onboardingScanOrganizationQrInstruction =>
      'Scan the main manager organization QR code to fill the API URL.';

  @override
  String get onboardingAdminTitle => 'Admin Onboarding';

  @override
  String get onboardingAdminSetupTitle => 'Main manager setup';

  @override
  String onboardingAdminLoggedInAs(Object username) {
    return 'Logged in as $username. You can now create a group or join a group.';
  }

  @override
  String get onboardingAdminLoginPrompt =>
      'Log in with a main manager account to continue with admin actions.';

  @override
  String get onboardingAdminLoginAction => 'Log in as main manager';

  @override
  String get expirationOneDay => '1 day';

  @override
  String get expirationThreeDays => '3 days';

  @override
  String get expirationSevenDays => '7 days';

  @override
  String get expirationFourteenDays => '14 days';

  @override
  String get expirationOneMonth => '1 month';

  @override
  String get expirationExpired => 'Deleted';

  @override
  String expirationInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Will be deleted in $days days',
      one: 'Will be deleted in 1 day',
    );
    return '$_temp0';
  }

  @override
  String expirationInHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Will be deleted in $hours hours',
      one: 'Will be deleted in 1 hour',
    );
    return '$_temp0';
  }
}
