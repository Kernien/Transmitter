package app.transmitter.transmitter

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.util.UUID

/**
 * Читает файл по content://-ссылке (из «Поделиться» или Галереи) в виде,
 * который понимает Dart: имя, MIME-тип, размер и байты (для небольших файлов)
 * либо путь к временному файлу [tempDir] (для крупных файлов, чтобы не держать
 * их целиком в оперативной памяти).
 *
 * Файлы больше [limit] не читаются — передаются только имя и размер, чтобы
 * Dart показал понятную ошибку «Файл больше N МБ».
 */
class ContentReader(
    private val resolver: ContentResolver,
    private val tempDir: File? = null,
) {
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
        // Крупные файлы или файлы неизвестного размера при большом лимите
        // копируем во временный файл, чтобы не выделять гигабайтный массив в памяти.
        if (tempDir != null && (size > IN_MEMORY_LIMIT || (size < 0 && limit > IN_MEMORY_LIMIT))) {
            return copyToTempFile(uri, fileName, mimeType, size, limit)
        }
        val bytes = resolver.openInputStream(uri)?.use { input ->
            if (size >= 0) {
                readExactly(input, size.toInt())
            } else {
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

    private fun copyToTempFile(
        uri: Uri,
        fileName: String,
        mimeType: String?,
        declaredSize: Long,
        limit: Long,
    ): Map<String, Any?> {
        cleanOldTempFiles()
        tempDir!!.mkdirs()
        val tempFile = File(tempDir, "in_${UUID.randomUUID()}.tmp")
        var total = 0L
        var exceeded = false
        resolver.openInputStream(uri)?.use { input ->
            tempFile.outputStream().use { out ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    total += read
                    if (total > limit) {
                        exceeded = true
                        break
                    }
                    out.write(buffer, 0, read)
                }
            }
        } ?: run {
            tempFile.delete()
            return mapOf(
                "name" to fileName,
                "mimeType" to mimeType,
                "size" to maxOf(declaredSize, 0L),
                "bytes" to null,
            )
        }
        if (exceeded) {
            tempFile.delete()
            return mapOf(
                "name" to fileName,
                "mimeType" to mimeType,
                "size" to maxOf(declaredSize, total),
                "bytes" to null,
            )
        }
        return mapOf(
            "name" to fileName,
            "mimeType" to mimeType,
            "size" to total,
            "bytes" to null,
            "path" to tempFile.absolutePath,
        )
    }

    private fun cleanOldTempFiles() {
        val dir = tempDir ?: return
        val cutoff = System.currentTimeMillis() - 6 * 3600 * 1000L
        dir.listFiles()?.forEach { file ->
            if (file.lastModified() < cutoff) {
                file.delete()
            }
        }
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

    companion object {
        private const val IN_MEMORY_LIMIT = 16L * 1024 * 1024
    }
}
