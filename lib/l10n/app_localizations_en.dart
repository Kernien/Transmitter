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
  String get decimalSeparator => '.';

  @override
  String sizeLimit(int mb) {
    return '$mb MB';
  }

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
  String vaultSubtitleNotConnected(String provider) {
    return '$provider · not connected';
  }

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
      'Applies to all devices with this key.\nIt can\'t be changed later.';

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
  String get feedEmpty => 'Nothing here yet. Send a link or drop a file here.';

  @override
  String attachFileTooltip(String limit) {
    return 'Attach a file (up to $limit)';
  }

  @override
  String attachMediaTooltip(String limit) {
    return 'Photo or video from the gallery (up to $limit)';
  }

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
