import 'cloud_provider_id.dart';
import 'cloud_storage.dart';

/// Вызывается, когда облако выдало новые учётные данные (например, после
/// обновления токена). Их нужно сохранить вместо старых.
typedef CredentialsChanged = Future<void> Function(String credentials);

/// Точка подключения облачного сервиса к приложению.
///
/// Чтобы добавить новое облако, создайте реализацию этого интерфейса в
/// `providers/` и зарегистрируйте её в `CloudProviderRegistry` (см. `main.dart`).
abstract interface class CloudProviderAdapter {
  CloudProviderId get id;

  /// `false`, если в сборке не задан ключ приложения для этого облака.
  bool get isConfigured;

  /// Подсказка, что делать, если [isConfigured] равно `false`.
  String get configurationHint;

  /// Проводит вход пользователя и возвращает учётные данные в виде строки.
  /// Формат строки знает только сам адаптер.
  ///
  /// В вебе метод нужно вызывать прямо из обработчика нажатия: до открытия
  /// окна входа в нём не должно быть `await`.
  Future<String> signIn();

  CloudStorage createStorage(
    String credentials, {
    required CredentialsChanged onCredentialsChanged,
  });
}

/// Набор доступных облаков. Облака, которых нет в реестре, показываются в
/// интерфейсе как «скоро».
class CloudProviderRegistry {
  CloudProviderRegistry(Iterable<CloudProviderAdapter> adapters)
      : _adapters = {for (final a in adapters) a.id: a};

  final Map<CloudProviderId, CloudProviderAdapter> _adapters;

  bool supports(CloudProviderId id) => _adapters.containsKey(id);

  CloudProviderAdapter adapterFor(CloudProviderId id) {
    final adapter = _adapters[id];
    if (adapter == null) {
      throw UnsupportedError('${id.title} пока не поддерживается');
    }
    return adapter;
  }
}
