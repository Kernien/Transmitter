import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Кодировщик и декодировщик сообщений с префиксом длины (4 байта) поверх TCP.
class P2pSocketCodec {
  P2pSocketCodec._();

  /// Отправляет JSON-сообщение с 4-байтным заголовком длины.
  static void sendMessage(Socket socket, Map<String, dynamic> json) {
    final payload = utf8.encode(jsonEncode(json));
    final header = ByteData(4)..setUint32(0, payload.length);
    socket.add(header.buffer.asUint8List());
    socket.add(payload);
  }

  /// Преобразует сырой поток байтов сокета в поток распарсенных JSON-сообщений.
  static Stream<Map<String, dynamic>> decodeMessages(Stream<Uint8List> socketStream) {
    late StreamController<Map<String, dynamic>> controller;
    final buffer = BytesBuilder(copy: false);
    int? expectedLength;

    void processBuffer() {
      while (true) {
        if (expectedLength == null) {
          if (buffer.length < 4) return;
          final bytes = buffer.takeBytes();
          final header = ByteData.sublistView(Uint8List.fromList(bytes.sublist(0, 4)));
          expectedLength = header.getUint32(0);
          if (bytes.length > 4) {
            buffer.add(bytes.sublist(4));
          }
        }

        if (expectedLength != null) {
          if (buffer.length < expectedLength!) return;
          final bytes = buffer.takeBytes();
          final payload = bytes.sublist(0, expectedLength!);
          if (bytes.length > expectedLength!) {
            buffer.add(bytes.sublist(expectedLength!));
          }
          final length = expectedLength!;
          expectedLength = null;

          try {
            final json = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
            controller.add(json);
          } catch (e) {
            controller.addError(FormatException('Invalid P2P JSON ($length bytes): $e'));
          }
        }
      }
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        socketStream.listen(
          (chunk) {
            buffer.add(chunk);
            processBuffer();
          },
          onError: controller.addError,
          onDone: controller.close,
          cancelOnError: false,
        );
      },
    );

    return controller.stream;
  }
}
