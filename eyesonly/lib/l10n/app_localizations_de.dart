// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsGeneral => 'Allgemein';

  @override
  String get settingsDeviceLock => 'Gerätesperre';

  @override
  String get settingsDeviceLockSubtitle =>
      'Gesicht, Fingerabdruck oder Gerätecode erforderlich';

  @override
  String get settingsPushNotifications => 'Push-Benachrichtigungen';

  @override
  String get settingsPushNotificationsSubtitle =>
      'Benachrichtigungen erhalten, wenn neue Bilder hochgeladen werden';

  @override
  String get settingsDarkMode => 'Dunkelmodus';

  @override
  String get settingsDarkModeSubtitle =>
      'Nachts ein dunkleres Design verwenden';

  @override
  String get settingsManagerMode => 'Manager-Modus';

  @override
  String get settingsManagerModeSubtitle =>
      'Funktionen für den Manager-Modus aktivieren';

  @override
  String get settingsOrganizations => 'Organisationen';

  @override
  String get settingsNoOrganizations => 'Noch keine Organisationen';

  @override
  String get settingsNoOrganizationsSubtitle =>
      'Füge eine Organisation hinzu, um dieses Gerät zu verbinden.';

  @override
  String get settingsAddOrganization => 'Organisation hinzufügen';

  @override
  String get settingsManagerSettings => 'Manager-Einstellungen';

  @override
  String get settingsManagerOrganization => 'Manager-Organisation';

  @override
  String get settingsManagerAddOrgFirst =>
      'Füge zuerst eine Organisation hinzu, um einen Manager-Server auszuwählen.';

  @override
  String get settingsDeleteImageCache => 'Verschlüsselten Bild-Cache löschen';

  @override
  String get settingsDeleteImageCacheSubtitle =>
      'Lokal zwischengespeicherte verschlüsselte Bilddaten entfernen';

  @override
  String get settingsResetApp => 'App zurücksetzen';

  @override
  String get settingsResetAppSubtitle =>
      'Lokale Schlüssel, Token, Organisationen und App-Einstellungen entfernen';

  @override
  String get settingsAppVersion => 'App-Version';

  @override
  String get settingsRemoveOrganizationTitle => 'Organisation entfernen';

  @override
  String settingsRemoveOrganizationContent(String name) {
    return 'Möchtest du $name von diesem Gerät entfernen?\n\nDadurch wird nur der lokale Organisationseintrag entfernt.';
  }

  @override
  String get settingsDeleteCache => 'Cache löschen';

  @override
  String get settingsDeleteImageCacheDialogTitle =>
      'Verschlüsselten Bild-Cache löschen';

  @override
  String get settingsDeleteImageCacheDialogContent =>
      'Alle lokal zwischengespeicherten verschlüsselten Bilddaten von diesem Gerät löschen?\n\nBeim nächsten Öffnen von Fotos werden verschlüsselte Bilddaten erneut geladen und erst beim Anzeigen entschlüsselt.';

  @override
  String get settingsImageCacheDeleted => 'Bild-Cache gelöscht.';

  @override
  String get settingsImageCacheDeleteFailed =>
      'Bild-Cache konnte nicht gelöscht werden.';

  @override
  String get settingsAddOrgFirst => 'Füge zuerst eine Organisation hinzu.';

  @override
  String get settingsResetAppDialogTitle => 'App zurücksetzen';

  @override
  String get settingsResetAppDialogContent =>
      'Warnung: Beim Zurücksetzen der App werden lokale Schlüssel, Token, Installationsidentität, Organisationen, zwischengespeicherte Bilder und App-Einstellungen entfernt. Diese Aktion kann nicht rückgängig gemacht werden.\n\nMöchtest du wirklich fortfahren?';

  @override
  String get settingsReset => 'Zurücksetzen';

  @override
  String get settingsDeviceLockNotAvailable =>
      'Auf diesem Gerät ist keine Geräteauthentifizierung verfügbar.';

  @override
  String get settingsDeviceLockNotEnabled =>
      'Gerätesperre wurde nicht aktiviert.';

  @override
  String get settingsPushNotificationsFailed =>
      'Push-Benachrichtigungen konnten nicht aktualisiert werden.';

  @override
  String get settingsAppVersionValue => '1.0.0';

  @override
  String get unexpectedErrorOccurred =>
      'Ein unerwarteter Fehler ist aufgetreten.';

  @override
  String get appTitle => 'Eyes Only';

  @override
  String get unlockReason => 'Eyes Only entsperren';

  @override
  String get lockNoAuthAvailable => 'Keine Geräteauthentifizierung verfügbar.';

  @override
  String get lockUnlockRequired => 'Zum Fortfahren entsperren.';

  @override
  String get lockAuthFailed => 'Geräteauthentifizierung fehlgeschlagen.';

  @override
  String get appLockedTitle => 'Eyes Only ist gesperrt';

  @override
  String get appLockedMessage =>
      'Verwende Gesicht, Fingerabdruck oder Gerätecode, um fortzufahren.';

  @override
  String get unlocking => 'Wird entsperrt...';

  @override
  String get unlock => 'Entsperren';

  @override
  String get homeMenu => 'Menü';

  @override
  String get homeTabPhotos => 'Fotos';

  @override
  String get homeTabGroups => 'Gruppen';

  @override
  String get homeTabAccount => 'Konto';

  @override
  String get homeTabLogIn => 'Anmelden';

  @override
  String get homeTabSettings => 'Einstellungen';

  @override
  String get homeTabAbout => 'Über';

  @override
  String get managerServerNotSet => 'Manager-Server-URL ist nicht gesetzt.';

  @override
  String get notifyWhenImagesLoading =>
      'Diese Gruppe kann erst benachrichtigt werden, wenn ihre Bilder fertig geladen sind.';

  @override
  String notificationSent(int count) {
    return 'Benachrichtigung an $count Geräte gesendet.';
  }

  @override
  String notificationSentWithSkipped(int notified, int skipped) {
    return 'Benachrichtigung an $notified Geräte gesendet. $skipped wurden übersprungen.';
  }

  @override
  String get imageDeleted => 'Bild gelöscht.';

  @override
  String get homeTakePicture => 'Foto aufnehmen';

  @override
  String get homeSendMessageToGroup => 'Nachricht an Gruppe senden';

  @override
  String get homeRetry => 'Erneut versuchen';

  @override
  String get homeNoImages => 'Aktuell gibt es keine Bilder für dich';

  @override
  String get homeNoGroupsYet => 'Du bist noch in keiner Gruppe.';

  @override
  String get homeJoinGroup => 'Gruppe beitreten';

  @override
  String get groupsTitle => 'Gruppen';

  @override
  String get groupsRefresh => 'Aktualisieren';

  @override
  String get groupsCreateGroup => 'Gruppe erstellen';

  @override
  String groupsError(Object message) {
    return 'Fehler: $message';
  }

  @override
  String get groupsAddOrganizationToSeeGroups =>
      'Füge eine Organisation hinzu, um hier ihre Gruppen zu sehen.';

  @override
  String get groupsNoGroups => 'Keine Gruppen';

  @override
  String get groupsJoinGroup => 'Gruppe beitreten';

  @override
  String get groupsLeaveGroup => 'Gruppe verlassen';

  @override
  String get groupsShareOrganization => 'Organisation teilen';

  @override
  String groupsFallbackName(Object shortId) {
    return 'Gruppe $shortId';
  }

  @override
  String groupsServerTimeoutWithUrl(Object apiUrl) {
    return '$apiUrl konnte innerhalb von 10 Sekunden nicht erreicht werden.';
  }

  @override
  String get groupsServerTimeout =>
      'Der Server konnte innerhalb von 10 Sekunden nicht erreicht werden.';

  @override
  String get homeApiUnreachable =>
      'API nicht erreichbar. Bitte Verbindung prüfen und erneut versuchen.';

  @override
  String get homeOffline => 'Du bist offline.';

  @override
  String get homeNoInternetConnection =>
      'Keine Internetverbindung. Bitte verbinde dich und versuche es erneut.';

  @override
  String get homeLoadingImages => 'Bilder werden geladen...';

  @override
  String get homeLookingForNewPhotos => 'Suche nach neuen Fotos...';

  @override
  String get homeDownloadingNewImages =>
      'Neue Bilder werden heruntergeladen...';

  @override
  String get homeNoNewImagesFound => 'Keine neuen Bilder gefunden.';

  @override
  String get homeUnknownDay => 'Unbekannter Tag';

  @override
  String get homeDeleteImageTitle => 'Bild löschen';

  @override
  String get homeDeleteImageConfirm =>
      'Dieses Bild für diese Gruppe vom Server löschen? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get homeCollapseCaption => 'Beschriftung einklappen';

  @override
  String get homeShowCaption => 'Beschriftung anzeigen';

  @override
  String get homeDeleteImageTooltip => 'Bild löschen';

  @override
  String get failedToDecryptImage => 'Bild konnte nicht entschlüsselt werden';

  @override
  String get captureNoCameraAvailable =>
      'Auf diesem Gerät ist keine Kamera verfügbar.';

  @override
  String get captureFlashModeFailed =>
      'Der Blitzmodus konnte nicht geändert werden. Bitte versuche es erneut.';

  @override
  String get captureTakePhotoFailed =>
      'Das Foto konnte nicht aufgenommen werden. Bitte versuche es erneut.';

  @override
  String get pictureDeleted => 'Bild gelöscht.';

  @override
  String get flashAuto => 'Blitz Auto';

  @override
  String get flashOn => 'Blitz An';

  @override
  String get flashOff => 'Blitz Aus';

  @override
  String get retryCamera => 'Kamera erneut starten';

  @override
  String get switchCamera => 'Kamera wechseln';

  @override
  String get sendTitle => 'Senden';

  @override
  String sendSuccess(int count) {
    return 'Verschlüsseltes Bild an $count Geräte gesendet.';
  }

  @override
  String get sendAddTextLabel => 'Text hinzufügen';

  @override
  String get sendAddTextHint => 'Optionalen Text für dieses Bild hinzufügen';

  @override
  String get sendDelete => 'Löschen';

  @override
  String get sendSending => 'Wird gesendet...';

  @override
  String get sendFailedTryAgain =>
      'Senden fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get sendSend => 'Senden';

  @override
  String get sendSelectExpirationTitle => 'Löschzeitpunkt wählen';

  @override
  String get close => 'Schließen';

  @override
  String get sendPhotoExpiration => 'Löschzeitpunkt';

  @override
  String get expiresToday => 'Wird heute gelöscht';

  @override
  String get createGroupTitle => 'Gruppe erstellen';

  @override
  String get createGroupHeading => 'Neue Gruppe';

  @override
  String get createGroupNameLabel => 'Name';

  @override
  String get createGroupNameRequired => 'Name ist erforderlich';

  @override
  String get createGroupCreating => 'Wird erstellt...';

  @override
  String get createGroupSuccess => 'Gruppe erfolgreich erstellt.';

  @override
  String get createGroupCreatorNotLinkedError =>
      'Das Ersteller-Gerät wurde nicht mit der neuen Gruppe verknüpft.';

  @override
  String get createGroupNoLoggedInManagerError =>
      'Kein angemeldetes Manager-Konto für die Geräteregistrierung gefunden.';

  @override
  String get createGroupNoUuidError =>
      'Die Gruppe wurde erstellt, aber der Server hat keine UUID zurückgegeben.';

  @override
  String get joinGroupPageTitle => 'Gruppe beitreten';

  @override
  String get joinGroupQrInstruction =>
      'Lasse einen Hauptmanager diesen QR-Code scannen und die Gruppe auswählen.';

  @override
  String get joinGroupQrWhatIsSharedTitle => 'Was wird geteilt?';

  @override
  String get joinGroupQrWhatIsSharedBody =>
      'Dieser QR-Code teilt die Organisations-Server-URL, diese Installationskennung und die öffentlichen Schlüsselinformationen dieses Geräts, damit ein Hauptmanager das Gerät registrieren und einer ausgewählten Gruppe hinzufügen kann.';

  @override
  String joinGroupQrInstallationId(Object installationId) {
    return 'Installationskennung: $installationId';
  }

  @override
  String get aboutInstallationIdentifier => 'Installationskennung';

  @override
  String get aboutHiddenValue => 'Versteckt';

  @override
  String get aboutHideIdentifier => 'Kennung ausblenden';

  @override
  String get aboutShowIdentifier => 'Kennung anzeigen';

  @override
  String get accountNotLoggedIn => 'Nicht angemeldet';

  @override
  String get accountLoggingOut => 'Wird abgemeldet...';

  @override
  String get accountLogOut => 'Abmelden';

  @override
  String get shareOrganizationQrInstruction =>
      'Lasse das andere Gerät diesen QR-Code scannen, um diese Organisation hinzuzufügen.';

  @override
  String get groupPushFixedMessageIntro =>
      'Die Benachrichtigungsnachricht ist aus Datenschutzgründen fest vorgegeben:';

  @override
  String get selectCaptureNoManagerGroups =>
      'Du bist noch für keine Gruppen als Manager eingetragen.';

  @override
  String get loginRegisterThisDeviceTitle => 'Dieses Gerät registrieren';

  @override
  String get loginRegisterThisDeviceContent =>
      'Dieses Gerät ist noch nicht registriert. Tippe auf deinem bereits registrierten Manager-Gerät auf \"Manager-Gerät registrieren\" und scanne den hier angezeigten QR-Code.';

  @override
  String get loginLater => 'Später';

  @override
  String get loginShowQrCode => 'QR-Code anzeigen';

  @override
  String get loginServerUrlNotSet =>
      'Server-URL ist nicht gesetzt. Konfiguriere sie in den Einstellungen.';

  @override
  String get loginSuccessful => 'Anmeldung erfolgreich';

  @override
  String get loginFailedTryAgain =>
      'Anmeldung fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get loginManagerTitle => 'Manager-Anmeldung';

  @override
  String get loginOnlyMessage =>
      'Diese App unterstützt nur die Anmeldung. Registrierung ist deaktiviert.';

  @override
  String get loginUsernameLabel => 'Benutzername';

  @override
  String get loginUsernameRequired => 'Benutzername ist erforderlich';

  @override
  String get loginPasswordLabel => 'Passwort';

  @override
  String get loginPasswordRequired => 'Passwort ist erforderlich';

  @override
  String get loginLoggingIn => 'Wird angemeldet...';

  @override
  String get scanQrTitle => 'QR-Code scannen';

  @override
  String get scanQrInstruction =>
      'Scanne den Organisations-QR-Code des Managers, um die API-URL zu übernehmen.';

  @override
  String get scanQrInvalidJson =>
      'Der gescannte QR-Code enthielt keine gültigen JSON-Daten.';

  @override
  String get addOrganizationApiUrlLabel => 'API-URL';

  @override
  String get addOrganizationApiUrlHint => 'https://api.example.com';

  @override
  String get addOrganizationApiUrlRequired => 'API-URL ist erforderlich';

  @override
  String get addOrganizationApiUrlInvalid =>
      'Gib eine gültige http- oder https-URL ein';

  @override
  String get addOrganizationApiUrlDuplicate =>
      'Diese API-URL wurde bereits hinzugefügt';

  @override
  String get addOrganizationChecking => 'Organisation wird geprüft...';

  @override
  String get addOrganizationCheckAction => 'Organisation prüfen';

  @override
  String get addOrganizationConfirmPrompt => 'Diese Organisation hinzufügen?';

  @override
  String get addOrganizationAdd => 'Hinzufügen';

  @override
  String get addOrganizationCancel => 'Abbrechen';

  @override
  String get addOrganizationInvalidQr =>
      'Der gescannte QR-Code enthielt keine gültige API-URL.';

  @override
  String get addOrganizationUnreachable =>
      'Der Server konnte nicht erreicht werden. Bitte prüfe URL und Netzwerkverbindung.';

  @override
  String get addOrganizationTimeout =>
      'Der Server konnte innerhalb von 10 Sekunden nicht erreicht werden.';

  @override
  String addOrganizationUnexpectedStatus(int statusCode) {
    return 'Der Server hat einen unerwarteten Status zurückgegeben ($statusCode). Bitte prüfe die URL.';
  }

  @override
  String get groupAddScanDeviceTitle => 'Gerät scannen';

  @override
  String get groupAddScanDeviceInstruction =>
      'Scanne den Geräte-QR-Code, um Installationskennung und öffentlichen Schlüssel zu erfassen.';

  @override
  String get groupAddServerUrlMismatchTitle =>
      'Server-URL stimmt nicht überein';

  @override
  String get groupAddServerUrlMismatchBody =>
      'Das gescannte Gerät ist mit einer anderen Serveradresse registriert als die aktuell verwaltete. Das kann normal sein, wenn derselbe Server über mehrere Adressen erreichbar ist (z. B. Emulator vs. physisches Gerät im selben Netzwerk).';

  @override
  String get groupAddCurrentServerLabel => 'Aktueller Server:';

  @override
  String get groupAddDeviceServerLabel => 'Geräte-Server:';

  @override
  String get groupAddServerUrlMismatchWarning =>
      'Nur fortfahren, wenn du sicher bist, dass beide Adressen auf denselben Server zeigen.';

  @override
  String get groupAddCancel => 'Abbrechen';

  @override
  String get groupAddAddAnyway => 'Trotzdem hinzufügen';

  @override
  String groupAddAddedMember(Object name, Object groupName) {
    return '$name wurde zu $groupName hinzugefügt.';
  }

  @override
  String get groupAddStatusReady => 'Bereit';

  @override
  String get groupAddStatusRequired => 'Erforderlich';

  @override
  String get groupAddDeviceTitle => 'Gerät hinzufügen';

  @override
  String get groupAddNameLabel => 'Name';

  @override
  String get groupAddNameHint => 'Gib einen Namen für dieses Gerät ein';

  @override
  String get groupAddNameRequired => 'Name ist erforderlich';

  @override
  String get groupAddDeviceLabel => 'Gerät';

  @override
  String get groupAddScanDeviceAction => 'Gerät scannen';

  @override
  String get groupAddAddingDevice => 'Gerät wird hinzugefügt...';

  @override
  String get groupAddDeviceAction => 'Gerät hinzufügen';

  @override
  String get groupAddNotJoinCode =>
      'Der gescannte QR-Code ist kein Geräte-Beitrittscode.';

  @override
  String get groupAddMissingManagerRequestData =>
      'Im gescannten QR-Code fehlen Manager-Anfragedaten.';

  @override
  String get groupAddMissingRegisterData =>
      'Im gescannten QR-Code fehlen Register-Geräte-Daten.';

  @override
  String get groupAddMissingRequiredData =>
      'Im gescannten QR-Code fehlen erforderliche Gerätedaten.';

  @override
  String get groupAddManagerDeviceTitle => 'Manager-Gerät hinzufügen';

  @override
  String get groupAddManagerInstruction =>
      'Scanne den QR-Code auf dem anderen Manager-Gerät (Gruppen → Gruppe beitreten), während dort ein Manager angemeldet ist.';

  @override
  String get groupAddManagerDeviceAction => 'Manager-Gerät hinzufügen';

  @override
  String get groupAddManagerScanTitle => 'Manager-Gerät scannen';

  @override
  String get groupAddManagerScanInstruction =>
      'Gehe auf dem anderen Manager-Gerät zu Gruppen → Gruppe beitreten und scanne dort den angezeigten QR-Code.';

  @override
  String get groupAddManagerServerUrlMismatchBody =>
      'Das gescannte Gerät meldet eine andere Serveradresse. Das kann normal sein, wenn beide Adressen auf denselben Server zeigen (z. B. Emulator vs. physisches Gerät).';

  @override
  String get groupAddManagerMissingOwnerUser =>
      'Dieser QR-Code enthält kein Manager-Konto. Stelle sicher, dass der andere Manager angemeldet ist, bevor der QR-Code angezeigt wird.';

  @override
  String get registerManagerDeviceTitle => 'Manager-Gerät registrieren';

  @override
  String get registerManagerDeviceInstruction =>
      'Scanne den auf dem zweiten Manager-Gerät angezeigten QR-Code (Gruppen → Gruppe beitreten), um es als zusätzliches Gerät für dein Konto zu registrieren.';

  @override
  String get registerManagerDeviceGenerating => 'Wird generiert...';

  @override
  String get registerManagerDeviceGenerateQrCode => 'QR-Code generieren';

  @override
  String get registerManagerDeviceServerUrlMismatchTitle =>
      'Server-URL stimmt nicht überein';

  @override
  String get registerManagerDeviceServerUrlMismatchBody =>
      'Das gescannte Gerät ist mit einer anderen Serveradresse registriert. Das kann normal sein, wenn beide Adressen auf denselben Server zeigen (z. B. Emulator vs. physisches Gerät im selben Netzwerk).';

  @override
  String get registerManagerDeviceCurrentServerLabel => 'Aktueller Server:';

  @override
  String get registerManagerDeviceDeviceServerLabel => 'Geräte-Server:';

  @override
  String get registerManagerDeviceServerUrlMismatchWarning =>
      'Nur fortfahren, wenn du sicher bist, dass beide Adressen auf denselben Server zeigen.';

  @override
  String get registerManagerDeviceCancel => 'Abbrechen';

  @override
  String get registerManagerDeviceContinue => 'Fortfahren';

  @override
  String get registerManagerDeviceSuccess => 'Gerät erfolgreich registriert.';

  @override
  String get registerManagerDeviceScanned => 'Gerät gescannt';

  @override
  String get registerManagerDeviceScanRequired => 'Scan erforderlich';

  @override
  String get registerManagerDeviceScanDeviceQr => 'Geräte-QR scannen';

  @override
  String get registerManagerDeviceRegistering => 'Wird registriert...';

  @override
  String get registerManagerDeviceRegisterAction => 'Gerät registrieren';

  @override
  String get registerManagerDeviceScanInstruction =>
      'Gehe auf dem zweiten Gerät zu Gruppen → Gruppe beitreten und scanne diesen QR-Code hier.';

  @override
  String get registerManagerDeviceNotJoinCode =>
      'Der gescannte QR-Code ist kein Geräte-Beitrittscode.';

  @override
  String get registerManagerDeviceMissingManagerRequestData =>
      'Im gescannten QR-Code fehlen Manager-Anfragedaten.';

  @override
  String get registerManagerDeviceMissingRegisterData =>
      'Im gescannten QR-Code fehlen Register-Geräte-Daten.';

  @override
  String get registerManagerDeviceMissingRequiredData =>
      'Im gescannten QR-Code fehlen erforderliche Gerätedaten.';

  @override
  String get groupDetailDecryptionFailed => 'Entschlüsselung fehlgeschlagen';

  @override
  String groupDetailRemovedFromGroup(Object ownerName) {
    return '$ownerName wurde aus der Gruppe entfernt.';
  }

  @override
  String get groupDetailRemoveDeviceTitle => 'Gerät entfernen?';

  @override
  String groupDetailRemoveDevicePrompt(Object ownerName) {
    return '$ownerName aus dieser Gruppe entfernen?';
  }

  @override
  String get groupDetailCancel => 'Abbrechen';

  @override
  String get groupDetailRemoveAction => 'Entfernen';

  @override
  String get groupDetailLeaveGroupTitle => 'Gruppe verlassen?';

  @override
  String groupDetailLeaveGroupPrompt(Object groupName) {
    return 'Möchtest du $groupName wirklich verlassen?\n\nNur ein Manager kann dich wieder zu dieser Gruppe hinzufügen.';
  }

  @override
  String get groupDetailLeaveAction => 'Verlassen';

  @override
  String get groupDetailDeleteGroupTitle => 'Gruppe löschen?';

  @override
  String groupDetailDeleteGroupPrompt(Object groupName) {
    return 'Möchtest du $groupName wirklich löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden.';
  }

  @override
  String get groupDetailDeleteGroupAction => 'Gruppe löschen';

  @override
  String groupDetailNotificationSent(int notifiedCount) {
    return 'Benachrichtigung an $notifiedCount Geräte gesendet.';
  }

  @override
  String groupDetailNotificationSentSkipped(
    int notifiedCount,
    int skippedCount,
  ) {
    return 'Benachrichtigung an $notifiedCount Geräte gesendet. $skippedCount wurden übersprungen.';
  }

  @override
  String get groupsRefreshTooltip => 'Aktualisieren';

  @override
  String get groupDetailAddMember => 'Mitglied hinzufügen';

  @override
  String get groupDetailShowInstallationIdentifiers =>
      'Installationskennungen anzeigen';

  @override
  String get groupDetailNoDevicesInGroup => 'Keine Geräte in dieser Gruppe.';

  @override
  String get onboardingWelcomeTitle => 'Willkommen bei Eyes Only';

  @override
  String get onboardingOrganizationUnreachable =>
      'Der Server konnte nicht erreicht werden. Bitte prüfe URL und Netzwerkverbindung.';

  @override
  String get onboardingOrganizationInvalidQr =>
      'Der gescannte QR-Code enthielt keine gültige Organisations-API-URL.';

  @override
  String onboardingUnexpectedStatus(int statusCode) {
    return 'Der Server hat einen unerwarteten Status zurückgegeben ($statusCode). Bitte prüfe die URL.';
  }

  @override
  String get onboardingTimeout =>
      'Der Server konnte innerhalb von 10 Sekunden nicht erreicht werden.';

  @override
  String get onboardingCompleteOrganizationFirst =>
      'Schließe zuerst die Organisationseinrichtung ab.';

  @override
  String get onboardingWaitingForAdminAssignment =>
      'Es wird auf die Zuweisung durch einen Admin gewartet, bevor es weitergeht.';

  @override
  String get onboardingStep1Title => 'Schritt 1: Organisation verbinden';

  @override
  String get onboardingStep1Body =>
      'Gib die API-URL deiner Organisation ein. Wir prüfen sie vor dem Fortfahren.';

  @override
  String get onboardingOrganizationApiUrlLabel => 'Organisations-API-URL';

  @override
  String get onboardingOrganizationApiUrlHint => 'https://api.example.com';

  @override
  String get onboardingApiUrlRequired => 'API-URL ist erforderlich';

  @override
  String get onboardingApiUrlInvalid =>
      'Gib eine gültige http- oder https-URL ein';

  @override
  String get onboardingScanOrganizationQrAction =>
      'Organisations-QR-Code scannen';

  @override
  String get onboardingCheckingOrganization => 'Organisation wird geprüft...';

  @override
  String get onboardingCheckOrganizationAction => 'Organisation prüfen';

  @override
  String get onboardingContinueWithOrganizationPrompt =>
      'Mit dieser Organisation fortfahren?';

  @override
  String get onboardingContinueAction => 'Fortfahren';

  @override
  String get onboardingCancelAction => 'Abbrechen';

  @override
  String get onboardingStep2Title =>
      'Schritt 2: Deiner ersten Gruppe beitreten';

  @override
  String get onboardingStep2Body =>
      'Zeige diesen QR-Code deinem Organisations-Admin. Wir prüfen weiter, bis dieses Gerät einer Gruppe zugewiesen wurde.';

  @override
  String get onboardingMembershipConfirmed =>
      'Gruppenmitgliedschaft bestätigt.';

  @override
  String get onboardingWaitingForAdminAssignmentShort =>
      'Warten auf Admin-Zuweisung...';

  @override
  String get onboardingWhatIsSharedTitle => 'Was wird geteilt?';

  @override
  String get onboardingWhatIsSharedBody =>
      'Dieser QR-Code teilt die Organisations-Server-URL, diese Installationskennung und die öffentlichen Schlüsselinformationen dieses Geräts, damit ein Hauptmanager das Gerät registrieren und einer ausgewählten Gruppe hinzufügen kann.';

  @override
  String onboardingInstallationIdentifier(Object installationId) {
    return 'Installationskennung: $installationId';
  }

  @override
  String get onboardingIAmMainManagerAction => 'Ich bin Hauptmanager';

  @override
  String get onboardingBackAction => 'Zurück';

  @override
  String get onboardingStep3Title => 'Schritt 3: Push-Benachrichtigungen';

  @override
  String get onboardingStep3Body =>
      'Möchtest du Push-Benachrichtigungen für neue Gruppenbilder erhalten?';

  @override
  String get onboardingPushPrivacyBody =>
      'Wenn aktiviert, kommuniziert dieses Gerät mit Google Firebase-Servern nur zum Empfang von Benachrichtigungsereignissen. Bildinhalte werden nicht an Firebase gesendet.';

  @override
  String get onboardingPushPermissionBody =>
      'Unter Android 12 und niedriger zeigt das System meist keinen Berechtigungsdialog für Benachrichtigungen. Unter Android 13+ und iOS kann das Betriebssystem um Erlaubnis bitten.';

  @override
  String get onboardingApplying => 'Wird angewendet...';

  @override
  String get onboardingEnableNotificationsAction =>
      'Benachrichtigungen aktivieren';

  @override
  String get onboardingNotNowAction => 'Nicht jetzt';

  @override
  String get onboardingScanOrganizationQrTitle =>
      'Organisations-QR-Code scannen';

  @override
  String get onboardingScanOrganizationQrInstruction =>
      'Scanne den Organisations-QR-Code des Hauptmanagers, um die API-URL zu übernehmen.';

  @override
  String get onboardingAdminTitle => 'Admin-Onboarding';

  @override
  String get onboardingAdminSetupTitle => 'Hauptmanager-Einrichtung';

  @override
  String onboardingAdminLoggedInAs(Object username) {
    return 'Als $username angemeldet. Du kannst jetzt eine Gruppe erstellen oder einer Gruppe beitreten.';
  }

  @override
  String get onboardingAdminLoginPrompt =>
      'Melde dich mit einem Hauptmanager-Konto an, um mit Admin-Aktionen fortzufahren.';

  @override
  String get onboardingAdminLoginAction => 'Als Hauptmanager anmelden';

  @override
  String get expirationOneDay => '1 Tag';

  @override
  String get expirationThreeDays => '3 Tage';

  @override
  String get expirationSevenDays => '7 Tage';

  @override
  String get expirationFourteenDays => '14 Tage';

  @override
  String get expirationOneMonth => '1 Monat';

  @override
  String get expirationExpired => 'Gelöscht';

  @override
  String expirationInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Wird in $days Tagen gelöscht',
      one: 'Wird in 1 Tag gelöscht',
    );
    return '$_temp0';
  }

  @override
  String expirationInHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Wird in $hours Stunden gelöscht',
      one: 'Wird in 1 Stunde gelöscht',
    );
    return '$_temp0';
  }
}
