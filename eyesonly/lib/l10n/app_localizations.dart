import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsDeviceLock.
  ///
  /// In en, this message translates to:
  /// **'Device Lock'**
  String get settingsDeviceLock;

  /// No description provided for @settingsDeviceLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Require face, fingerprint, or device code'**
  String get settingsDeviceLockSubtitle;

  /// No description provided for @settingsPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get settingsPushNotifications;

  /// No description provided for @settingsPushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications when new pictures are uploaded'**
  String get settingsPushNotificationsSubtitle;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsDarkModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a darker appearance at night'**
  String get settingsDarkModeSubtitle;

  /// No description provided for @settingsManagerMode.
  ///
  /// In en, this message translates to:
  /// **'Manager Mode'**
  String get settingsManagerMode;

  /// No description provided for @settingsManagerModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable manager mode features'**
  String get settingsManagerModeSubtitle;

  /// No description provided for @settingsOrganizations.
  ///
  /// In en, this message translates to:
  /// **'Organizations'**
  String get settingsOrganizations;

  /// No description provided for @settingsNoOrganizations.
  ///
  /// In en, this message translates to:
  /// **'No organizations yet'**
  String get settingsNoOrganizations;

  /// No description provided for @settingsNoOrganizationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add an organization to connect this device.'**
  String get settingsNoOrganizationsSubtitle;

  /// No description provided for @settingsAddOrganization.
  ///
  /// In en, this message translates to:
  /// **'Add Organization'**
  String get settingsAddOrganization;

  /// No description provided for @settingsManagerSettings.
  ///
  /// In en, this message translates to:
  /// **'Manager Settings'**
  String get settingsManagerSettings;

  /// No description provided for @settingsManagerOrganization.
  ///
  /// In en, this message translates to:
  /// **'Manager Organization'**
  String get settingsManagerOrganization;

  /// No description provided for @settingsManagerAddOrgFirst.
  ///
  /// In en, this message translates to:
  /// **'Add an organization first to select a manager server.'**
  String get settingsManagerAddOrgFirst;

  /// No description provided for @settingsDeleteImageCache.
  ///
  /// In en, this message translates to:
  /// **'Delete Encrypted Image Cache'**
  String get settingsDeleteImageCache;

  /// No description provided for @settingsDeleteImageCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove locally cached encrypted image blobs'**
  String get settingsDeleteImageCacheSubtitle;

  /// No description provided for @settingsResetApp.
  ///
  /// In en, this message translates to:
  /// **'Reset App'**
  String get settingsResetApp;

  /// No description provided for @settingsResetAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove local keys, tokens, organizations, and app settings'**
  String get settingsResetAppSubtitle;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get settingsAppVersion;

  /// No description provided for @settingsRemoveOrganizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Organization'**
  String get settingsRemoveOrganizationTitle;

  /// No description provided for @settingsRemoveOrganizationContent.
  ///
  /// In en, this message translates to:
  /// **'Do you want to remove {name} from this device?\n\nThis only removes the local organization entry.'**
  String settingsRemoveOrganizationContent(String name);

  /// No description provided for @settingsDeleteCache.
  ///
  /// In en, this message translates to:
  /// **'Delete Cache'**
  String get settingsDeleteCache;

  /// No description provided for @settingsDeleteImageCacheDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Encrypted Image Cache'**
  String get settingsDeleteImageCacheDialogTitle;

  /// No description provided for @settingsDeleteImageCacheDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Delete all locally cached encrypted image blobs from this device?\n\nThe next time you open Photos, encrypted blobs will be fetched again and decrypted when viewed.'**
  String get settingsDeleteImageCacheDialogContent;

  /// No description provided for @settingsImageCacheDeleted.
  ///
  /// In en, this message translates to:
  /// **'Image cache deleted.'**
  String get settingsImageCacheDeleted;

  /// No description provided for @settingsImageCacheDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete image cache.'**
  String get settingsImageCacheDeleteFailed;

  /// No description provided for @settingsAddOrgFirst.
  ///
  /// In en, this message translates to:
  /// **'Add an organization first.'**
  String get settingsAddOrgFirst;

  /// No description provided for @settingsResetAppDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset App'**
  String get settingsResetAppDialogTitle;

  /// No description provided for @settingsResetAppDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Warning: Resetting the app will remove local keys, tokens, installation identity, organizations, cached images, and app settings. This action cannot be undone.\n\nAre you sure you want to continue?'**
  String get settingsResetAppDialogContent;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// No description provided for @settingsDeviceLockNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'No device authentication is available on this device.'**
  String get settingsDeviceLockNotAvailable;

  /// No description provided for @settingsDeviceLockNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Device lock was not enabled.'**
  String get settingsDeviceLockNotEnabled;

  /// No description provided for @settingsPushNotificationsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update push notifications.'**
  String get settingsPushNotificationsFailed;

  /// No description provided for @settingsAppVersionValue.
  ///
  /// In en, this message translates to:
  /// **'1.0.0'**
  String get settingsAppVersionValue;

  /// No description provided for @unexpectedErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get unexpectedErrorOccurred;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Eyes Only'**
  String get appTitle;

  /// No description provided for @unlockReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Eyes Only'**
  String get unlockReason;

  /// No description provided for @lockNoAuthAvailable.
  ///
  /// In en, this message translates to:
  /// **'No device authentication is available.'**
  String get lockNoAuthAvailable;

  /// No description provided for @lockUnlockRequired.
  ///
  /// In en, this message translates to:
  /// **'Unlock required to continue.'**
  String get lockUnlockRequired;

  /// No description provided for @lockAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Device authentication failed.'**
  String get lockAuthFailed;

  /// No description provided for @appLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Eyes Only is locked'**
  String get appLockedTitle;

  /// No description provided for @appLockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Use face, fingerprint, or your device code to continue.'**
  String get appLockedMessage;

  /// No description provided for @unlocking.
  ///
  /// In en, this message translates to:
  /// **'Unlocking...'**
  String get unlocking;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @homeMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get homeMenu;

  /// No description provided for @homeTabPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get homeTabPhotos;

  /// No description provided for @homeTabGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get homeTabGroups;

  /// No description provided for @homeTabAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get homeTabAccount;

  /// No description provided for @homeTabLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get homeTabLogIn;

  /// No description provided for @homeTabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeTabSettings;

  /// No description provided for @homeTabAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get homeTabAbout;

  /// No description provided for @managerServerNotSet.
  ///
  /// In en, this message translates to:
  /// **'Manager server URL is not set.'**
  String get managerServerNotSet;

  /// No description provided for @notifyWhenImagesLoading.
  ///
  /// In en, this message translates to:
  /// **'This group cannot be notified until its images finish loading.'**
  String get notifyWhenImagesLoading;

  /// No description provided for @notificationSent.
  ///
  /// In en, this message translates to:
  /// **'Notification sent to {count} devices.'**
  String notificationSent(int count);

  /// No description provided for @notificationSentWithSkipped.
  ///
  /// In en, this message translates to:
  /// **'Notification sent to {notified} devices. {skipped} were skipped.'**
  String notificationSentWithSkipped(int notified, int skipped);

  /// No description provided for @imageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Image deleted.'**
  String get imageDeleted;

  /// No description provided for @homeTakePicture.
  ///
  /// In en, this message translates to:
  /// **'Take Picture'**
  String get homeTakePicture;

  /// No description provided for @homeSendMessageToGroup.
  ///
  /// In en, this message translates to:
  /// **'Send Message to Group'**
  String get homeSendMessageToGroup;

  /// No description provided for @homeRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetry;

  /// No description provided for @homeNoImages.
  ///
  /// In en, this message translates to:
  /// **'Currently there are no images for you'**
  String get homeNoImages;

  /// No description provided for @homeNoGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'You are not in any groups yet.'**
  String get homeNoGroupsYet;

  /// No description provided for @homeJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get homeJoinGroup;

  /// No description provided for @groupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsTitle;

  /// No description provided for @groupsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get groupsRefresh;

  /// No description provided for @groupsCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get groupsCreateGroup;

  /// No description provided for @groupsError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String groupsError(Object message);

  /// No description provided for @groupsAddOrganizationToSeeGroups.
  ///
  /// In en, this message translates to:
  /// **'Add an organization to see its groups here.'**
  String get groupsAddOrganizationToSeeGroups;

  /// No description provided for @groupsNoGroups.
  ///
  /// In en, this message translates to:
  /// **'No groups'**
  String get groupsNoGroups;

  /// No description provided for @groupsJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get groupsJoinGroup;

  /// No description provided for @groupsLeaveGroup.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get groupsLeaveGroup;

  /// No description provided for @groupsShareOrganization.
  ///
  /// In en, this message translates to:
  /// **'Share Organization'**
  String get groupsShareOrganization;

  /// No description provided for @groupsFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Group {shortId}'**
  String groupsFallbackName(Object shortId);

  /// No description provided for @groupsServerTimeoutWithUrl.
  ///
  /// In en, this message translates to:
  /// **'Could not reach {apiUrl} within 10 seconds.'**
  String groupsServerTimeoutWithUrl(Object apiUrl);

  /// No description provided for @groupsServerTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server within 10 seconds.'**
  String get groupsServerTimeout;

  /// No description provided for @homeApiUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the API. Please check your connection and try again.'**
  String get homeApiUnreachable;

  /// No description provided for @homeOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline.'**
  String get homeOffline;

  /// No description provided for @homeNoInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please connect and try again.'**
  String get homeNoInternetConnection;

  /// No description provided for @homeLoadingImages.
  ///
  /// In en, this message translates to:
  /// **'Loading images...'**
  String get homeLoadingImages;

  /// No description provided for @homeLookingForNewPhotos.
  ///
  /// In en, this message translates to:
  /// **'Looking for new photos...'**
  String get homeLookingForNewPhotos;

  /// No description provided for @homeDownloadingNewImages.
  ///
  /// In en, this message translates to:
  /// **'Downloading new images...'**
  String get homeDownloadingNewImages;

  /// No description provided for @homeNoNewImagesFound.
  ///
  /// In en, this message translates to:
  /// **'No new images found.'**
  String get homeNoNewImagesFound;

  /// No description provided for @homeUnknownDay.
  ///
  /// In en, this message translates to:
  /// **'Unknown day'**
  String get homeUnknownDay;

  /// No description provided for @homeDeleteImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Image'**
  String get homeDeleteImageTitle;

  /// No description provided for @homeDeleteImageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this image from the server for this group? This action cannot be undone.'**
  String get homeDeleteImageConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @homeCollapseCaption.
  ///
  /// In en, this message translates to:
  /// **'Collapse caption'**
  String get homeCollapseCaption;

  /// No description provided for @homeShowCaption.
  ///
  /// In en, this message translates to:
  /// **'Show caption'**
  String get homeShowCaption;

  /// No description provided for @homeDeleteImageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete image'**
  String get homeDeleteImageTooltip;

  /// No description provided for @failedToDecryptImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to decrypt image'**
  String get failedToDecryptImage;

  /// No description provided for @captureNoCameraAvailable.
  ///
  /// In en, this message translates to:
  /// **'No camera is available on this device.'**
  String get captureNoCameraAvailable;

  /// No description provided for @captureFlashModeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change flash mode. Please try again.'**
  String get captureFlashModeFailed;

  /// No description provided for @captureTakePhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not take photo. Please try again.'**
  String get captureTakePhotoFailed;

  /// No description provided for @pictureDeleted.
  ///
  /// In en, this message translates to:
  /// **'Picture deleted.'**
  String get pictureDeleted;

  /// No description provided for @flashAuto.
  ///
  /// In en, this message translates to:
  /// **'Flash Auto'**
  String get flashAuto;

  /// No description provided for @flashOn.
  ///
  /// In en, this message translates to:
  /// **'Flash On'**
  String get flashOn;

  /// No description provided for @flashOff.
  ///
  /// In en, this message translates to:
  /// **'Flash Off'**
  String get flashOff;

  /// No description provided for @retryCamera.
  ///
  /// In en, this message translates to:
  /// **'Retry Camera'**
  String get retryCamera;

  /// No description provided for @switchCamera.
  ///
  /// In en, this message translates to:
  /// **'Switch Camera'**
  String get switchCamera;

  /// No description provided for @sendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendTitle;

  /// No description provided for @sendSuccess.
  ///
  /// In en, this message translates to:
  /// **'Encrypted image sent to {count} devices.'**
  String sendSuccess(int count);

  /// No description provided for @sendAddTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get sendAddTextLabel;

  /// No description provided for @sendAddTextHint.
  ///
  /// In en, this message translates to:
  /// **'Add optional text for this image'**
  String get sendAddTextHint;

  /// No description provided for @sendDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sendDelete;

  /// No description provided for @sendSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sendSending;

  /// No description provided for @sendFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Sending failed. Please try again.'**
  String get sendFailedTryAgain;

  /// No description provided for @sendSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendSend;

  /// No description provided for @sendSelectExpirationTitle.
  ///
  /// In en, this message translates to:
  /// **'Select deletion time'**
  String get sendSelectExpirationTitle;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @sendPhotoExpiration.
  ///
  /// In en, this message translates to:
  /// **'Will be deleted at'**
  String get sendPhotoExpiration;

  /// No description provided for @expiresToday.
  ///
  /// In en, this message translates to:
  /// **'Will be deleted today'**
  String get expiresToday;

  /// No description provided for @createGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroupTitle;

  /// No description provided for @createGroupHeading.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get createGroupHeading;

  /// No description provided for @createGroupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get createGroupNameLabel;

  /// No description provided for @createGroupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get createGroupNameRequired;

  /// No description provided for @createGroupCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get createGroupCreating;

  /// No description provided for @createGroupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group created successfully.'**
  String get createGroupSuccess;

  /// No description provided for @createGroupCreatorNotLinkedError.
  ///
  /// In en, this message translates to:
  /// **'Creator device was not linked to the new group.'**
  String get createGroupCreatorNotLinkedError;

  /// No description provided for @createGroupNoLoggedInManagerError.
  ///
  /// In en, this message translates to:
  /// **'No logged-in manager account found for device registration.'**
  String get createGroupNoLoggedInManagerError;

  /// No description provided for @createGroupNoUuidError.
  ///
  /// In en, this message translates to:
  /// **'Group was created but server returned no UUID.'**
  String get createGroupNoUuidError;

  /// No description provided for @joinGroupPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Group'**
  String get joinGroupPageTitle;

  /// No description provided for @joinGroupQrInstruction.
  ///
  /// In en, this message translates to:
  /// **'Have a main manager scan this QR code and choose the group.'**
  String get joinGroupQrInstruction;

  /// No description provided for @joinGroupQrWhatIsSharedTitle.
  ///
  /// In en, this message translates to:
  /// **'What is shared?'**
  String get joinGroupQrWhatIsSharedTitle;

  /// No description provided for @joinGroupQrWhatIsSharedBody.
  ///
  /// In en, this message translates to:
  /// **'This QR code shares the organization server URL, this installation identifier, and this device public key data so a main manager can register the device and add it to a selected group.'**
  String get joinGroupQrWhatIsSharedBody;

  /// No description provided for @joinGroupQrInstallationId.
  ///
  /// In en, this message translates to:
  /// **'Installation Identifier: {installationId}'**
  String joinGroupQrInstallationId(Object installationId);

  /// No description provided for @aboutInstallationIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Installation Identifier'**
  String get aboutInstallationIdentifier;

  /// No description provided for @aboutHiddenValue.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get aboutHiddenValue;

  /// No description provided for @aboutHideIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Hide Identifier'**
  String get aboutHideIdentifier;

  /// No description provided for @aboutShowIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Show Identifier'**
  String get aboutShowIdentifier;

  /// No description provided for @accountNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get accountNotLoggedIn;

  /// No description provided for @accountLoggingOut.
  ///
  /// In en, this message translates to:
  /// **'Logging Out...'**
  String get accountLoggingOut;

  /// No description provided for @accountLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get accountLogOut;

  /// No description provided for @shareOrganizationQrInstruction.
  ///
  /// In en, this message translates to:
  /// **'Have the other device scan this QR code to add this organization.'**
  String get shareOrganizationQrInstruction;

  /// No description provided for @groupPushFixedMessageIntro.
  ///
  /// In en, this message translates to:
  /// **'The notification message is fixed for privacy reasons:'**
  String get groupPushFixedMessageIntro;

  /// No description provided for @selectCaptureNoManagerGroups.
  ///
  /// In en, this message translates to:
  /// **'You are not a manager for any groups yet.'**
  String get selectCaptureNoManagerGroups;

  /// No description provided for @loginRegisterThisDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Register This Device'**
  String get loginRegisterThisDeviceTitle;

  /// No description provided for @loginRegisterThisDeviceContent.
  ///
  /// In en, this message translates to:
  /// **'This device is not registered yet. On your already-registered manager device, tap \"Register Manager Device\" and scan the QR code shown here.'**
  String get loginRegisterThisDeviceContent;

  /// No description provided for @loginLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get loginLater;

  /// No description provided for @loginShowQrCode.
  ///
  /// In en, this message translates to:
  /// **'Show QR Code'**
  String get loginShowQrCode;

  /// No description provided for @loginServerUrlNotSet.
  ///
  /// In en, this message translates to:
  /// **'Server URL is not set. Configure it in Settings.'**
  String get loginServerUrlNotSet;

  /// No description provided for @loginSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get loginSuccessful;

  /// No description provided for @loginFailedTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailedTryAgain;

  /// No description provided for @loginManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Manager Login'**
  String get loginManagerTitle;

  /// No description provided for @loginOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'This app supports login only. Registration is disabled.'**
  String get loginOnlyMessage;

  /// No description provided for @loginUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get loginUsernameLabel;

  /// No description provided for @loginUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get loginUsernameRequired;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get loginPasswordRequired;

  /// No description provided for @loginLoggingIn.
  ///
  /// In en, this message translates to:
  /// **'Logging In...'**
  String get loginLoggingIn;

  /// No description provided for @scanQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrTitle;

  /// No description provided for @scanQrInstruction.
  ///
  /// In en, this message translates to:
  /// **'Scan the manager\'s organization QR code to fill the API URL.'**
  String get scanQrInstruction;

  /// No description provided for @scanQrInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code did not contain valid JSON data.'**
  String get scanQrInvalidJson;

  /// No description provided for @addOrganizationApiUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'API URL'**
  String get addOrganizationApiUrlLabel;

  /// No description provided for @addOrganizationApiUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://api.example.com'**
  String get addOrganizationApiUrlHint;

  /// No description provided for @addOrganizationApiUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'API URL is required'**
  String get addOrganizationApiUrlRequired;

  /// No description provided for @addOrganizationApiUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http or https URL'**
  String get addOrganizationApiUrlInvalid;

  /// No description provided for @addOrganizationApiUrlDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This API URL has already been added'**
  String get addOrganizationApiUrlDuplicate;

  /// No description provided for @addOrganizationChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking organization...'**
  String get addOrganizationChecking;

  /// No description provided for @addOrganizationCheckAction.
  ///
  /// In en, this message translates to:
  /// **'Check Organization'**
  String get addOrganizationCheckAction;

  /// No description provided for @addOrganizationConfirmPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add this organization?'**
  String get addOrganizationConfirmPrompt;

  /// No description provided for @addOrganizationAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addOrganizationAdd;

  /// No description provided for @addOrganizationCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get addOrganizationCancel;

  /// No description provided for @addOrganizationInvalidQr.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code did not contain a valid API URL.'**
  String get addOrganizationInvalidQr;

  /// No description provided for @addOrganizationUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Please check the URL and your network connection.'**
  String get addOrganizationUnreachable;

  /// No description provided for @addOrganizationTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server within 10 seconds.'**
  String get addOrganizationTimeout;

  /// No description provided for @addOrganizationUnexpectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Server returned an unexpected status ({statusCode}). Please check the URL.'**
  String addOrganizationUnexpectedStatus(int statusCode);

  /// No description provided for @groupAddScanDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Device'**
  String get groupAddScanDeviceTitle;

  /// No description provided for @groupAddScanDeviceInstruction.
  ///
  /// In en, this message translates to:
  /// **'Scan the device QR code to capture its installation identifier and public key.'**
  String get groupAddScanDeviceInstruction;

  /// No description provided for @groupAddServerUrlMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Server URL mismatch'**
  String get groupAddServerUrlMismatchTitle;

  /// No description provided for @groupAddServerUrlMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'The scanned device is registered to a different server address than the one you are currently managing. This may be normal if the same server is reachable at multiple addresses (e.g. emulator vs. physical device on the same network).'**
  String get groupAddServerUrlMismatchBody;

  /// No description provided for @groupAddCurrentServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Current server:'**
  String get groupAddCurrentServerLabel;

  /// No description provided for @groupAddDeviceServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Device server:'**
  String get groupAddDeviceServerLabel;

  /// No description provided for @groupAddServerUrlMismatchWarning.
  ///
  /// In en, this message translates to:
  /// **'Only continue if you are sure both addresses point to the same server.'**
  String get groupAddServerUrlMismatchWarning;

  /// No description provided for @groupAddCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get groupAddCancel;

  /// No description provided for @groupAddAddAnyway.
  ///
  /// In en, this message translates to:
  /// **'Add anyway'**
  String get groupAddAddAnyway;

  /// No description provided for @groupAddAddedMember.
  ///
  /// In en, this message translates to:
  /// **'Added {name} to {groupName}.'**
  String groupAddAddedMember(Object name, Object groupName);

  /// No description provided for @groupAddStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get groupAddStatusReady;

  /// No description provided for @groupAddStatusRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get groupAddStatusRequired;

  /// No description provided for @groupAddDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Device'**
  String get groupAddDeviceTitle;

  /// No description provided for @groupAddNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get groupAddNameLabel;

  /// No description provided for @groupAddNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for this device'**
  String get groupAddNameHint;

  /// No description provided for @groupAddNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get groupAddNameRequired;

  /// No description provided for @groupAddDeviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get groupAddDeviceLabel;

  /// No description provided for @groupAddScanDeviceAction.
  ///
  /// In en, this message translates to:
  /// **'Scan Device'**
  String get groupAddScanDeviceAction;

  /// No description provided for @groupAddAddingDevice.
  ///
  /// In en, this message translates to:
  /// **'Adding Device...'**
  String get groupAddAddingDevice;

  /// No description provided for @groupAddDeviceAction.
  ///
  /// In en, this message translates to:
  /// **'Add Device'**
  String get groupAddDeviceAction;

  /// No description provided for @groupAddNotJoinCode.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code is not a device join code.'**
  String get groupAddNotJoinCode;

  /// No description provided for @groupAddMissingManagerRequestData.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code is missing manager request data.'**
  String get groupAddMissingManagerRequestData;

  /// No description provided for @groupAddMissingRegisterData.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code is missing register-device data.'**
  String get groupAddMissingRegisterData;

  /// No description provided for @groupAddMissingRequiredData.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code is missing required device data.'**
  String get groupAddMissingRequiredData;

  /// No description provided for @groupAddManagerDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Manager Device'**
  String get groupAddManagerDeviceTitle;

  /// No description provided for @groupAddManagerInstruction.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code shown on the other manager\'s device (Groups → Join Group) while they are logged in as a manager.'**
  String get groupAddManagerInstruction;

  /// No description provided for @groupAddManagerDeviceAction.
  ///
  /// In en, this message translates to:
  /// **'Add Manager Device'**
  String get groupAddManagerDeviceAction;

  /// No description provided for @groupAddManagerScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Manager Device'**
  String get groupAddManagerScanTitle;

  /// No description provided for @groupAddManagerScanInstruction.
  ///
  /// In en, this message translates to:
  /// **'On the other manager\'s device, go to Groups → Join Group and scan the QR code shown there.'**
  String get groupAddManagerScanInstruction;

  /// No description provided for @groupAddManagerServerUrlMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'The scanned device reports a different server address. This may be normal if both addresses point to the same server (e.g. emulator vs. physical device).'**
  String get groupAddManagerServerUrlMismatchBody;

  /// No description provided for @groupAddManagerMissingOwnerUser.
  ///
  /// In en, this message translates to:
  /// **'This QR code does not include a manager account. Make sure the other manager is logged in before showing the QR code.'**
  String get groupAddManagerMissingOwnerUser;

  /// No description provided for @registerManagerDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Manager Device'**
  String get registerManagerDeviceTitle;

  /// No description provided for @registerManagerDeviceInstruction.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code shown on the second manager device (Groups → Join Group) to register it as an additional device for your account.'**
  String get registerManagerDeviceInstruction;

  /// No description provided for @registerManagerDeviceGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get registerManagerDeviceGenerating;

  /// No description provided for @registerManagerDeviceGenerateQrCode.
  ///
  /// In en, this message translates to:
  /// **'Generate QR Code'**
  String get registerManagerDeviceGenerateQrCode;

  /// No description provided for @registerManagerDeviceServerUrlMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Server URL mismatch'**
  String get registerManagerDeviceServerUrlMismatchTitle;

  /// No description provided for @registerManagerDeviceServerUrlMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'The scanned device is registered to a different server address. This may be normal if both addresses point to the same server (e.g. emulator vs. physical device on the same network).'**
  String get registerManagerDeviceServerUrlMismatchBody;

  /// No description provided for @registerManagerDeviceCurrentServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Current server:'**
  String get registerManagerDeviceCurrentServerLabel;

  /// No description provided for @registerManagerDeviceDeviceServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Device server:'**
  String get registerManagerDeviceDeviceServerLabel;

  /// No description provided for @registerManagerDeviceServerUrlMismatchWarning.
  ///
  /// In en, this message translates to:
  /// **'Only continue if you are sure both addresses point to the same server.'**
  String get registerManagerDeviceServerUrlMismatchWarning;

  /// No description provided for @registerManagerDeviceCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get registerManagerDeviceCancel;

  /// No description provided for @registerManagerDeviceContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get registerManagerDeviceContinue;

  /// No description provided for @registerManagerDeviceSuccess.
  ///
  /// In en, this message translates to:
  /// **'Device registered successfully.'**
  String get registerManagerDeviceSuccess;

  /// No description provided for @registerManagerDeviceScanned.
  ///
  /// In en, this message translates to:
  /// **'Device scanned'**
  String get registerManagerDeviceScanned;

  /// No description provided for @registerManagerDeviceScanRequired.
  ///
  /// In en, this message translates to:
  /// **'Scan required'**
  String get registerManagerDeviceScanRequired;

  /// No description provided for @registerManagerDeviceScanDeviceQr.
  ///
  /// In en, this message translates to:
  /// **'Scan Device QR'**
  String get registerManagerDeviceScanDeviceQr;

  /// No description provided for @registerManagerDeviceRegistering.
  ///
  /// In en, this message translates to:
  /// **'Registering...'**
  String get registerManagerDeviceRegistering;

  /// No description provided for @registerManagerDeviceRegisterAction.
  ///
  /// In en, this message translates to:
  /// **'Register Device'**
  String get registerManagerDeviceRegisterAction;

  /// No description provided for @registerManagerDeviceScanInstruction.
  ///
  /// In en, this message translates to:
  /// **'On the second device, go to Groups → Join Group and scan that QR code here.'**
  String get registerManagerDeviceScanInstruction;

  /// No description provided for @registerManagerDeviceNotJoinCode.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code is not a device join code.'**
  String get registerManagerDeviceNotJoinCode;

  /// No description provided for @registerManagerDeviceMissingManagerRequestData.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code is missing manager request data.'**
  String get registerManagerDeviceMissingManagerRequestData;

  /// No description provided for @registerManagerDeviceMissingRegisterData.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code is missing register-device data.'**
  String get registerManagerDeviceMissingRegisterData;

  /// No description provided for @registerManagerDeviceMissingRequiredData.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code is missing required device data.'**
  String get registerManagerDeviceMissingRequiredData;

  /// No description provided for @groupDetailDecryptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Decryption failed'**
  String get groupDetailDecryptionFailed;

  /// No description provided for @groupDetailRemovedFromGroup.
  ///
  /// In en, this message translates to:
  /// **'Removed {ownerName} from the group.'**
  String groupDetailRemovedFromGroup(Object ownerName);

  /// No description provided for @groupDetailRemoveDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Device?'**
  String get groupDetailRemoveDeviceTitle;

  /// No description provided for @groupDetailRemoveDevicePrompt.
  ///
  /// In en, this message translates to:
  /// **'Remove {ownerName} from this group?'**
  String groupDetailRemoveDevicePrompt(Object ownerName);

  /// No description provided for @groupDetailCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get groupDetailCancel;

  /// No description provided for @groupDetailRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get groupDetailRemoveAction;

  /// No description provided for @groupDetailLeaveGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Group?'**
  String get groupDetailLeaveGroupTitle;

  /// No description provided for @groupDetailLeaveGroupPrompt.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to leave {groupName}?\n\nOnly a manager can re-add you to this group.'**
  String groupDetailLeaveGroupPrompt(Object groupName);

  /// No description provided for @groupDetailLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get groupDetailLeaveAction;

  /// No description provided for @groupDetailDeleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Group?'**
  String get groupDetailDeleteGroupTitle;

  /// No description provided for @groupDetailDeleteGroupPrompt.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to delete {groupName}?\n\nThis action cannot be undone.'**
  String groupDetailDeleteGroupPrompt(Object groupName);

  /// No description provided for @groupDetailDeleteGroupAction.
  ///
  /// In en, this message translates to:
  /// **'Delete Group'**
  String get groupDetailDeleteGroupAction;

  /// No description provided for @groupDetailNotificationSent.
  ///
  /// In en, this message translates to:
  /// **'Notification sent to {notifiedCount} devices.'**
  String groupDetailNotificationSent(int notifiedCount);

  /// No description provided for @groupDetailNotificationSentSkipped.
  ///
  /// In en, this message translates to:
  /// **'Notification sent to {notifiedCount} devices. {skippedCount} were skipped.'**
  String groupDetailNotificationSentSkipped(
    int notifiedCount,
    int skippedCount,
  );

  /// No description provided for @groupsRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get groupsRefreshTooltip;

  /// No description provided for @groupDetailAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get groupDetailAddMember;

  /// No description provided for @groupDetailShowInstallationIdentifiers.
  ///
  /// In en, this message translates to:
  /// **'Show installation identifiers'**
  String get groupDetailShowInstallationIdentifiers;

  /// No description provided for @groupDetailNoDevicesInGroup.
  ///
  /// In en, this message translates to:
  /// **'No devices in this group.'**
  String get groupDetailNoDevicesInGroup;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Eyes Only'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingOrganizationUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Please check the URL and your network connection.'**
  String get onboardingOrganizationUnreachable;

  /// No description provided for @onboardingOrganizationInvalidQr.
  ///
  /// In en, this message translates to:
  /// **'The scanned QR code did not contain a valid organization API URL.'**
  String get onboardingOrganizationInvalidQr;

  /// No description provided for @onboardingUnexpectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Server returned an unexpected status ({statusCode}). Please check the URL.'**
  String onboardingUnexpectedStatus(int statusCode);

  /// No description provided for @onboardingTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server within 10 seconds.'**
  String get onboardingTimeout;

  /// No description provided for @onboardingCompleteOrganizationFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete organization setup first.'**
  String get onboardingCompleteOrganizationFirst;

  /// No description provided for @onboardingWaitingForAdminAssignment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for admin assignment before next step.'**
  String get onboardingWaitingForAdminAssignment;

  /// No description provided for @onboardingStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Connect your organization'**
  String get onboardingStep1Title;

  /// No description provided for @onboardingStep1Body.
  ///
  /// In en, this message translates to:
  /// **'Enter your organization API URL. We will verify it before continuing.'**
  String get onboardingStep1Body;

  /// No description provided for @onboardingOrganizationApiUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Organization API URL'**
  String get onboardingOrganizationApiUrlLabel;

  /// No description provided for @onboardingOrganizationApiUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://api.example.com'**
  String get onboardingOrganizationApiUrlHint;

  /// No description provided for @onboardingApiUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'API URL is required'**
  String get onboardingApiUrlRequired;

  /// No description provided for @onboardingApiUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http or https URL'**
  String get onboardingApiUrlInvalid;

  /// No description provided for @onboardingScanOrganizationQrAction.
  ///
  /// In en, this message translates to:
  /// **'Scan organization QR code'**
  String get onboardingScanOrganizationQrAction;

  /// No description provided for @onboardingCheckingOrganization.
  ///
  /// In en, this message translates to:
  /// **'Checking organization...'**
  String get onboardingCheckingOrganization;

  /// No description provided for @onboardingCheckOrganizationAction.
  ///
  /// In en, this message translates to:
  /// **'Check organization'**
  String get onboardingCheckOrganizationAction;

  /// No description provided for @onboardingContinueWithOrganizationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Continue with this organization?'**
  String get onboardingContinueWithOrganizationPrompt;

  /// No description provided for @onboardingContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinueAction;

  /// No description provided for @onboardingCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get onboardingCancelAction;

  /// No description provided for @onboardingStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Join your first group'**
  String get onboardingStep2Title;

  /// No description provided for @onboardingStep2Body.
  ///
  /// In en, this message translates to:
  /// **'Show this QR code to your organization admin. We will keep checking until this device is assigned to a group.'**
  String get onboardingStep2Body;

  /// No description provided for @onboardingMembershipConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Group membership confirmed.'**
  String get onboardingMembershipConfirmed;

  /// No description provided for @onboardingWaitingForAdminAssignmentShort.
  ///
  /// In en, this message translates to:
  /// **'Waiting for admin assignment...'**
  String get onboardingWaitingForAdminAssignmentShort;

  /// No description provided for @onboardingWhatIsSharedTitle.
  ///
  /// In en, this message translates to:
  /// **'What is shared?'**
  String get onboardingWhatIsSharedTitle;

  /// No description provided for @onboardingWhatIsSharedBody.
  ///
  /// In en, this message translates to:
  /// **'This QR code shares the organization server URL, this installation identifier, and this device public key data so a main manager can register the device and add it to a selected group.'**
  String get onboardingWhatIsSharedBody;

  /// No description provided for @onboardingInstallationIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Installation Identifier: {installationId}'**
  String onboardingInstallationIdentifier(Object installationId);

  /// No description provided for @onboardingIAmMainManagerAction.
  ///
  /// In en, this message translates to:
  /// **'I am a manager'**
  String get onboardingIAmMainManagerAction;

  /// No description provided for @onboardingBackAction.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBackAction;

  /// No description provided for @onboardingStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Step 3: Push notifications'**
  String get onboardingStep3Title;

  /// No description provided for @onboardingStep3Body.
  ///
  /// In en, this message translates to:
  /// **'Do you want to receive push notifications for new group images?'**
  String get onboardingStep3Body;

  /// No description provided for @onboardingPushPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'If enabled, this device communicates with Google Firebase servers only to receive notification events. Image content is not sent to Firebase.'**
  String get onboardingPushPrivacyBody;

  /// No description provided for @onboardingPushPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'On Android 12 and lower, the system usually does not show a notification permission popup. On Android 13+ and iOS, the OS may ask for permission.'**
  String get onboardingPushPermissionBody;

  /// No description provided for @onboardingApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying...'**
  String get onboardingApplying;

  /// No description provided for @onboardingEnableNotificationsAction.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get onboardingEnableNotificationsAction;

  /// No description provided for @onboardingNotNowAction.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get onboardingNotNowAction;

  /// No description provided for @onboardingScanOrganizationQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Organization QR Code'**
  String get onboardingScanOrganizationQrTitle;

  /// No description provided for @onboardingScanOrganizationQrInstruction.
  ///
  /// In en, this message translates to:
  /// **'Scan the main manager organization QR code to fill the API URL.'**
  String get onboardingScanOrganizationQrInstruction;

  /// No description provided for @onboardingAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Onboarding'**
  String get onboardingAdminTitle;

  /// No description provided for @onboardingAdminSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Main manager setup'**
  String get onboardingAdminSetupTitle;

  /// No description provided for @onboardingAdminLoggedInAs.
  ///
  /// In en, this message translates to:
  /// **'Logged in as {username}. You can now create a group or join a group.'**
  String onboardingAdminLoggedInAs(Object username);

  /// No description provided for @onboardingAdminLoginPrompt.
  ///
  /// In en, this message translates to:
  /// **'Log in with a main manager account to continue with admin actions.'**
  String get onboardingAdminLoginPrompt;

  /// No description provided for @onboardingAdminLoginAction.
  ///
  /// In en, this message translates to:
  /// **'Log in as main manager'**
  String get onboardingAdminLoginAction;

  /// No description provided for @expirationOneDay.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get expirationOneDay;

  /// No description provided for @expirationThreeDays.
  ///
  /// In en, this message translates to:
  /// **'3 days'**
  String get expirationThreeDays;

  /// No description provided for @expirationSevenDays.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get expirationSevenDays;

  /// No description provided for @expirationFourteenDays.
  ///
  /// In en, this message translates to:
  /// **'14 days'**
  String get expirationFourteenDays;

  /// No description provided for @expirationOneMonth.
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get expirationOneMonth;

  /// No description provided for @expirationExpired.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get expirationExpired;

  /// No description provided for @expirationInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Will be deleted in 1 day} other{Will be deleted in {days} days}}'**
  String expirationInDays(int days);

  /// No description provided for @expirationInHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{Will be deleted in 1 hour} other{Will be deleted in {hours} hours}}'**
  String expirationInHours(int hours);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
