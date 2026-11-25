import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/domain/post.dart';

void main() {
  group('FolderEntry tags', () {
    test('сериализация и десериализация тегов', () {
      const entry = FolderEntry(
        id: 'f1',
        relativePath: 'sub/doc.txt',
        size: 100,
        tags: ['работа', 'отчёт'],
      );

      final json = entry.toJson();
      expect(json['tags'], ['работа', 'отчёт']);

      final restored = FolderEntry.fromJson(json);
      expect(restored.tags, ['работа', 'отчёт']);
      expect(restored.fileName, 'doc.txt');
    });

    test('withTags обновляет теги', () {
      const entry = FolderEntry(
        id: 'f1',
        relativePath: 'doc.txt',
        size: 100,
      );
      final updated = entry.withTags(['важно']);
      expect(updated.tags, ['важно']);
      expect(updated.id, 'f1');
    });
  });

  group('FolderAttachment tags', () {
    test('сериализация и десериализация dirTags и allTags', () {
      const folder = FolderAttachment(
        name: 'Проект',
        files: [
          FolderEntry(
            id: 'f1',
            relativePath: 'src/main.dart',
            size: 200,
            tags: ['код', 'flutter'],
          ),
          FolderEntry(
            id: 'f2',
            relativePath: 'docs/readme.md',
            size: 150,
            tags: ['дока'],
          ),
        ],
        dirTags: {
          'src': ['разработка'],
          'docs': ['документация', 'важно'],
        },
      );

      final json = folder.toJson();
      expect(json['dirs'], {
        'src': ['разработка'],
        'docs': ['документация', 'важно'],
      });

      final restored = FolderAttachment.fromJson(json);
      expect(restored.name, 'Проект');
      expect(restored.dirTags['src'], ['разработка']);
      expect(restored.dirTags['docs'], ['документация', 'важно']);

      // allTags собирает теги файлов и подпапок
      expect(restored.allTags, containsAll(['код', 'flutter', 'дока', 'разработка', 'документация', 'важно']));
    });

    test('withFileTags и withDirTags обновляют структуру', () {
      const folder = FolderAttachment(
        name: 'Test',
        files: [
          FolderEntry(id: '1', relativePath: 'a.txt', size: 10),
        ],
      );

      final withFile = folder.withFileTags('1', ['новое']);
      expect(withFile.files.first.tags, ['новое']);

      final withDir = withFile.withDirTags('sub', ['директория']);
      expect(withDir.dirTags['sub'], ['директория']);

      final clearedDir = withDir.withDirTags('sub', []);
      expect(clearedDir.dirTags.containsKey('sub'), isFalse);
    });
  });

  group('Post explicitTags & combined tags', () {
    test('Post.tags объединяет хештеги, explicitTags и folder.allTags', () {
      final post = Post(
        id: 'p1',
        kind: PostKind.folder,
        createdAt: DateTime.utc(2026, 11, 25),
        senderDevice: 'PC',
        text: 'Пост с #текстТег в подписи',
        note: PostNote(
          postId: 'p1',
          text: 'Заметка с #заметкаТег',
          editedAt: DateTime.utc(2026, 11, 25),
          editorDevice: 'Phone',
        ),
        explicitTags: const ['ручнойТег'],
        folder: const FolderAttachment(
          name: 'Файлы',
          files: [
            FolderEntry(
              id: 'f1',
              relativePath: 'file.txt',
              size: 50,
              tags: ['тегФайла'],
            ),
          ],
          dirTags: {
            'sub': ['тегПапки'],
          },
        ),
      );

      expect(post.tags, containsAll([
        'текстТег',
        'заметкаТег',
        'ручнойТег',
        'тегФайла',
        'тегПапки',
      ]));

      final json = post.toJson();
      expect(json['tags'], ['ручнойТег']);

      final restored = Post.fromJson(json);
      expect(restored.explicitTags, ['ручнойТег']);
    });
  });
}
