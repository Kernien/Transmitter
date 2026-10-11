import 'package:flutter/foundation.dart';

import '../../core/share/incoming_share.dart';
import '../../core/vault/vault_key.dart';
import '../../data/post_repository.dart';

typedef VaultOpener = Future<PostRepository> Function(VaultKey key);

/// Отправка того, чем поделились из другого приложения, в выбранную базу.
class ShareTargetController extends ChangeNotifier {
  ShareTargetController({
    required this.content,
    required List<VaultKey> vaults,
    required bool Function(VaultKey) isUsable,
    required this._openVault,
  }) : vaults = List.unmodifiable(vaults),
       _isUsable = isUsable {
    _selected = this.vaults.where(isUsable).firstOrNull;
  }

  final SharedContent content;
  final List<VaultKey> vaults;
  final bool Function(VaultKey) _isUsable;
  final VaultOpener _openVault;

  VaultKey? _selected;
  bool _sending = false;
  int _sent = 0;
  Object? _error;

  VaultKey? get selected => _selected;
  bool get isSending => _sending;

  /// Ошибка отправки; текст на языке интерфейса — `describeError`.
  Object? get error => _error;

  /// Сколько постов уже отправлено и сколько всего будет.
  int get sentCount => _sent;
  int get totalCount => _sendableFiles.length + (_textAsPost ? 1 : 0);

  bool isUsable(VaultKey key) => _isUsable(key);

  /// Лимит размера файла выбранной базы.
  int get maxFileSize => _selected?.maxFileSize ?? VaultKey.defaultMaxFileSize;

  /// Пропускается ли файл: он больше лимита выбранной базы.
  bool isSkipped(SharedFile file) => file.exceeds(maxFileSize);

  /// Файлы, которые будут отправлены (слишком большие пропускаются).
  List<SharedFile> get _sendableFiles =>
      content.files.where((f) => !isSkipped(f)).toList();

  List<SharedFile> get skippedFiles => content.files.where(isSkipped).toList();

  /// Текст уходит отдельным постом, только если нет файлов; иначе он
  /// становится подписью к первому файлу.
  bool get _textAsPost => content.hasText && _sendableFiles.isEmpty;

  bool get canSend => !_sending && _selected != null && totalCount > 0;

  void select(VaultKey key) {
    if (!_isUsable(key) || _sending) return;
    _selected = key;
    notifyListeners();
  }

  /// Возвращает `true`, если всё отправлено.
  Future<bool> send() async {
    final target = _selected;
    if (!canSend || target == null) return false;
    _sending = true;
    _sent = 0;
    _error = null;
    notifyListeners();
    try {
      final repository = await _openVault(target);
      final text = content.text?.trim() ?? '';
      if (_textAsPost) {
        await repository.sendText(text);
        _progress();
      }
      final files = _sendableFiles;
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        await repository.sendFile(
          fileName: file.name,
          bytes: file.bytes!,
          mimeType: file.mimeType,
          caption: i == 0 ? text : '',
        );
        _progress();
      }
      return true;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  void _progress() {
    _sent++;
    notifyListeners();
  }
}
