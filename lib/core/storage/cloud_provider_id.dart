/// Поддерживаемые облачные сервисы.
///
/// [code] записывается в ключ хранилища и в настройки, поэтому его нельзя
/// менять у уже существующих значений.
enum CloudProviderId {
  googleDrive('gdrive', 'Google Drive'),
  dropbox('dropbox', 'Dropbox'),
  oneDrive('onedrive', 'OneDrive'),
  mega('mega', 'MEGA');

  const CloudProviderId(this.code, this.title);

  final String code;
  final String title;

  static CloudProviderId fromCode(String code) => values.firstWhere(
        (p) => p.code == code,
        orElse: () => throw FormatException('Неизвестное облако: $code'),
      );
}
