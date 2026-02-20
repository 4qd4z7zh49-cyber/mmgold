package com.example.mmgold

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "mmgold/files"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveImageToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName") ?: "mmgold_voucher.png"
                val mimeType = call.argument<String>("mimeType") ?: "image/png"

                if (bytes == null || bytes.isEmpty()) {
                    result.error("INVALID_BYTES", "Image bytes are empty", null)
                    return@setMethodCallHandler
                }

                try {
                    val path = saveImageToDownloads(bytes, fileName, mimeType)
                    result.success(path)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            }
    }

    private fun saveImageToDownloads(bytes: ByteArray, fileName: String, mimeType: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/mmgold")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val itemUri = resolver.insert(collection, values)
                ?: throw IllegalStateException("Unable to create download item")

            resolver.openOutputStream(itemUri)?.use { stream ->
                stream.write(bytes)
            } ?: throw IllegalStateException("Unable to open download output stream")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(itemUri, values, null, null)
            return "/storage/emulated/0/Download/mmgold/$fileName"
        }

        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val folder = File(downloadsDir, "mmgold")
        if (!folder.exists()) folder.mkdirs()

        val file = File(folder, fileName)
        FileOutputStream(file).use { it.write(bytes) }
        return file.absolutePath
    }
}
