package id.gmls.logeva

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Kanal "id.gmls.logeva/unduhan":
 *  - simpan: menyimpan file LANGSUNG ke folder Download/LOGEVA (tanpa memilih
 *    lokasi), supaya file dari HP Induk mudah dicari & dikirim lagi.
 *  - pilih: membuka pemilih file yang langsung berada di folder Download
 *    (tempat file Bluetooth / Quick Share / LOGEVA tersimpan).
 *  - ambilBerkasMasuk: file yang dibuka lewat "Buka dengan LOGEVA" / menu
 *    Bagikan (ZIP dari Quick Share, Bluetooth, WhatsApp, aplikasi File).
 *    Saat aplikasi sudah terbuka, Flutter diberi tahu lewat "berkasMasuk".
 */
class MainActivity : FlutterActivity() {
    private val kanal = "id.gmls.logeva/unduhan"
    private val kodePilih = 4107
    private var hasilPilih: MethodChannel.Result? = null
    private var saluran: MethodChannel? = null
    private var berkasMasuk: Map<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kanal)
        saluran = ch
        tanganiIntent(intent)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "ambilBerkasMasuk" -> {
                    result.success(berkasMasuk)
                    berkasMasuk = null
                }
                "simpan" -> {
                    val nama = call.argument<String>("nama")
                    val bytes = call.argument<ByteArray>("bytes")
                    val mime = call.argument<String>("mime") ?: "application/octet-stream"
                    if (nama == null || bytes == null) {
                        result.error("ARG", "Nama atau isi file kosong", null)
                    } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        // Android 9 ke bawah: Flutter memakai pemilih lokasi biasa.
                        result.error("TIDAK_DIDUKUNG", "Android < 10", null)
                    } else {
                        try {
                            result.success(simpanKeUnduhan(nama, bytes, mime))
                        } catch (e: Exception) {
                            result.error("GAGAL", e.message, null)
                        }
                    }
                }
                "pilih" -> {
                    if (hasilPilih != null) {
                        result.error("SIBUK", "Pemilih file sedang terbuka", null)
                    } else {
                        hasilPilih = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                putExtra(
                                    DocumentsContract.EXTRA_INITIAL_URI,
                                    DocumentsContract.buildDocumentUri(
                                        "com.android.externalstorage.documents", "primary:Download"
                                    )
                                )
                            }
                        }
                        try {
                            startActivityForResult(intent, kodePilih)
                        } catch (e: Exception) {
                            hasilPilih = null
                            result.error("GAGAL", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (tanganiIntent(intent)) saluran?.invokeMethod("berkasMasuk", null)
    }

    /** Simpan file dari intent VIEW/SEND. Hasil: true = ada file baru. */
    private fun tanganiIntent(intent: Intent?): Boolean {
        if (intent == null) return false
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
                }
            else -> null
        }
        if (uri == null) return false
        // Supaya tidak dibaca ulang kalau activity dibuat ulang.
        intent.action = Intent.ACTION_MAIN
        return try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return false
            berkasMasuk = mapOf("nama" to (namaFile(uri) ?: uri.lastPathSegment ?: "file.zip"), "bytes" to bytes)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Hasil: lokasi yang mudah dibaca, misal "Download/LOGEVA/nama.zip". */
    private fun simpanKeUnduhan(nama: String, bytes: ByteArray, mime: String): String {
        val folder = Environment.DIRECTORY_DOWNLOADS + "/LOGEVA"
        val nilai = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, nama)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, folder)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, nilai)
            ?: throw IllegalStateException("Folder Download tidak bisa ditulis")
        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("File tidak bisa dibuka")
            nilai.clear()
            nilai.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, nilai, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        // Nama bisa diberi akhiran (1) oleh Android kalau sudah ada yang sama.
        return "$folder/${namaFile(uri) ?: nama}"
    }

    private fun namaFile(uri: Uri): String? =
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        }

    @Deprecated("Dipakai untuk hasil pemilih file")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != kodePilih) return
        val result = hasilPilih ?: return
        hasilPilih = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null) {
                result.error("GAGAL", "Isi file tidak bisa dibaca", null)
                return
            }
            result.success(mapOf("nama" to (namaFile(uri) ?: "file"), "bytes" to bytes))
        } catch (e: Exception) {
            result.error("GAGAL", e.message, null)
        }
    }
}
