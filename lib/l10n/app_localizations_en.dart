// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get retry => 'Retry';

  @override
  String get later => 'Later';

  @override
  String get add => 'Add';

  @override
  String get create => 'Create';

  @override
  String get untitled => 'Untitled';

  @override
  String get copied => 'Copied';

  @override
  String get saved => 'Saved';

  @override
  String get sent => 'Sent';

  @override
  String savedFile(String name) {
    return 'Saved: $name';
  }

  @override
  String get sizeUnitB => 'B';

  @override
  String get sizeUnitKb => 'KB';

  @override
  String get sizeUnitMb => 'MB';

  @override
  String get sizeUnitGb => 'GB';

  @override
  String get speedUnitB => 'B/s';

  @override
  String get speedUnitKb => 'KB/s';

  @override
  String get speedUnitMb => 'MB/s';

  @override
  String get speedUnitGb => 'GB/s';

  @override
  String get decimalSeparator => '.';

  @override
  String sizeLimit(int mb) {
    return '$mb MB';
  }

  @override
  String sizeLimitGb(int gb) {
    return '$gb GB';
  }

  @override
  String get sizeLimitUnlimited => 'No limit';

  @override
  String deviceNameTooltip(String name) {
    return 'Device name: $name';
  }

  @override
  String get clouds => 'Clouds';

  @override
  String get addKey => 'Add key';

  @override
  String get newKey => 'New key';

  @override
  String providerNotSupported(String provider) {
    return '$provider isn\'t supported yet';
  }

  @override
  String vaultSubtitleConnected(String provider, String limit) {
    return '$provider · files up to $limit';
  }

  @override
  String vaultSubtitleConnectedUnlimited(String provider) {
    return '$provider · files without limit';
  }

  @override
  String vaultSubtitleConnectedPlain(String provider, String limit) {
    return '$provider · unencrypted · files up to $limit';
  }

  @override
  String vaultSubtitleConnectedPlainUnlimited(String provider) {
    return '$provider · unencrypted · files without limit';
  }

  @override
  String vaultSubtitleNotConnected(String provider) {
    return '$provider · not connected';
  }

  @override
  String vaultSubtitleNotConnectedPlain(String provider) {
    return '$provider · unencrypted · not connected';
  }

  @override
  String get pinVault => 'Pin';

  @override
  String get unpinVault => 'Unpin';

  @override
  String get pinnedVault => 'Pinned';

  @override
  String get pinVaultHint => 'Open by default when launching the app';

  @override
  String get showKeyQr => 'Show key / QR';

  @override
  String get rename => 'Rename';

  @override
  String get removeFromDevice => 'Remove from device';

  @override
  String get nameTitle => 'Name';

  @override
  String get removeKeyTitle => 'Remove key?';

  @override
  String get removeKeyText =>
      'The key will be removed from this device only. The data in the cloud stays. If you have no copy of the key, access to the vault will be lost.';

  @override
  String get vaultsEmpty =>
      'Create a new key or add a key from another device by scanning its QR code.';

  @override
  String get selectBoardHint => 'Select a board on the left';

  @override
  String get keyNameLabel => 'Name, e.g. “Work”';

  @override
  String get cloudLabel => 'Cloud';

  @override
  String cloudComingSoon(String provider) {
    return '$provider (coming soon)';
  }

  @override
  String get maxFileSizeLabel => 'Maximum file size';

  @override
  String get maxFileSizeHelp =>
      'Applies to all devices with this key.\nYou can change it later: ⋮ next to the vault → “File size…”.';

  @override
  String get encryptVaultLabel => 'Encrypt data';

  @override
  String get encryptVaultSubtitle =>
      'If turned off, files are stored in the cloud with their real names so you can open them right in the cloud.';

  @override
  String get fileSizeAction => 'File size…';

  @override
  String get fileSizeHelp =>
      'For new files on all devices of this vault. Files already uploaded stay.';

  @override
  String vaultChangeFailed(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get scanQr => 'Scan QR code';

  @override
  String get orPasteKey => 'or paste the key:';

  @override
  String get scanTitle => 'Point the camera at the QR code';

  @override
  String get vaultKeyTitle => 'Vault key';

  @override
  String get copyKey => 'Copy key';

  @override
  String get keyCopied => 'Key copied';

  @override
  String get keyWarning =>
      'Anyone with this key can read and add items to the vault. Share it only with your own devices.';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get statusSoon => 'Coming soon';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusNotConnected => 'Not connected';

  @override
  String connectTitle(String provider) {
    return 'Connect $provider';
  }

  @override
  String connectExplanation(String provider) {
    return 'Sign in to $provider on this device. The app only gets access to its own folder; your other files stay invisible to it. Everything is encrypted before it\'s sent.';
  }

  @override
  String cloudNotConfigured(String provider) {
    return 'This build has no app key for $provider (see docs/DEVELOPMENT.md).';
  }

  @override
  String get finishSignInInBrowser =>
      'Finish signing in in the browser window…';

  @override
  String passwordSignInExplanation(String provider) {
    return 'Sign in with your $provider email and password. The password isn\'t stored: the app keeps only the sign-in session. $provider has no access limited to one folder, so technically the app could see your whole drive, but it only works with the Transmitter folder. Everything is encrypted before it\'s sent.';
  }

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get secondFactorCodeLabel => 'Two-factor authentication code';

  @override
  String get signingIn => 'Signing in…';

  @override
  String signInTo(String provider) {
    return 'Sign in to $provider';
  }

  @override
  String connectFailed(String error) {
    return 'Couldn\'t connect: $error';
  }

  @override
  String get deviceNameFirstRunTitle => 'What should this device be called?';

  @override
  String get deviceNameTitle => 'Device name';

  @override
  String get deviceNameFirstRunText =>
      'Items from this device will be signed with this name, so your other devices show where they came from.';

  @override
  String get deviceNameEditText =>
      'New items will be signed with the new name; old ones keep the previous one.';

  @override
  String get deviceNameHint => 'For example, “Phone — work” or “Laptop”';

  @override
  String get enterName => 'Enter a name';

  @override
  String get vaultFallbackTitle => 'Vault';

  @override
  String openVaultFailed(String error) {
    return 'Couldn\'t open the vault: $error';
  }

  @override
  String get clearFeed => 'Clear feed';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String selectedCount(int count) {
    return 'Selected: $count';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get share => 'Share';

  @override
  String get downloadSelected => 'Download selected';

  @override
  String get deleteSelected => 'Delete selected';

  @override
  String deleteSelectedTitle(int count) {
    return 'Delete selected ($count)?';
  }

  @override
  String get deleteSelectedText =>
      'Items and files will be deleted from the cloud on all devices.';

  @override
  String get clearFeedTitle => 'Clear feed?';

  @override
  String get clearFeedText =>
      'All items and files of this vault will be deleted from the cloud on all devices. This can\'t be undone.';

  @override
  String get deleteAll => 'Delete all';

  @override
  String dropHint(String limit) {
    return 'Release to send (up to $limit per file)';
  }

  @override
  String get dropHintUnlimited => 'Release to send';

  @override
  String get feedEmpty => 'Nothing here yet. Send a link or drop a file here.';

  @override
  String attachFileTooltip(String limit) {
    return 'Attach a file (up to $limit)';
  }

  @override
  String get attachFileTooltipUnlimited => 'Attach a file';

  @override
  String get attachFolder => 'Attach folder';

  @override
  String attachFolderTooltip(String limit) {
    return 'Attach a folder (files up to $limit)';
  }

  @override
  String get attachFolderTooltipUnlimited => 'Attach a folder';

  @override
  String get saveFolder => 'Save folder';

  @override
  String savedFolder(String name) {
    return 'Folder saved: $name';
  }

  @override
  String get openFolder => 'Open folder';

  @override
  String folderFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get folderEmpty => 'Folder is empty';

  @override
  String get folderTitle => 'Folder';

  @override
  String get deleteFolderTitle => 'Delete folder?';

  @override
  String get cancelUpload => 'Cancel upload';

  @override
  String get uploadCancelled => 'Upload cancelled';

  @override
  String attachMediaTooltip(String limit) {
    return 'Photo or video from the gallery (up to $limit)';
  }

  @override
  String get attachMediaTooltipUnlimited => 'Photo or video from the gallery';

  @override
  String get composeHint => 'Link or text';

  @override
  String get send => 'Send';

  @override
  String get actions => 'Actions';

  @override
  String get deleteFileTitle => 'Delete file?';

  @override
  String get deleteItemTitle => 'Delete item?';

  @override
  String get deleteItemText =>
      'It will disappear from the cloud and all devices.';

  @override
  String get actionSelect => 'Select';

  @override
  String get actionAddNote => 'Add comment';

  @override
  String get actionEditNote => 'Edit comment';

  @override
  String get noteTitle => 'Comment';

  @override
  String get noteHint => 'What is this, why it matters';

  @override
  String noteEditedBy(String device) {
    return 'Last edited on $device';
  }

  @override
  String get actionSaveFile => 'Save file';

  @override
  String get actionCopyText => 'Copy text';

  @override
  String get actionSelectText => 'Select text';

  @override
  String get markdownSource => 'Show source text';

  @override
  String get documentUnreadable =>
      'Can\'t read this document — save the file and open it in another app';

  @override
  String get openWith => 'Open in another app';

  @override
  String get errNoAppToOpen =>
      'There is no app on this device that can open this file';

  @override
  String get fullscreen => 'Full screen';

  @override
  String get exitFullscreen => 'Exit full screen';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get playbackFailed =>
      'This file can\'t be played here — open it in another app';

  @override
  String get settings => 'Settings';

  @override
  String get appLockTitle => 'App lock';

  @override
  String get appLockEnabledSubtitle =>
      'PIN enabled · locks after 5 minutes in the background';

  @override
  String get appLockDisabledSubtitle => 'Protect the app with a PIN';

  @override
  String get appLockEnable => 'Enable PIN';

  @override
  String get appLockChangePin => 'Change PIN';

  @override
  String get appLockDisablePin => 'Turn off PIN';

  @override
  String get appLockSetPinTitle => 'Create a PIN';

  @override
  String get appLockCurrentPinTitle => 'Enter your current PIN';

  @override
  String get appLockEnterPinTitle => 'Enter PIN';

  @override
  String appLockPinInstructions(int length) {
    return 'Use a $length-digit PIN';
  }

  @override
  String get appLockEnterPinHint => 'Enter your 4-digit PIN';

  @override
  String get appLockSettingsCorrupt =>
      'The PIN record can\'t be read. Reset local keys to continue.';

  @override
  String get appLockRepeatPin => 'Repeat PIN';

  @override
  String get appLockPinInvalid => 'PIN must contain 4 digits';

  @override
  String get appLockPinMismatch => 'The PINs don\'t match';

  @override
  String get appLockWrongPin => 'Incorrect PIN';

  @override
  String appLockWaitSeconds(int seconds) {
    return 'Too many attempts. Try again in $seconds sec.';
  }

  @override
  String get appLockBiometrics => 'Unlock with fingerprint or biometrics';

  @override
  String get appLockBiometricReason => 'Unlock Transmitter';

  @override
  String get appLockUnlock => 'Unlock';

  @override
  String get appLockForgotPin => 'I forgot my PIN';

  @override
  String get appLockRecoveryTitle => 'Reset local keys?';

  @override
  String get appLockRecoveryMessage =>
      'All board keys on this device will be deleted. Cloud data and cloud sign-ins will remain. To restore your boards, add the keys from another device.';

  @override
  String get appLockRecover => 'Reset keys';

  @override
  String get appLockRecoveryComplete =>
      'Local keys were reset. Add them again from another device.';

  @override
  String get theme => 'Appearance';

  @override
  String get themeSystem => 'As in the system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeOcean => 'Ocean';

  @override
  String get themeForest => 'Forest';

  @override
  String get themeSunset => 'Sunset';

  @override
  String get themeNight => 'Night (black)';

  @override
  String get themeDracula => 'Dracula';

  @override
  String get themeNord => 'Nord';

  @override
  String get themeOneDark => 'One Dark';

  @override
  String get themeSolarized => 'Solarized Dark';

  @override
  String get themeGruvbox => 'Gruvbox';

  @override
  String get themeCatppuccin => 'Catppuccin Mocha';

  @override
  String storageLimitValue(String size) {
    return 'Limit: $size';
  }

  @override
  String get storageTitle => 'Storage on this device';

  @override
  String get storageIntro =>
      'Opened files are kept on the device (encrypted) so they open instantly and without internet. When space runs out, the ones opened longest ago go first. Items themselves are always kept.';

  @override
  String storageUsed(String size) {
    return 'Used: $size';
  }

  @override
  String get storageLimit => 'Limit for files';

  @override
  String get storageClear => 'Clear files';

  @override
  String get monospaceFont => 'Monospace font';

  @override
  String get copyAll => 'Copy all';

  @override
  String textTruncated(String size) {
    return 'Showing the beginning of the file ($size in total) — save it to read everything';
  }

  @override
  String showPhoto(String size) {
    return 'Show photo ($size)';
  }

  @override
  String get imageUnsupported =>
      'This image format can\'t be shown — save the file to open it';

  @override
  String get closeAction => 'Close';

  @override
  String get actionDeleteEverywhere => 'Delete on all devices';

  @override
  String get fileFallback => 'File';

  @override
  String get exportTextFileName => 'items.txt';

  @override
  String exportFileNote(String name) {
    return 'file $name';
  }

  @override
  String get shareTargetTitle => 'Send to Transmitter';

  @override
  String get sendTo => 'Send to';

  @override
  String get noVaultsYet => 'Create a vault key in Transmitter first.';

  @override
  String vaultNeedsSignIn(String provider) {
    return '$provider · sign in to the cloud first';
  }

  @override
  String sendingProgress(int current, int total) {
    return 'Sending $current of $total…';
  }

  @override
  String fileSkipped(String limit) {
    return 'Larger than $limit — won\'t be sent';
  }

  @override
  String shareReceiveFailed(String error) {
    return 'Couldn\'t receive the data: $error';
  }

  @override
  String get authPageTitle => 'Signed in';

  @override
  String get authPageClose =>
      'You can close this tab and return to Transmitter.';

  @override
  String get authPageReturn => 'Return to Transmitter';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'As in the system';

  @override
  String get deviceWorkProfile => 'work';

  @override
  String get deviceBrowserName => 'Browser';

  @override
  String get errAuthCancelled => 'Sign-in cancelled';

  @override
  String get errBrowserOpenFailed => 'Couldn\'t open the browser';

  @override
  String errAuthPortBusy(String port) {
    return 'Port $port is used by another program';
  }

  @override
  String get errPopupBlocked =>
      'The browser blocked the pop-up window. Allow pop-ups for this site.';

  @override
  String errAuthRejected(String provider, String details) {
    return '$provider rejected the sign-in: $details';
  }

  @override
  String errAuthStateMismatch(String provider) {
    return 'The response from $provider failed verification, please try again';
  }

  @override
  String errAuthNoCode(String provider) {
    return '$provider didn\'t return a sign-in code';
  }

  @override
  String errAuthTokenFailed(String provider, String details) {
    return 'Couldn\'t get a $provider token ($details)';
  }

  @override
  String get errCloudWrongPassword => 'Wrong email or password';

  @override
  String get errCloudSecondFactorRequired =>
      'Enter the code from your authenticator app';

  @override
  String get errCloudSecondFactorWrong =>
      'Wrong code — check the authenticator app and try again';

  @override
  String errCloudAccountBlocked(String provider) {
    return 'The $provider account is blocked — check it on the $provider website';
  }

  @override
  String errAuthNoOfflineAccess(String provider) {
    return '$provider didn\'t grant long-term access';
  }

  @override
  String get errCloudNotConnected => 'The cloud isn\'t connected';

  @override
  String get errCloudSignInAgain => 'Sign in to the cloud again';

  @override
  String errCloudAccessRevoked(String provider) {
    return 'Access to $provider was revoked, sign in again';
  }

  @override
  String errCloudWebSessionExpired(String provider) {
    return 'Sign-in to $provider in the browser lasts about an hour — sign in again (☁ → $provider)';
  }

  @override
  String errCloudTokenRefreshFailed(String provider, String details) {
    return 'Couldn\'t refresh the $provider token ($details)';
  }

  @override
  String errCloudRateLimited(String provider) {
    return '$provider is temporarily limiting requests, try again later';
  }

  @override
  String errCloudStorageStalled(String provider) {
    return '$provider\'s storage server isn\'t responding. If the rest of the internet works, your provider may be blocking it — try a VPN';
  }

  @override
  String get errCloudQuota => 'The cloud is out of space';

  @override
  String get errCloudFileNotFound =>
      'The file has already been deleted from the cloud';

  @override
  String errCloudNoUploadUrl(String provider) {
    return '$provider didn\'t return an upload address';
  }

  @override
  String errCloudRequestFailed(String provider, String details) {
    return '$provider error ($details)';
  }

  @override
  String errFileTooLarge(String limit) {
    return 'File is larger than $limit';
  }

  @override
  String get errDecryptionFailed => 'Couldn\'t decrypt the data';

  @override
  String get errKeyNotTransmitter => 'This isn\'t a Transmitter key';

  @override
  String get errKeyCorrupted => 'The key is damaged';

  @override
  String get errKeyRequiresUpdate =>
      'This key was created in a newer version of Transmitter — update the app';

  @override
  String get errNetwork => 'No connection — check your internet and try again';

  @override
  String get boardAccessAction => 'Read-only access…';

  @override
  String get boardAccessTitle => 'Read-only access';

  @override
  String get boardIntro =>
      'Anyone with the reader key will be able to view, copy and download all items in this vault, including comments — but not change them. Readers don\'t need a cloud account.';

  @override
  String get boardOpenAccess => 'Open access';

  @override
  String get boardReaderHint =>
      'Send this reader key to the people you want to share with. New items will appear for them automatically.';

  @override
  String get boardCloseAccess => 'Close access';

  @override
  String get boardCloseTitle => 'Close access?';

  @override
  String get boardCloseText =>
      'All reader keys you have given out will stop working. If you open access again, there will be a new key.';

  @override
  String get boardClosed => 'Access closed';

  @override
  String get errBoardClosed => 'The owner has closed access to this board';

  @override
  String boardSubtitle(String provider) {
    return 'Read-only · $provider';
  }

  @override
  String get readOnly => 'Read-only';

  @override
  String get readerKeyWarning =>
      'This is a read-only key: with it the board can be viewed, but not changed.';

  @override
  String get removeBoardText =>
      'The board will disappear only from this device. To get it back, you will need the reader key again.';

  @override
  String boardSignInAgain(String provider) {
    return 'Sign in to $provider again';
  }

  @override
  String get boardEmpty => 'Nothing on this board yet';

  @override
  String boardRenameFailed(String error) {
    return 'The vault is renamed, but readers will still see the old board name: $error';
  }

  @override
  String get boardUnsupported => 'This cloud doesn\'t support public boards';

  @override
  String errCloudSharingNotAllowed(String provider) {
    return 'Sign in to $provider again to allow public links: ☁ → $provider → Sign out, then Sign in';
  }

  @override
  String get errBoardSignatureInvalid =>
      'The board failed the integrity check: it was damaged or tampered with';

  @override
  String errUnknown(String error) {
    return 'Error: $error';
  }
}
