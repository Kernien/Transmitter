// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get subVaults => 'Поддоски';

  @override
  String get createSubVault => 'Создать поддоску';

  @override
  String get noSubVaults => 'Поддосок пока нет';

  @override
  String get subVaultKeyWarning =>
      'Этот ключ даёт доступ к доске и ко всем её текущим и будущим поддоскам.';

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
  String get speedUnitB => 'Б/с';

  @override
  String get speedUnitKb => 'КБ/с';

  @override
  String get speedUnitMb => 'МБ/с';

  @override
  String get speedUnitGb => 'ГБ/с';

  @override
  String get decimalSeparator => ',';

  @override
  String sizeLimit(int mb) {
    return '$mb МБ';
  }

  @override
  String sizeLimitGb(int gb) {
    return '$gb ГБ';
  }

  @override
  String get sizeLimitUnlimited => 'Без лимита';

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
    return '$provider · $limit';
  }

  @override
  String vaultSubtitleConnectedUnlimited(String provider) {
    return '$provider · без лимита';
  }

  @override
  String vaultSubtitleConnectedPlain(String provider, String limit) {
    return '$provider · открытая · $limit';
  }

  @override
  String vaultSubtitleConnectedPlainUnlimited(String provider) {
    return '$provider · открытая · без лимита';
  }

  @override
  String vaultSubtitleNotConnected(String provider) {
    return '$provider · не подключено';
  }

  @override
  String vaultSubtitleNotConnectedPlain(String provider) {
    return '$provider · открытая · не подключено';
  }

  @override
  String get pinVault => 'Закрепить';

  @override
  String get unpinVault => 'Открепить';

  @override
  String get pinnedVault => 'Закреплено';

  @override
  String get pinVaultHint => 'Открывать по умолчанию при запуске';

  @override
  String get showKeyQr => 'Показать ключ / QR';

  @override
  String get rename => 'Переименовать';

  @override
  String get vaultIconAction => 'Значок доски…';

  @override
  String get vaultTagsAction => 'Теги…';

  @override
  String get manageTagsTitle => 'Теги доски';

  @override
  String get tagHint => 'Имя тега';

  @override
  String get existingTags => 'Имеющиеся теги';

  @override
  String get noTagsYet => 'Нет тегов';

  @override
  String deleteTagTitle(String tag) {
    return 'Удалить тег #$tag?';
  }

  @override
  String get deleteTagConfirm =>
      'Тег будет удалён из списка и снят со всех связанных элементов.';

  @override
  String get deleteTagAction => 'Удалить тег';

  @override
  String tagDeleted(String tag) {
    return 'Тег #$tag удалён';
  }

  @override
  String get filterAll => 'Все';

  @override
  String get selectIconTitle => 'Значок доски';

  @override
  String get iconsTab => 'Значки';

  @override
  String get emojisTab => 'Эмодзи';

  @override
  String get customEmojiHint => 'Любой свой эмодзи';

  @override
  String get resetToDefault => 'По умолчанию';

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
  String get selectBoardHint => 'Выберите доску в списке слева';

  @override
  String get keyNameLabel => 'Название, например «Работа»';

  @override
  String get cloudLabel => 'Облако';

  @override
  String cloudComingSoon(String provider) {
    return '$provider (скоро)';
  }

  @override
  String get providerP2p => 'Прямая связь (P2P)';

  @override
  String p2pPeersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count устройств в сети',
      few: '$count устройства в сети',
      one: '1 устройство в сети',
    );
    return '$_temp0';
  }

  @override
  String get p2pWaitingPeers => 'Ожидание устройств в сети';

  @override
  String get maxFileSizeLabel => 'Максимальный размер файла';

  @override
  String get maxFileSizeHelp =>
      'Действует на всех устройствах с этим ключом.\nПотом его можно изменить: ⋮ у базы → «Размер файлов…».';

  @override
  String get encryptVaultLabel => 'Шифровать данные';

  @override
  String get encryptVaultSubtitle =>
      'Если выключить, файлы будут лежать в облаке под своими именами — их можно будет открывать прямо в облаке.';

  @override
  String get fileSizeAction => 'Размер файлов…';

  @override
  String get fileSizeHelp =>
      'Для новых файлов на всех устройствах базы. Уже загруженные файлы остаются.';

  @override
  String vaultChangeFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

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
  String passwordSignInExplanation(String provider) {
    return 'Войдите почтой и паролем от аккаунта $provider. Пароль не сохраняется: приложение хранит только сеанс входа. У $provider нет доступа «только к одной папке», поэтому технически приложение видит весь диск, но работает только с папкой «Transmitter». Всё содержимое шифруется до отправки.';
  }

  @override
  String get emailLabel => 'Почта';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get secondFactorCodeLabel => 'Код двухфакторной аутентификации';

  @override
  String get signingIn => 'Вход…';

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
  String get dropHintUnlimited => 'Отпустите, чтобы отправить';

  @override
  String get feedEmpty =>
      'Пока пусто. Отправьте ссылку или перетащите сюда файл.';

  @override
  String attachFileTooltip(String limit) {
    return 'Прикрепить файл (до $limit)';
  }

  @override
  String get attachFileTooltipUnlimited => 'Прикрепить файл';

  @override
  String get attachFolder => 'Прикрепить папку';

  @override
  String attachFolderTooltip(String limit) {
    return 'Прикрепить папку (файлы до $limit)';
  }

  @override
  String get attachFolderTooltipUnlimited => 'Прикрепить папку';

  @override
  String get saveFolder => 'Сохранить папку';

  @override
  String savedFolder(String name) {
    return 'Папка «$name» сохранена';
  }

  @override
  String get openFolder => 'Открыть папку';

  @override
  String folderFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файлов',
      few: '$count файла',
      one: '1 файл',
    );
    return '$_temp0';
  }

  @override
  String get folderEmpty => 'Папка пуста';

  @override
  String get folderTitle => 'Папка';

  @override
  String get deleteFolderTitle => 'Удалить папку?';

  @override
  String get moveItem => 'Переместить';

  @override
  String get moveToTitle => 'Переместить в папку';

  @override
  String get folderRoot => 'Корень папки';

  @override
  String get newSubfolderHint => 'Или укажите путь новой подпапки';

  @override
  String get replaceFile => 'Заменить файл';

  @override
  String get replaceFolder => 'Заменить папку';

  @override
  String fileReplaced(String name) {
    return 'Файл «$name» заменён';
  }

  @override
  String folderReplaced(String name) {
    return 'Папка «$name» заменена';
  }

  @override
  String get fileRenamed => 'Файл переименован';

  @override
  String get folderRenamed => 'Папка переименована';

  @override
  String get addFilesToFolder => 'Добавить файлы';

  @override
  String get editText => 'Редактировать';

  @override
  String get discardChangesTitle => 'Отменить изменения?';

  @override
  String get discardChangesText =>
      'Несохранённые правки в тексте будут потеряны.';

  @override
  String get discard => 'Отменить правки';

  @override
  String get cancelUpload => 'Отменить отправку';

  @override
  String get uploadCancelled => 'Отправка отменена';

  @override
  String attachMediaTooltip(String limit) {
    return 'Фото или видео из Галереи (до $limit)';
  }

  @override
  String get attachMediaTooltipUnlimited => 'Фото или видео из Галереи';

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
  String get markdownSource => 'Показать исходный текст';

  @override
  String get documentUnreadable =>
      'Не удалось прочитать документ — сохраните файл и откройте его в другой программе';

  @override
  String get openWith => 'Открыть в другом приложении';

  @override
  String get errNoAppToOpen =>
      'На устройстве нет приложения, которое открывает такие файлы';

  @override
  String get fullscreen => 'На весь экран';

  @override
  String get exitFullscreen => 'Выйти из полноэкранного режима';

  @override
  String get play => 'Воспроизвести';

  @override
  String get pause => 'Пауза';

  @override
  String get playbackFailed =>
      'Этот файл здесь не воспроизвести — откройте его в другом приложении';

  @override
  String get settings => 'Настройки';

  @override
  String get aboutAppTitle => 'О программе';

  @override
  String get appDescription =>
      'Безопасная передача заметок и файлов между устройствами через личные облака со сквозным шифрованием или напрямую по P2P.';

  @override
  String get githubRepository => 'Репозиторий на GitHub';

  @override
  String appVersionLabel(String version) {
    return 'Версия $version';
  }

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String get checkingForUpdates => 'Проверка обновлений…';

  @override
  String get latestVersionInstalled => 'У вас установлена актуальная версия';

  @override
  String updateAvailable(String version) {
    return 'Доступна новая версия: $version';
  }

  @override
  String get updateAppAction => 'Обновить приложение';

  @override
  String get updatingApp => 'Обновление…';

  @override
  String downloadingUpdate(int percent) {
    return 'Загрузка обновления: $percent%';
  }

  @override
  String get updateSuccessRestart =>
      'Обновление загружено! Нажмите для перезапуска.';

  @override
  String get updateSuccessReady => 'Обновление загружено и готово к установке.';

  @override
  String get restartNow => 'Перезапустить';

  @override
  String get installAndRestart => 'Установить и перезапустить';

  @override
  String get installUpdate => 'Установить обновление';

  @override
  String get viewReleaseNotes => 'Список изменений на GitHub';

  @override
  String get updateCheckFailed => 'Не удалось проверить обновления';

  @override
  String get appLockTitle => 'Блокировка приложения';

  @override
  String get appLockEnabledSubtitle =>
      'ПИН-код включён · блокировка через 5 минут в фоне';

  @override
  String get appLockDisabledSubtitle => 'Защитить приложение ПИН-кодом';

  @override
  String get appLockEnable => 'Включить ПИН-код';

  @override
  String get appLockChangePin => 'Изменить ПИН-код';

  @override
  String get appLockDisablePin => 'Отключить ПИН-код';

  @override
  String get appLockSetPinTitle => 'Придумайте ПИН-код';

  @override
  String get appLockCurrentPinTitle => 'Введите текущий ПИН-код';

  @override
  String get appLockEnterPinTitle => 'Введите ПИН-код';

  @override
  String appLockPinInstructions(int length) {
    return 'Задайте $length-значный ПИН-код';
  }

  @override
  String get appLockEnterPinHint => 'Введите ПИН-код (4 цифры)';

  @override
  String get appLockSettingsCorrupt =>
      'Не удалось прочитать ПИН-код. Для продолжения сбросьте локальные ключи.';

  @override
  String get appLockRepeatPin => 'Повторите ПИН-код';

  @override
  String get appLockPinInvalid => 'ПИН-код должен состоять из 4 цифр';

  @override
  String get appLockPinMismatch => 'ПИН-коды не совпадают';

  @override
  String get appLockWrongPin => 'Неверный ПИН-код';

  @override
  String appLockWaitSeconds(int seconds) {
    return 'Слишком много попыток. Попробуйте снова через $seconds с.';
  }

  @override
  String get appLockBiometrics => 'Разблокировать по отпечатку или биометрии';

  @override
  String get appLockBiometricReason => 'Разблокировать Transmitter';

  @override
  String get appLockUnlock => 'Разблокировать';

  @override
  String get appLockForgotPin => 'Не помню ПИН-код';

  @override
  String get appLockRecoveryTitle => 'Сбросить локальные ключи?';

  @override
  String get appLockRecoveryMessage =>
      'Все ключи досок на этом устройстве будут удалены. Данные и подключение к облакам останутся. Чтобы вернуть доски, добавьте ключи с другого устройства.';

  @override
  String get appLockRecover => 'Сбросить ключи';

  @override
  String get appLockRecoveryComplete =>
      'Локальные ключи сброшены. Добавьте их снова с другого устройства.';

  @override
  String get theme => 'Оформление';

  @override
  String get themeSystem => 'Как в системе';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeOcean => 'Океан';

  @override
  String get themeForest => 'Лес';

  @override
  String get themeSunset => 'Закат';

  @override
  String get themeNight => 'Ночь (чёрная)';

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
  String get themeTokyoNight => 'Tokyo Night';

  @override
  String get themeMonokai => 'Monokai';

  @override
  String get themeGithubDark => 'GitHub Dark';

  @override
  String get themeRosePine => 'Rosé Pine';

  @override
  String get themeAyuMirage => 'Ayu Mirage';

  @override
  String get themeEverforest => 'Everforest';

  @override
  String get themeViceCity => 'Vice City';

  @override
  String storageLimitValue(String size) {
    return 'Лимит: $size';
  }

  @override
  String get storageTitle => 'Место на устройстве';

  @override
  String get storageIntro =>
      'Открытые файлы хранятся на устройстве (зашифрованными), чтобы открываться сразу и без интернета. Когда место заканчивается, первыми удаляются давно не открытые. Сами записи остаются всегда.';

  @override
  String storageUsed(String size) {
    return 'Занято: $size';
  }

  @override
  String get storageLimit => 'Лимит для файлов';

  @override
  String get storageClear => 'Очистить файлы';

  @override
  String get monospaceFont => 'Моноширинный шрифт';

  @override
  String get copyAll => 'Копировать всё';

  @override
  String textTruncated(String size) {
    return 'Показано начало файла (всего $size) — сохраните его, чтобы прочитать целиком';
  }

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
  String get errCloudWrongPassword => 'Неверная почта или пароль';

  @override
  String get errCloudSecondFactorRequired =>
      'Введите код из приложения-аутентификатора';

  @override
  String get errCloudSecondFactorWrong =>
      'Неверный код — проверьте приложение-аутентификатор и попробуйте снова';

  @override
  String errCloudAccountBlocked(String provider) {
    return 'Аккаунт $provider заблокирован — проверьте его на сайте $provider';
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
  String errCloudStorageStalled(String provider) {
    return 'Сервер хранения $provider не отвечает. Если остальной интернет работает, его может блокировать провайдер — попробуйте через VPN';
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
  String get errKeyRequiresUpdate =>
      'Этот ключ создан в более новой версии Transmitter — обновите приложение';

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

  @override
  String get feedTab => 'Лента';

  @override
  String get filesTab => 'Файлы';

  @override
  String get searchHint => 'Поиск на доске…';

  @override
  String get searchFolderHint => 'Поиск в папке…';

  @override
  String get searchVaultsHint => 'Поиск баз…';

  @override
  String get noFilesYet => 'На этой доске пока нет файлов';

  @override
  String get searchNoResults => 'Ничего не найдено';

  @override
  String get vaultEncryptedBadge => 'Зашифрована';

  @override
  String get vaultPlainBadge => 'Без шифрования';

  @override
  String get boardReaderBadge => 'Только чтение';

  @override
  String get searchAction => 'Поиск';

  @override
  String get clearSearch => 'Очистить';

  @override
  String get addAccount => 'Добавить аккаунт';

  @override
  String get renameAccount => 'Переименовать аккаунт';

  @override
  String get accountNameLabel => 'Название аккаунта';

  @override
  String get accountLabel => 'Аккаунт';

  @override
  String get switchAccount => 'Сменить аккаунт';

  @override
  String get selectAccount => 'Выберите аккаунт';

  @override
  String disconnectAccountConfirm(String name) {
    return 'Выйти из аккаунта «$name»?';
  }

  @override
  String get noAccountsConnected => 'Нет подключённых аккаунтов';

  @override
  String get pinPost => 'Закрепить';

  @override
  String get unpinPost => 'Открепить';

  @override
  String get pinnedPost => 'Закреплённое сообщение';

  @override
  String pinnedPosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count закреплённых сообщений',
      few: '$count закреплённых сообщения',
      one: '$count закреплённое сообщение',
    );
    return '$_temp0';
  }

  @override
  String get pinnedSection => 'Закреплённые';

  @override
  String get sortBy => 'Сортировка';

  @override
  String get sortDateDesc => 'Сначала новые';

  @override
  String get sortDateAsc => 'Сначала старые';

  @override
  String get sortNameAsc => 'По имени (А–Я)';

  @override
  String get sortNameDesc => 'По имени (Я–А)';

  @override
  String get sortSizeDesc => 'Сначала крупные';

  @override
  String get sortSizeAsc => 'Сначала мелкие';

  @override
  String get sortType => 'По типу';

  @override
  String get feedEmptyTitle => 'Лента пуста';

  @override
  String get feedEmptySubtitle =>
      'Отправляйте ссылки, файлы или фото через строку внизу';

  @override
  String get filesEmptySubtitle =>
      'Файлы и папки, отправленные на эту доску, появятся здесь';

  @override
  String get searchNoResultsSubtitle => 'Попробуйте изменить поисковый запрос';

  @override
  String get noSubVaultsSubtitle =>
      'Создайте поддоску с отдельной лентой внутри этой доски';

  @override
  String get folderEmptySubtitle =>
      'Нажмите кнопку + внизу, чтобы добавить файлы или подпапки';

  @override
  String get vaultsEmptyTitle => 'Нет подключённых досок';
}
