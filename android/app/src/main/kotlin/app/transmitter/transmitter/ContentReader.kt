package app.transmitter.transmitter

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns

/**
 * Читает файл по content://-ссылке (из «Поделиться» или Галереи) в виде,
 * который понимает Dart: имя, MIME-тип, размер и байты.
 *
 * Файлы больше [limit] не читаются — передаются только имя и размер, чтобы
 * Dart показал понятную ошибку «Файл больше N МБ».
 */
class ContentReader(private val resolver: ContentResolver) {
    fun read(uri: Uri, fallbackType: String?, limit: Long): Map<String, Any?> {
        var name: String? = null
        var size: Long = -1
        resolver.query(
            uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameIndex >= 0) name = cursor.getString(nameIndex)
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
            }
        }
        val mimeType = resolver.getType(uri) ?: fallbackType
        val fileName = name ?: uri.lastPathSegment ?: "file"

        if (size > limit) {
            return mapOf("name" to fileName, "mimeType" to mimeType, "size" to size, "bytes" to null)
        }
        val bytes = resolver.openInputStream(uri)?.use { input ->
            if (size >= 0) {
                // Размер известен: читаем сразу в массив нужной длины, без
                // промежуточного буфера (важно для файлов до 100 МБ).
                readExactly(input, size.toInt())
            } else {
                // Размер неизвестен — читаем с ограничением.
                val data = input.readNBytesCompat(limit + 1)
                if (data.size > limit) null else data
            }
        }
        return mapOf(
            "name" to fileName,
            "mimeType" to mimeType,
            "size" to (bytes?.size?.toLong() ?: maxOf(size, limit + 1)),
            "bytes" to bytes,
        )
    }

    /** Ровно [size] байт; `null`, если поток оказался длиннее (размер был неверным). */
    private fun readExactly(input: java.io.InputStream, size: Int): ByteArray? {
        val data = ByteArray(size)
        var offset = 0
        while (offset < size) {
            val read = input.read(data, offset, size - offset)
            if (read < 0) return data.copyOf(offset)
            offset += read
        }
        return if (input.read() < 0) data else null
    }

    private fun java.io.InputStream.readNBytesCompat(max: Long): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (total < max) {
            val read = read(buffer, 0, minOf(buffer.size.toLong(), max - total).toInt())
            if (read < 0) break
            out.write(buffer, 0, read)
            total += read
        }
        return out.toByteArray()
    }
}
