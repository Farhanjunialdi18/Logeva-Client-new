package id.gmls.logeva

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.os.storage.StorageVolume
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
 *  - simpanFlashdisk: menyimpan file LANGSUNG ke folder LOGEVA di flashdisk
 *    (USB OTG). Pertama kali Android menanyakan izin sekali (layar langsung
 *    terbuka di flashdisk); setelah itu tanpa memilih lokasi lagi.
 *  - adaFlashdisk / daftarFlashdisk / bacaFlashdisk: IMPOR dari flashdisk
 *    tanpa pemilih file Android: LOGEVA menampilkan sendiri daftar file
 *    di flashdisk (folder utama + satu tingkat di bawahnya).
 *  - ambilBerkasMasuk: file yang dibuka lewat "Buka dengan LOGEVA" / menu
 *    Bagikan (ZIP dari Quick Share, Bluetooth, WhatsApp, aplikasi File).
 *    Saat aplikasi sudah terbuka, Flutter diberi tahu lewat "berkasMasuk".
 */
class MainActivity : FlutterActivity() {
    private val kanal = "id.gmls.logeva/unduhan"
    private val kodePilih = 4107
    private val kodeFlashdisk = 4108
    private var tundaIzin: TundaIzin? = null

    /** Menunggu layar izin flashdisk; [lanjut] dijalankan setelah diizinkan. */
    private class TundaIzin(
        val volume: StorageVolume,
        val result: MethodChannel.Result,
        val lanjut: (Uri) -> Unit,
    )
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
                "simpanFlashdisk" -> {
                    val nama = call.argument<String>("nama")
                    val bytes = call.argument<ByteArray>("bytes")
                    val mime = call.argument<String>("mime") ?: "application/octet-stream"
                    if (nama == null || bytes == null) {
                        result.error("ARG", "Nama atau isi file kosong", null)
                    } else {
                        denganFlashdisk(result) { tree, volume ->
                            tulisFlashdisk(tree, volume, nama, bytes, mime)
                        }
                    }
                }
                "adaFlashdisk" -> result.success(flashdisk() != null)
                "daftarFlashdisk" -> {
                    val ekstensi = call.argument<List<String>>("ekstensi") ?: emptyList()
                    denganFlashdisk(result) { tree, _ -> daftarFlashdisk(tree, ekstensi) }
                }
                "bacaFlashdisk" -> {
                    val uri = call.argument<String>("uri")?.let { Uri.parse(it) }
                    if (uri == null) {
                        result.error("ARG", "File kosong", null)
                    } else {
                        Thread {
                            try {
                                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                                runOnUiThread {
                                    if (bytes == null) result.error("GAGAL", "Isi file tidak bisa dibaca", null)
                                    else result.success(bytes)
                                }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("GAGAL", e.message, null) }
                            }
                        }.start()
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

    // ---------------- FLASHDISK (USB OTG) ----------------

    /** Flashdisk yang tercolok (penyimpanan lepas-pasang), USB diutamakan. */
    private fun flashdisk(): StorageVolume? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return null
        val sm = getSystemService(STORAGE_SERVICE) as StorageManager
        val lepas = sm.storageVolumes.filter {
            it.isRemovable && it.uuid != null && it.state == Environment.MEDIA_MOUNTED
        }
        return lepas.firstOrNull { it.getDescription(this).contains("USB", ignoreCase = true) }
            ?: lepas.firstOrNull()
    }

    private fun milikVolume(tree: Uri, volume: StorageVolume): Boolean = try {
        DocumentsContract.getTreeDocumentId(tree).startsWith("${volume.uuid}:")
    } catch (e: Exception) {
        false
    }

    /** Izin tulis flashdisk yang sudah pernah diberikan (null = belum). */
    private fun izinFlashdisk(volume: StorageVolume): Uri? =
        contentResolver.persistedUriPermissions
            .firstOrNull { it.isWritePermission && milikVolume(it.uri, volume) }?.uri

    /**
     * Jalankan [kerja] (di thread lain) dengan izin flashdisk. Kalau izin belum
     * ada / sudah tidak berlaku (misal flashdisk diformat), layar izin dibuka
     * dulu (sekali). Hasil [kerja] dikirim ke Flutter; null = dibatalkan.
     */
    private fun denganFlashdisk(result: MethodChannel.Result, kerja: (Uri, StorageVolume) -> Any?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            result.error("TIDAK_DIDUKUNG", "Android < 7", null)
            return
        }
        if (tundaIzin != null) {
            result.error("SIBUK", "Layar izin flashdisk sedang terbuka", null)
            return
        }
        val volume = flashdisk()
        if (volume == null) {
            result.error("TIDAK_ADA", "Flashdisk tidak terdeteksi", null)
            return
        }

        fun jalankan(tree: Uri, bolehMintaUlang: Boolean) {
            Thread {
                try {
                    val hasil = kerja(tree, volume)
                    runOnUiThread { result.success(hasil) }
                } catch (e: SecurityException) {
                    runOnUiThread {
                        if (!bolehMintaUlang) {
                            result.error("GAGAL", e.message, null)
                        } else {
                            try {
                                contentResolver.releasePersistableUriPermission(
                                    tree,
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                                )
                            } catch (e2: Exception) {
                                // abaikan
                            }
                            mintaIzinFlashdisk(TundaIzin(volume, result) { jalankan(it, false) })
                        }
                    }
                } catch (e: Exception) {
                    runOnUiThread { result.error("GAGAL", e.message, null) }
                }
            }.start()
        }

