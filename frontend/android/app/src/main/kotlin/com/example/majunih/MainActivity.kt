package com.example.majunih

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.majunih/file_export"
        private const val PICK_IMAGE_REQUEST = 4102
    }

    private var pendingImageResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveCsvToDownloads" -> {
                    val fileName = call.argument<String>("fileName")
                    val content = call.argument<String>("content")
                    if (fileName.isNullOrBlank() || content == null) {
                        result.error("INVALID_ARGS", "Nama file atau konten CSV tidak valid", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val savedPath = saveToDownloads(fileName, content)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message ?: "Gagal menyimpan ke Download", null)
                    }
                }
                "pickImage" -> {
                    pendingImageResult?.success(null)
                    pendingImageResult = result
                    try {
                        val docIntent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/*"
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            putExtra("android.content.extra.SHOW_ADVANCED", true)
                        }
                        startActivityForResult(docIntent, PICK_IMAGE_REQUEST)
                    } catch (_: ActivityNotFoundException) {
                        try {
                            val getIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "image/*"
                            }
                            startActivityForResult(
                                Intent.createChooser(getIntent, "Pilih File Gambar"),
                                PICK_IMAGE_REQUEST,
                            )
                        } catch (e: Exception) {
                            pendingImageResult = null
                            result.error("PICKER_FAILED", e.message ?: "Gagal membuka pemilih file", null)
                        }
                    } catch (e: Exception) {
                        pendingImageResult = null
                        result.error("PICKER_FAILED", e.message ?: "Gagal membuka pemilih file", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_IMAGE_REQUEST) return

        val callback = pendingImageResult
        pendingImageResult = null
        if (callback == null) return

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            callback.success(null)
            return
        }

        try {
            val encoded = readAndCompressImage(uri)
            val name = resolveFileName(uri)
            callback.success(mapOf("base64" to encoded, "name" to name))
        } catch (e: Exception) {
            callback.error("READ_IMAGE_FAILED", e.message ?: "Gagal membaca gambar", null)
        }
    }

    private fun readAndCompressImage(uri: Uri): String {
        val rawBytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: run {
                val path = if (uri.scheme == "file") uri.path else null
                if (!path.isNullOrBlank()) File(path).readBytes() else null
            }
            ?: throw IllegalStateException("Tidak dapat membaca file gambar")

        val maxDim = 600
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(rawBytes, 0, rawBytes.size, bounds)
        var sampleSize = 1
        while (bounds.outWidth / sampleSize > maxDim * 2 || bounds.outHeight / sampleSize > maxDim * 2) {
            sampleSize *= 2
        }

        val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        val decoded = BitmapFactory.decodeByteArray(rawBytes, 0, rawBytes.size, decodeOpts)
        if (decoded != null) {
            val w = decoded.width
            val h = decoded.height
            val scaled = if (w > maxDim || h > maxDim) {
                val scale = maxDim.toFloat() / maxOf(w, h).toFloat()
                Bitmap.createScaledBitmap(decoded, (w * scale).toInt().coerceAtLeast(1), (h * scale).toInt().coerceAtLeast(1), true)
            } else {
                decoded
            }
            val out = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 82, out)
            if (scaled != decoded) scaled.recycle()
            decoded.recycle()
            val b64 = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
            return "data:image/jpeg;base64,$b64"
        }

        val mime = contentResolver.getType(uri)?.takeIf { it.startsWith("image/") } ?: "image/jpeg"
        val b64 = Base64.encodeToString(rawBytes, Base64.NO_WRAP)
        return "data:$mime;base64,$b64"
    }

    private fun resolveFileName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) {
                    val name = cursor.getString(idx)
                    if (!name.isNullOrBlank()) return name
                }
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "foto_produk.jpg"
    }

    private fun saveToDownloads(fileName: String, content: String): String {
        val bytes = content.toByteArray(Charsets.UTF_8)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = applicationContext.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "text/csv")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Tidak dapat membuat file di folder Download")

            try {
                resolver.openOutputStream(uri)?.use { stream ->
                    stream.write(bytes)
                    stream.flush()
                } ?: throw IllegalStateException("Gagal membuka stream untuk menulis CSV")

                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            return "Download/$fileName"
        }

        @Suppress("DEPRECATION")
        val publicDownloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val targetDir = if (publicDownloads != null && (publicDownloads.exists() || publicDownloads.mkdirs()) && publicDownloads.canWrite()) {
            publicDownloads
        } else {
            getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
        }
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }
        val outFile = File(targetDir, fileName)
        outFile.writeBytes(bytes)
        return outFile.absolutePath
    }
}
