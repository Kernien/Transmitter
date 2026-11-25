/// Поддерживаемые облачные сервисы.
///
/// [code] записывается в ключ хранилища и в настройки, поэтому его нельзя
/// менять у уже существующих значений. Код `onedrive` занят: OneDrive был в
/// списке («Скоро»), но так и не появился — новому облаку его не давать.
enum CloudProviderId {
  googleDrive('gdrive', 'Google Drive'),
  dropbox('dropbox', 'Dropbox'),
  mega('mega', 'MEGA'),
  p2p('p2p', 'P2P');

  const CloudProviderId(this.code, this.title);

  final String code;
  final String title;

  /// Является ли облачным сервисом (в отличие от прямой P2P-связи).
  bool get isCloud => this != CloudProviderId.p2p;

  static CloudProviderId fromCode(String code) => values.firstWhere(
    (p) => p.code == code,
    orElse: () => throw FormatException('Unknown cloud: $code'),
  );
}