        val izin = izinFlashdisk(volume)
        if (izin != null) {
            jalankan(izin, true)
        } else {
            mintaIzinFlashdisk(TundaIzin(volume, result) { jalankan(it, false) })
        }
    }

    /** Layar izin Android, langsung terbuka di akar flashdisk. */
    private fun mintaIzinFlashdisk(tunda: TundaIzin) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tunda.volume.createOpenDocumentTreeIntent()
        } else {
            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    putExtra(
                        DocumentsContract.EXTRA_INITIAL_URI,
                        DocumentsContract.buildDocumentUri(
                            "com.android.externalstorage.documents", "${tunda.volume.uuid}:"
                        )
                    )
                }
            }
        }
        intent.addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
        tundaIzin = tunda
        try {
            startActivityForResult(intent, kodeFlashdisk)
        } catch (e: Exception) {
            tundaIzin = null
            tunda.result.error("GAGAL", e.message, null)
        }
    }

    /** Tulis ke [tree]/LOGEVA/nama. Hasil: lokasi yang mudah dibaca. */
    private fun tulisFlashdisk(
        tree: Uri, volume: StorageVolume, nama: String, bytes: ByteArray, mime: String
    ): String {
        val resolver = contentResolver
        val akarId = DocumentsContract.getTreeDocumentId(tree)
        val akar = DocumentsContract.buildDocumentUriUsingTree(tree, akarId)
        val folder = cariFolder(tree, akarId, "LOGEVA")
            ?: DocumentsContract.createDocument(
                resolver, akar, DocumentsContract.Document.MIME_TYPE_DIR, "LOGEVA"
            )
            ?: throw IllegalStateException("Folder LOGEVA tidak bisa dibuat di flashdisk")
        val file = DocumentsContract.createDocument(resolver, folder, mime, nama)
            ?: throw IllegalStateException("File tidak bisa dibuat di flashdisk")
        resolver.openOutputStream(file)?.use { it.write(bytes) }
            ?: throw IllegalStateException("File di flashdisk tidak bisa dibuka")
        return "${volume.getDescription(this)}/LOGEVA/${namaFile(file) ?: nama}"
    }

    /**
     * File berakhiran [ekstensi] di folder utama flashdisk dan di setiap folder
     * tepat di bawahnya (misal LOGEVA/, Download/). Terbaru di atas.
     */
    private fun daftarFlashdisk(tree: Uri, ekstensi: List<String>): List<Map<String, Any>> {
        val hasil = mutableListOf<Map<String, Any>>()
        val akarId = DocumentsContract.getTreeDocumentId(tree)
        val kolom = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )

        fun baca(indukId: String, folder: String, turun: Boolean) {
            val anak = DocumentsContract.buildChildDocumentsUriUsingTree(tree, indukId)
            contentResolver.query(anak, kolom, null, null, null)?.use {
                while (it.moveToNext()) {
                    val id = it.getString(0) ?: continue
                    val nama = it.getString(1) ?: continue
                    if (nama.startsWith(".")) continue
                    if (it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                        if (turun) baca(id, nama, false)
                    } else if (ekstensi.isEmpty() || ekstensi.any { e -> nama.endsWith(e, ignoreCase = true) }) {
                        hasil.add(
                            mapOf(
                                "nama" to nama,
                                "folder" to folder,
                                "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                                "ukuran" to (if (it.isNull(3)) 0L else it.getLong(3)),
                                "waktu" to (if (it.isNull(4)) 0L else it.getLong(4)),
                            )
                        )
                    }
                }
            }
        }

        baca(akarId, "", true)
        return hasil.sortedByDescending { it["waktu"] as Long }
    }

    private fun cariFolder(tree: Uri, induk: String, nama: String): Uri? {
        val anak = DocumentsContract.buildChildDocumentsUriUsingTree(tree, induk)
        contentResolver.query(
            anak,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null, null, null
        )?.use {
            while (it.moveToNext()) {
                if (it.getString(1) == nama && it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                    return DocumentsContract.buildDocumentUriUsingTree(tree, it.getString(0))
                }
            }
        }
        return null
    }

    private fun hasilIzinFlashdisk(resultCode: Int, data: Intent?) {
        val tunda = tundaIzin ?: return
        tundaIzin = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            tunda.result.success(null) // dibatalkan
            return
        }
        if (!milikVolume(uri, tunda.volume)) {
            tunda.result.error("BUKAN_FLASHDISK", "Lokasi yang dipilih bukan flashdisk", null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (e: Exception) {
            // tetap bisa dipakai sekali ini
        }
        tunda.lanjut(uri)
    }

    @Deprecated("Dipakai untuk hasil pemilih file")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == kodeFlashdisk) {
            hasilIzinFlashdisk(resultCode, data)
            return
        }
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
