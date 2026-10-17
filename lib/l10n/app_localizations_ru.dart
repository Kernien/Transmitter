// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get retry => 'Повторить';

  @override
  String get later => 'Позже';

  @override
  String get add => 'Добавить';

  @override
  String get create => 'Создать';

  @override
  String get untitled => 'Без названия';

  @override
  String get copied => 'Скопировано';

  @override
  String get saved => 'Сохранено';

  @override
  String get sent => 'Отправлено';

  @override
  String savedFile(String name) {
    return 'Сохранено: $name';
  }

  @override
  String get sizeUnitB => 'Б';

  @override
  String get sizeUnitKb => 'КБ';

  @override
  String get sizeUnitMb => 'МБ';

  @override
  String get sizeUnitGb => 'ГБ';

  @override
  String get decimalSeparator => ',';

  @override
  String sizeLimit(int mb) {
    return '$mb МБ';
  }

  @override
  String deviceNameTooltip(String name) {
    return 'Имя устройства: $name';
  }

  @override
  String get clouds => 'Облака';

  @override
  String get addKey => 'Добавить ключ';

  @override
  String get newKey => 'Новый ключ';

  @override
  String providerNotSupported(String provider) {
    return '$provider пока не поддерживается';
  }

  @override
  String vaultSubtitleConnected(String provider, String limit) {
    return '$provider · файлы до $limit';
  }

  @override
  String vaultSubtitleNotConnected(String provider) {
    return '$provider · не подключено';
  }

  @override
  String get showKeyQr => 'Показать ключ / QR';

  @override
  String get rename => 'Переименовать';

  @override
  String get removeFromDevice => 'Удалить с устройства';

  @override
  String get nameTitle => 'Название';

  @override
  String get removeKeyTitle => 'Удалить ключ?';

  @override
  String get removeKeyText =>
      'Ключ будет удалён только с этого устройства. Данные в облаке останутся. Если у вас нет копии ключа, доступ к базе будет потерян.';

  @override
  String get vaultsEmpty =>
      'Создайте новый ключ или добавьте ключ с другого устройства, отсканировав его QR-код.';

  @override
  String get keyNameLabel => 'Название, например «Работа»';

  @override
  String get cloudLabel => 'Облако';

  @override
  String cloudComingSoon(String provider) {
    return '$provider (скоро)';
  }

  @override
  String get maxFileSizeLabel => 'Максимальный размер файла';

  @override
  String get maxFileSizeHelp =>
      'Действует на всех устройствах с этим ключом.\nИзменить его потом нельзя.';

  @override
  String get scanQr => 'Сканировать QR-код';

  @override
  String get orPasteKey => 'или вставьте ключ:';

  @override
  String get scanTitle => 'Наведите камеру на QR-код';

  @override
  String get vaultKeyTitle => 'Ключ базы';

  @override
  String get copyKey => 'Скопировать ключ';

  @override
  String get keyCopied => 'Ключ скопирован';

  @override
  String get keyWarning =>
      'Любой, у кого есть этот ключ, может читать и добавлять записи в базу. Передавайте его только на свои устройства.';

  @override
  String get signIn => 'Войти';

  @override
  String get signOut => 'Выйти';

  @override
  String get statusSoon => 'Скоро';

  @override
  String get statusConnected => 'Подключено';

  @override
  String get statusNotConnected => 'Не подключено';

  @override
  String connectTitle(String provider) {
    return 'Подключить $provider';
  }

  @override
  String connectExplanation(String provider) {
    return 'Войдите в $provider на этом устройстве. Приложение получит доступ только к своей отдельной папке, остальные файлы ему не видны. Всё содержимое шифруется до отправки.';
  }

  @override
  String cloudNotConfigured(String provider) {
    return 'В этой сборке не задан ключ приложения для $provider (см. docs/DEVELOPMENT.md).';
  }

  @override
  String get finishSignInInBrowser =>
      'Завершите вход в открывшемся окне браузера…';

  @override
  String signInTo(String provider) {
    return 'Войти в $provider';
  }

  @override
  String connectFailed(String error) {
    return 'Не удалось подключиться: $error';
  }

  @override
  String get deviceNameFirstRunTitle => 'Как назвать это устройство?';

  @override
  String get deviceNameTitle => 'Имя устройства';

  @override
  String get deviceNameFirstRunText =>
      'Этим именем будут подписаны записи с этого устройства — так на других устройствах будет понятно, откуда они пришли.';

  @override
  String get deviceNameEditText =>
      'Новые записи будут подписаны новым именем; старые сохранят прежнее.';

  @override
  String get deviceNameHint => 'Например, «Redmi — рабочий» или «Ноутбук»';

  @override
  String get enterName => 'Введите имя';

  @override
  String get vaultFallbackTitle => 'База';

  @override
  String openVaultFailed(String error) {
    return 'Не удалось открыть базу: $error';
  }

  @override
  String get clearFeed => 'Очистить ленту';

  @override
  String get clearSelection => 'Снять выделение';

  @override
  String selectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get selectAll => 'Выбрать все';

  @override
  String get share => 'Поделиться';

  @override
  String get downloadSelected => 'Скачать выбранное';

  @override
  String get deleteSelected => 'Удалить выбранное';

  @override
  String deleteSelectedTitle(int count) {
    return 'Удалить выбранное ($count)?';
  }

  @override
  String get deleteSelectedText =>
      'Записи и файлы будут удалены из облака на всех устройствах.';

  @override
  String get clearFeedTitle => 'Очистить ленту?';

  @override
  String get clearFeedText =>
      'Все записи и файлы этой базы будут удалены из облака на всех устройствах. Отменить это нельзя.';

  @override
  String get deleteAll => 'Удалить всё';

  @override
  String dropHint(String limit) {
    return 'Отпустите, чтобы отправить (до $limit на файл)';
  }

  @override
  String get feedEmpty =>
      'Пока пусто. Отправьте ссылку или перетащите сюда файл.';

  @override
  String attachFileTooltip(String limit) {
    return 'Прикрепить файл (до $limit)';
  }

  @override
  String attachMediaTooltip(String limit) {
    return 'Фото или видео из Галереи (до $limit)';
  }

  @override
  String get composeHint => 'Ссылка или текст';

  @override
  String get send => 'Отправить';

  @override
  String get actions => 'Действия';

  @override
  String get deleteFileTitle => 'Удалить файл?';

  @override
  String get deleteItemTitle => 'Удалить запись?';

  @override
  String get deleteItemText => 'Запись исчезнет из облака и со всех устройств.';

  @override
  String get actionSelect => 'Выбрать';

  @override
  String get actionAddNote => 'Добавить комментарий';

  @override
  String get actionEditNote => 'Изменить комментарий';

  @override
  String get noteTitle => 'Комментарий';

  @override
  String get noteHint => 'Что это и зачем';

  @override
  String noteEditedBy(String device) {
    return 'Последняя правка: $device';
  }

  @override
  String get actionSaveFile => 'Сохранить файл';

  @override
  String get actionCopyText => 'Копировать текст';

  @override
  String get actionSelectText => 'Выделить текст';

  @override
  String showPhoto(String size) {
    return 'Показать фото ($size)';
  }

  @override
  String get imageUnsupported =>
      'Этот формат изображения не показать — сохраните файл, чтобы открыть его';

  @override
  String get closeAction => 'Закрыть';

  @override
  String get actionDeleteEverywhere => 'Удалить для всех устройств';

  @override
  String get fileFallback => 'Файл';

  @override
  String get exportTextFileName => 'записи.txt';

  @override
  String exportFileNote(String name) {
    return 'файл $name';
  }

  @override
  String get shareTargetTitle => 'Отправить в Transmitter';

  @override
  String get sendTo => 'Куда отправить';

  @override
  String get noVaultsYet => 'Сначала создайте ключ базы в Transmitter.';

  @override
  String vaultNeedsSignIn(String provider) {
    return '$provider · сначала войдите в облако';
  }

  @override
  String sendingProgress(int current, int total) {
    return 'Отправка $current из $total…';
  }

  @override
  String fileSkipped(String limit) {
    return 'Больше $limit — не будет отправлен';
  }

  @override
  String shareReceiveFailed(String error) {
    return 'Не удалось получить данные: $error';
  }

  @override
  String get authPageTitle => 'Вход выполнен';

  @override
  String get authPageClose =>
      'Можно закрыть эту вкладку и вернуться в Transmitter.';

  @override
  String get authPageReturn => 'Вернуться в Transmitter';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get deviceWorkProfile => 'рабочий';

  @override
  String get deviceBrowserName => 'Браузер';

  @override
  String get errAuthCancelled => 'Вход отменён';

  @override
  String get errBrowserOpenFailed => 'Не удалось открыть браузер';

  @override
  String errAuthPortBusy(String port) {
    return 'Порт $port занят другой программой';
  }

  @override
  String get errPopupBlocked =>
      'Браузер заблокировал всплывающее окно. Разрешите всплывающие окна для этого сайта.';

  @override
  String errAuthRejected(String provider, String details) {
    return '$provider отклонил вход: $details';
  }

  @override
  String errAuthStateMismatch(String provider) {
    return 'Ответ $provider не прошёл проверку, попробуйте ещё раз';
  }

  @override
  String errAuthNoCode(String provider) {
    return '$provider не вернул код входа';
  }

  @override
  String errAuthTokenFailed(String provider, String details) {
    return 'Не удалось получить токен $provider ($details)';
  }

  @override
  String errAuthNoOfflineAccess(String provider) {
    return '$provider не выдал долгосрочный доступ';
  }

  @override
  String get errCloudNotConnected => 'Облако не подключено';

  @override
  String get errCloudSignInAgain => 'Нужно заново войти в облако';

  @override
  String errCloudAccessRevoked(String provider) {
    return 'Доступ к $provider отозван, войдите заново';
  }

  @override
  String errCloudWebSessionExpired(String provider) {
    return 'Вход в $provider в браузере действует около часа — войдите снова (☁ → $provider)';
  }

  @override
  String errCloudTokenRefreshFailed(String provider, String details) {
    return 'Не удалось обновить токен $provider ($details)';
  }

  @override
  String errCloudRateLimited(String provider) {
    return '$provider временно ограничил запросы, попробуйте позже';
  }

  @override
  String get errCloudQuota => 'В облаке закончилось место';

  @override
  String get errCloudFileNotFound => 'Файл уже удалён из облака';

  @override
  String errCloudNoUploadUrl(String provider) {
    return '$provider не вернул адрес для загрузки файла';
  }

  @override
  String errCloudRequestFailed(String provider, String details) {
    return 'Ошибка $provider ($details)';
  }

  @override
  String errFileTooLarge(String limit) {
    return 'Файл больше $limit';
  }

  @override
  String get errDecryptionFailed => 'Не удалось расшифровать данные';

  @override
  String get errKeyNotTransmitter => 'Это не ключ Transmitter';

  @override
  String get errKeyCorrupted => 'Ключ повреждён';

  @override
  String get errNetwork =>
      'Нет связи — проверьте интернет и попробуйте ещё раз';

  @override
  String get boardAccessAction => 'Доступ на чтение…';

  @override
  String get boardAccessTitle => 'Доступ на чтение';

  @override
  String get boardIntro =>
      'Любой, у кого есть ключ читателя, сможет смотреть, копировать и скачивать все записи этой базы вместе с комментариями — но не менять их. Аккаунт облака читателю не нужен.';

  @override
  String get boardOpenAccess => 'Открыть доступ';

  @override
  String get boardReaderHint =>
      'Отправьте этот ключ читателя тем, с кем хотите поделиться. Новые записи появятся у них сами.';

  @override
  String get boardCloseAccess => 'Закрыть доступ';

  @override
  String get boardCloseTitle => 'Закрыть доступ?';

  @override
  String get boardCloseText =>
      'Все выданные ключи читателя перестанут работать. Если открыть доступ снова, ключ будет новым.';

  @override
  String get boardClosed => 'Доступ закрыт';

  @override
  String get errBoardClosed => 'Владелец закрыл доступ к этой доске';

  @override
  String boardSubtitle(String provider) {
    return 'Только чтение · $provider';
  }

  @override
  String get readOnly => 'Только чтение';

  @override
  String get readerKeyWarning =>
      'Это ключ только для чтения: с ним доску можно смотреть, но не менять.';

  @override
  String get removeBoardText =>
      'Доска пропадёт только с этого устройства. Чтобы вернуть её, снова понадобится ключ читателя.';

  @override
  String boardSignInAgain(String provider) {
    return 'Войти в $provider заново';
  }

  @override
  String get boardEmpty => 'На доске пока ничего нет';

  @override
  String boardRenameFailed(String error) {
    return 'База переименована, но читатели пока видят старое название доски: $error';
  }

  @override
  String get boardUnsupported => 'Это облако не поддерживает публичные доски';

  @override
  String errCloudSharingNotAllowed(String provider) {
    return 'Чтобы разрешить публичные ссылки, войдите в $provider заново: ☁ → $provider → «Выйти», затем «Войти»';
  }

  @override
  String get errBoardSignatureInvalid =>
      'Доска не прошла проверку подлинности: она повреждена или подменена';

  @override
  String errUnknown(String error) {
    return 'Ошибка: $error';
  }
}
