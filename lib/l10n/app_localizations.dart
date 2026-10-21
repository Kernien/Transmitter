import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @savedFile.
  ///
  /// In en, this message translates to:
  /// **'Saved: {name}'**
  String savedFile(String name);

  /// No description provided for @sizeUnitB.
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get sizeUnitB;

  /// No description provided for @sizeUnitKb.
  ///
  /// In en, this message translates to:
  /// **'KB'**
  String get sizeUnitKb;

  /// No description provided for @sizeUnitMb.
  ///
  /// In en, this message translates to:
  /// **'MB'**
  String get sizeUnitMb;

  /// No description provided for @sizeUnitGb.
  ///
  /// In en, this message translates to:
  /// **'GB'**
  String get sizeUnitGb;

  /// No description provided for @decimalSeparator.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get decimalSeparator;

  /// No description provided for @sizeLimit.
  ///
  /// In en, this message translates to:
  /// **'{mb} MB'**
  String sizeLimit(int mb);

  /// No description provided for @deviceNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Device name: {name}'**
  String deviceNameTooltip(String name);

  /// No description provided for @clouds.
  ///
  /// In en, this message translates to:
  /// **'Clouds'**
  String get clouds;

  /// No description provided for @addKey.
  ///
  /// In en, this message translates to:
  /// **'Add key'**
  String get addKey;

  /// No description provided for @newKey.
  ///
  /// In en, this message translates to:
  /// **'New key'**
  String get newKey;

  /// No description provided for @providerNotSupported.
  ///
  /// In en, this message translates to:
  /// **'{provider} isn\'t supported yet'**
  String providerNotSupported(String provider);

  /// No description provided for @vaultSubtitleConnected.
  ///
  /// In en, this message translates to:
  /// **'{provider} · files up to {limit}'**
  String vaultSubtitleConnected(String provider, String limit);

  /// No description provided for @vaultSubtitleNotConnected.
  ///
  /// In en, this message translates to:
  /// **'{provider} · not connected'**
  String vaultSubtitleNotConnected(String provider);

  /// No description provided for @showKeyQr.
  ///
  /// In en, this message translates to:
  /// **'Show key / QR'**
  String get showKeyQr;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @removeFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove from device'**
  String get removeFromDevice;

  /// No description provided for @nameTitle.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameTitle;

  /// No description provided for @removeKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove key?'**
  String get removeKeyTitle;

  /// No description provided for @removeKeyText.
  ///
  /// In en, this message translates to:
  /// **'The key will be removed from this device only. The data in the cloud stays. If you have no copy of the key, access to the vault will be lost.'**
  String get removeKeyText;

  /// No description provided for @vaultsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Create a new key or add a key from another device by scanning its QR code.'**
  String get vaultsEmpty;

  /// No description provided for @keyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name, e.g. “Work”'**
  String get keyNameLabel;

  /// No description provided for @cloudLabel.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloudLabel;

  /// No description provided for @cloudComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{provider} (coming soon)'**
  String cloudComingSoon(String provider);

  /// No description provided for @maxFileSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Maximum file size'**
  String get maxFileSizeLabel;

  /// No description provided for @maxFileSizeHelp.
  ///
  /// In en, this message translates to:
  /// **'Applies to all devices with this key.\nIt can\'t be changed later.'**
  String get maxFileSizeHelp;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get scanQr;

  /// No description provided for @orPasteKey.
  ///
  /// In en, this message translates to:
  /// **'or paste the key:'**
  String get orPasteKey;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the QR code'**
  String get scanTitle;

  /// No description provided for @vaultKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault key'**
  String get vaultKeyTitle;

  /// No description provided for @copyKey.
  ///
  /// In en, this message translates to:
  /// **'Copy key'**
  String get copyKey;

  /// No description provided for @keyCopied.
  ///
  /// In en, this message translates to:
  /// **'Key copied'**
  String get keyCopied;

  /// No description provided for @keyWarning.
  ///
  /// In en, this message translates to:
  /// **'Anyone with this key can read and add items to the vault. Share it only with your own devices.'**
  String get keyWarning;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @statusSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get statusSoon;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusNotConnected;

  /// No description provided for @connectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect {provider}'**
  String connectTitle(String provider);

  /// No description provided for @connectExplanation.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {provider} on this device. The app only gets access to its own folder; your other files stay invisible to it. Everything is encrypted before it\'s sent.'**
  String connectExplanation(String provider);

  /// No description provided for @cloudNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'This build has no app key for {provider} (see docs/DEVELOPMENT.md).'**
  String cloudNotConfigured(String provider);

  /// No description provided for @finishSignInInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Finish signing in in the browser window…'**
  String get finishSignInInBrowser;

  /// No description provided for @passwordSignInExplanation.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your {provider} email and password. The password isn\'t stored: the app keeps only the sign-in session. {provider} has no access limited to one folder, so technically the app could see your whole drive, but it only works with the Transmitter folder. Everything is encrypted before it\'s sent.'**
  String passwordSignInExplanation(String provider);

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @secondFactorCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication code'**
  String get secondFactorCodeLabel;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @signInTo.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {provider}'**
  String signInTo(String provider);

  /// No description provided for @connectFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect: {error}'**
  String connectFailed(String error);

  /// No description provided for @deviceNameFirstRunTitle.
  ///
  /// In en, this message translates to:
  /// **'What should this device be called?'**
  String get deviceNameFirstRunTitle;

  /// No description provided for @deviceNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceNameTitle;

  /// No description provided for @deviceNameFirstRunText.
  ///
  /// In en, this message translates to:
  /// **'Items from this device will be signed with this name, so your other devices show where they came from.'**
  String get deviceNameFirstRunText;

  /// No description provided for @deviceNameEditText.
  ///
  /// In en, this message translates to:
  /// **'New items will be signed with the new name; old ones keep the previous one.'**
  String get deviceNameEditText;

  /// No description provided for @deviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example, “Phone — work” or “Laptop”'**
  String get deviceNameHint;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterName;

  /// No description provided for @vaultFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get vaultFallbackTitle;

  /// No description provided for @openVaultFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the vault: {error}'**
  String openVaultFailed(String error);

  /// No description provided for @clearFeed.
  ///
  /// In en, this message translates to:
  /// **'Clear feed'**
  String get clearFeed;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String selectedCount(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @downloadSelected.
  ///
  /// In en, this message translates to:
  /// **'Download selected'**
  String get downloadSelected;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelected;

  /// No description provided for @deleteSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete selected ({count})?'**
  String deleteSelectedTitle(int count);

  /// No description provided for @deleteSelectedText.
  ///
  /// In en, this message translates to:
  /// **'Items and files will be deleted from the cloud on all devices.'**
  String get deleteSelectedText;

  /// No description provided for @clearFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear feed?'**
  String get clearFeedTitle;

  /// No description provided for @clearFeedText.
  ///
  /// In en, this message translates to:
  /// **'All items and files of this vault will be deleted from the cloud on all devices. This can\'t be undone.'**
  String get clearFeedText;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get deleteAll;

  /// No description provided for @dropHint.
  ///
  /// In en, this message translates to:
  /// **'Release to send (up to {limit} per file)'**
  String dropHint(String limit);

  /// No description provided for @feedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Send a link or drop a file here.'**
  String get feedEmpty;

  /// No description provided for @attachFileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attach a file (up to {limit})'**
  String attachFileTooltip(String limit);

  /// No description provided for @attachMediaTooltip.
  ///
  /// In en, this message translates to:
  /// **'Photo or video from the gallery (up to {limit})'**
  String attachMediaTooltip(String limit);

  /// No description provided for @composeHint.
  ///
  /// In en, this message translates to:
  /// **'Link or text'**
  String get composeHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @deleteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete file?'**
  String get deleteFileTitle;

  /// No description provided for @deleteItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete item?'**
  String get deleteItemTitle;

  /// No description provided for @deleteItemText.
  ///
  /// In en, this message translates to:
  /// **'It will disappear from the cloud and all devices.'**
  String get deleteItemText;

  /// No description provided for @actionSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get actionSelect;

  /// No description provided for @actionAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add comment'**
  String get actionAddNote;

  /// No description provided for @actionEditNote.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get actionEditNote;

  /// No description provided for @noteTitle.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get noteTitle;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'What is this, why it matters'**
  String get noteHint;

  /// No description provided for @noteEditedBy.
  ///
  /// In en, this message translates to:
  /// **'Last edited on {device}'**
  String noteEditedBy(String device);

  /// No description provided for @actionSaveFile.
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get actionSaveFile;

  /// No description provided for @actionCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get actionCopyText;

  /// No description provided for @actionSelectText.
  ///
  /// In en, this message translates to:
  /// **'Select text'**
  String get actionSelectText;

  /// No description provided for @markdownSource.
  ///
  /// In en, this message translates to:
  /// **'Show source text'**
  String get markdownSource;

  /// No description provided for @documentUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t read this document — save the file and open it in another app'**
  String get documentUnreadable;

  /// No description provided for @openWith.
  ///
  /// In en, this message translates to:
  /// **'Open in another app'**
  String get openWith;

  /// No description provided for @errNoAppToOpen.
  ///
  /// In en, this message translates to:
  /// **'There is no app on this device that can open this file'**
  String get errNoAppToOpen;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullscreen;

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get exitFullscreen;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be played here — open it in another app'**
  String get playbackFailed;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'As in the system'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get themeOcean;

  /// No description provided for @themeForest.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get themeForest;

  /// No description provided for @themeSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get themeSunset;

  /// No description provided for @themeNight.
  ///
  /// In en, this message translates to:
  /// **'Night (black)'**
  String get themeNight;

  /// No description provided for @themeDracula.
  ///
  /// In en, this message translates to:
  /// **'Dracula'**
  String get themeDracula;

  /// No description provided for @themeNord.
  ///
  /// In en, this message translates to:
  /// **'Nord'**
  String get themeNord;

  /// No description provided for @themeOneDark.
  ///
  /// In en, this message translates to:
  /// **'One Dark'**
  String get themeOneDark;

  /// No description provided for @themeSolarized.
  ///
  /// In en, this message translates to:
  /// **'Solarized Dark'**
  String get themeSolarized;

  /// No description provided for @themeGruvbox.
  ///
  /// In en, this message translates to:
  /// **'Gruvbox'**
  String get themeGruvbox;

  /// No description provided for @themeCatppuccin.
  ///
  /// In en, this message translates to:
  /// **'Catppuccin Mocha'**
  String get themeCatppuccin;

  /// No description provided for @storageLimitValue.
  ///
  /// In en, this message translates to:
  /// **'Limit: {size}'**
  String storageLimitValue(String size);

  /// No description provided for @storageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage on this device'**
  String get storageTitle;

  /// No description provided for @storageIntro.
  ///
  /// In en, this message translates to:
  /// **'Opened files are kept on the device (encrypted) so they open instantly and without internet. When space runs out, the ones opened longest ago go first. Items themselves are always kept.'**
  String get storageIntro;

  /// No description provided for @storageUsed.
  ///
  /// In en, this message translates to:
  /// **'Used: {size}'**
  String storageUsed(String size);

  /// No description provided for @storageLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit for files'**
  String get storageLimit;

  /// No description provided for @storageClear.
  ///
  /// In en, this message translates to:
  /// **'Clear files'**
  String get storageClear;

  /// No description provided for @monospaceFont.
  ///
  /// In en, this message translates to:
  /// **'Monospace font'**
  String get monospaceFont;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copyAll;

  /// No description provided for @textTruncated.
  ///
  /// In en, this message translates to:
  /// **'Showing the beginning of the file ({size} in total) — save it to read everything'**
  String textTruncated(String size);

  /// No description provided for @showPhoto.
  ///
  /// In en, this message translates to:
  /// **'Show photo ({size})'**
  String showPhoto(String size);

  /// No description provided for @imageUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This image format can\'t be shown — save the file to open it'**
  String get imageUnsupported;

  /// No description provided for @closeAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeAction;

  /// No description provided for @actionDeleteEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Delete on all devices'**
  String get actionDeleteEverywhere;

  /// No description provided for @fileFallback.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get fileFallback;

  /// No description provided for @exportTextFileName.
  ///
  /// In en, this message translates to:
  /// **'items.txt'**
  String get exportTextFileName;

  /// No description provided for @exportFileNote.
  ///
  /// In en, this message translates to:
  /// **'file {name}'**
  String exportFileNote(String name);

  /// No description provided for @shareTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to Transmitter'**
  String get shareTargetTitle;

  /// No description provided for @sendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to'**
  String get sendTo;

  /// No description provided for @noVaultsYet.
  ///
  /// In en, this message translates to:
  /// **'Create a vault key in Transmitter first.'**
  String get noVaultsYet;

  /// No description provided for @vaultNeedsSignIn.
  ///
  /// In en, this message translates to:
  /// **'{provider} · sign in to the cloud first'**
  String vaultNeedsSignIn(String provider);

  /// No description provided for @sendingProgress.
  ///
  /// In en, this message translates to:
  /// **'Sending {current} of {total}…'**
  String sendingProgress(int current, int total);

  /// No description provided for @fileSkipped.
  ///
  /// In en, this message translates to:
  /// **'Larger than {limit} — won\'t be sent'**
  String fileSkipped(String limit);

  /// No description provided for @shareReceiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t receive the data: {error}'**
  String shareReceiveFailed(String error);

  /// No description provided for @authPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get authPageTitle;

  /// No description provided for @authPageClose.
  ///
  /// In en, this message translates to:
  /// **'You can close this tab and return to Transmitter.'**
  String get authPageClose;

  /// No description provided for @authPageReturn.
  ///
  /// In en, this message translates to:
  /// **'Return to Transmitter'**
  String get authPageReturn;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'As in the system'**
  String get languageSystem;

  /// No description provided for @deviceWorkProfile.
  ///
  /// In en, this message translates to:
  /// **'work'**
  String get deviceWorkProfile;

  /// No description provided for @deviceBrowserName.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get deviceBrowserName;

  /// No description provided for @errAuthCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in cancelled'**
  String get errAuthCancelled;

  /// No description provided for @errBrowserOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the browser'**
  String get errBrowserOpenFailed;

  /// No description provided for @errAuthPortBusy.
  ///
  /// In en, this message translates to:
  /// **'Port {port} is used by another program'**
  String errAuthPortBusy(String port);

  /// No description provided for @errPopupBlocked.
  ///
  /// In en, this message translates to:
  /// **'The browser blocked the pop-up window. Allow pop-ups for this site.'**
  String get errPopupBlocked;

  /// No description provided for @errAuthRejected.
  ///
  /// In en, this message translates to:
  /// **'{provider} rejected the sign-in: {details}'**
  String errAuthRejected(String provider, String details);

  /// No description provided for @errAuthStateMismatch.
  ///
  /// In en, this message translates to:
  /// **'The response from {provider} failed verification, please try again'**
  String errAuthStateMismatch(String provider);

  /// No description provided for @errAuthNoCode.
  ///
  /// In en, this message translates to:
  /// **'{provider} didn\'t return a sign-in code'**
  String errAuthNoCode(String provider);

  /// No description provided for @errAuthTokenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a {provider} token ({details})'**
  String errAuthTokenFailed(String provider, String details);

  /// No description provided for @errCloudWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password'**
  String get errCloudWrongPassword;

  /// No description provided for @errCloudSecondFactorRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your authenticator app'**
  String get errCloudSecondFactorRequired;

  /// No description provided for @errCloudSecondFactorWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong code — check the authenticator app and try again'**
  String get errCloudSecondFactorWrong;

  /// No description provided for @errCloudAccountBlocked.
  ///
  /// In en, this message translates to:
  /// **'The {provider} account is blocked — check it on the {provider} website'**
  String errCloudAccountBlocked(String provider);

  /// No description provided for @errAuthNoOfflineAccess.
  ///
  /// In en, this message translates to:
  /// **'{provider} didn\'t grant long-term access'**
  String errAuthNoOfflineAccess(String provider);

  /// No description provided for @errCloudNotConnected.
  ///
  /// In en, this message translates to:
  /// **'The cloud isn\'t connected'**
  String get errCloudNotConnected;

  /// No description provided for @errCloudSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in to the cloud again'**
  String get errCloudSignInAgain;

  /// No description provided for @errCloudAccessRevoked.
  ///
  /// In en, this message translates to:
  /// **'Access to {provider} was revoked, sign in again'**
  String errCloudAccessRevoked(String provider);

  /// No description provided for @errCloudWebSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Sign-in to {provider} in the browser lasts about an hour — sign in again (☁ → {provider})'**
  String errCloudWebSessionExpired(String provider);

  /// No description provided for @errCloudTokenRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh the {provider} token ({details})'**
  String errCloudTokenRefreshFailed(String provider, String details);

  /// No description provided for @errCloudRateLimited.
  ///
  /// In en, this message translates to:
  /// **'{provider} is temporarily limiting requests, try again later'**
  String errCloudRateLimited(String provider);

  /// No description provided for @errCloudQuota.
  ///
  /// In en, this message translates to:
  /// **'The cloud is out of space'**
  String get errCloudQuota;

  /// No description provided for @errCloudFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'The file has already been deleted from the cloud'**
  String get errCloudFileNotFound;

  /// No description provided for @errCloudNoUploadUrl.
  ///
  /// In en, this message translates to:
  /// **'{provider} didn\'t return an upload address'**
  String errCloudNoUploadUrl(String provider);

  /// No description provided for @errCloudRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'{provider} error ({details})'**
  String errCloudRequestFailed(String provider, String details);

  /// No description provided for @errFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is larger than {limit}'**
  String errFileTooLarge(String limit);

  /// No description provided for @errDecryptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t decrypt the data'**
  String get errDecryptionFailed;

  /// No description provided for @errKeyNotTransmitter.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a Transmitter key'**
  String get errKeyNotTransmitter;

  /// No description provided for @errKeyCorrupted.
  ///
  /// In en, this message translates to:
  /// **'The key is damaged'**
  String get errKeyCorrupted;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection — check your internet and try again'**
  String get errNetwork;

  /// No description provided for @boardAccessAction.
  ///
  /// In en, this message translates to:
  /// **'Read-only access…'**
  String get boardAccessAction;

  /// No description provided for @boardAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Read-only access'**
  String get boardAccessTitle;

  /// No description provided for @boardIntro.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the reader key will be able to view, copy and download all items in this vault, including comments — but not change them. Readers don\'t need a cloud account.'**
  String get boardIntro;

  /// No description provided for @boardOpenAccess.
  ///
  /// In en, this message translates to:
  /// **'Open access'**
  String get boardOpenAccess;

  /// No description provided for @boardReaderHint.
  ///
  /// In en, this message translates to:
  /// **'Send this reader key to the people you want to share with. New items will appear for them automatically.'**
  String get boardReaderHint;

  /// No description provided for @boardCloseAccess.
  ///
  /// In en, this message translates to:
  /// **'Close access'**
  String get boardCloseAccess;

  /// No description provided for @boardCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close access?'**
  String get boardCloseTitle;

  /// No description provided for @boardCloseText.
  ///
  /// In en, this message translates to:
  /// **'All reader keys you have given out will stop working. If you open access again, there will be a new key.'**
  String get boardCloseText;

  /// No description provided for @boardClosed.
  ///
  /// In en, this message translates to:
  /// **'Access closed'**
  String get boardClosed;

  /// No description provided for @errBoardClosed.
  ///
  /// In en, this message translates to:
  /// **'The owner has closed access to this board'**
  String get errBoardClosed;

  /// No description provided for @boardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read-only · {provider}'**
  String boardSubtitle(String provider);

  /// No description provided for @readOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get readOnly;

  /// No description provided for @readerKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'This is a read-only key: with it the board can be viewed, but not changed.'**
  String get readerKeyWarning;

  /// No description provided for @removeBoardText.
  ///
  /// In en, this message translates to:
  /// **'The board will disappear only from this device. To get it back, you will need the reader key again.'**
  String get removeBoardText;

  /// No description provided for @boardSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {provider} again'**
  String boardSignInAgain(String provider);

  /// No description provided for @boardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this board yet'**
  String get boardEmpty;

  /// No description provided for @boardRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'The vault is renamed, but readers will still see the old board name: {error}'**
  String boardRenameFailed(String error);

  /// No description provided for @boardUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This cloud doesn\'t support public boards'**
  String get boardUnsupported;

  /// No description provided for @errCloudSharingNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Sign in to {provider} again to allow public links: ☁ → {provider} → Sign out, then Sign in'**
  String errCloudSharingNotAllowed(String provider);

  /// No description provided for @errBoardSignatureInvalid.
  ///
  /// In en, this message translates to:
  /// **'The board failed the integrity check: it was damaged or tampered with'**
  String get errBoardSignatureInvalid;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errUnknown(String error);
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
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
