import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/domain/post.dart';

void main() {
  test('Post.tags: извлечение тегов из текста и комментария', () {
    final now = DateTime.now();

    final post1 = Post(
      id: '1',
      kind: PostKind.text,
      createdAt: now,
      senderDevice: 'Device',
      text: 'Привет #мир #тест и снова #мир',
    );
    expect(post1.tags, ['мир', 'тест']);

    final post2 = Post(
      id: '2',
      kind: PostKind.text,
      createdAt: now,
      senderDevice: 'Device',
      text: '#Работа-2026 #dev_tag #Transmitter',
      note: PostNote(
        postId: '2',
        text: 'Пояснение с #важное',
        editedAt: now,
        editorDevice: 'Device',
      ),
    );
    expect(post2.tags, ['Работа-2026', 'dev_tag', 'Transmitter', 'важное']);

    final post3 = Post(
      id: '3',
      kind: PostKind.text,
      createdAt: now,
      senderDevice: 'Device',
      text: 'Без тегов https://example.com#anchor ## ### #',
    );
    expect(post3.tags, isEmpty);
  });
}
