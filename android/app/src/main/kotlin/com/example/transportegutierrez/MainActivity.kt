package com.example.transportegutierrez

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.ClipData
import android.content.ActivityNotFoundException
import androidx.core.content.FileProvider
import java.io.File

class OrdenPdfProvider : FileProvider()

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "teg/whatsapp_pdf").setMethodCallHandler { call, result ->
            if (call.method != "abrirPdf") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val pdf = call.argument<ByteArray>("pdf")
            val name = call.argument<String>("nombre") ?: "orden.pdf"
            val text = call.argument<String>("mensaje") ?: ""
            if (pdf == null || pdf.size < 5 || pdf.size > 12 * 1024 * 1024 ||
                !name.matches(Regex("[A-Za-z0-9_-]+\\.pdf")) ||
                !pdf.copyOfRange(0,5).contentEquals("%PDF-".toByteArray())) {
                result.error("PDF_INVALIDO", "PDF o nombre de archivo no válido.", null)
                return@setMethodCallHandler
            }
            try {
                val folder = File(cacheDir, "ordenes_whatsapp").apply { mkdirs() }
                val file = File(folder, name)
                file.writeBytes(pdf)
                val uri = FileProvider.getUriForFile(this, "$packageName.ordenes_pdf", file)
                val base = Intent(Intent.ACTION_SEND).apply {
                    type = "application/pdf"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_TEXT, text)
                    clipData = ClipData.newRawUri("Orden de escolta", uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                // No enlace wa.me ni selector general: WhatsApp recibe el adjunto.
                val target = listOf("com.whatsapp", "com.whatsapp.w4b")
                    .map { Intent(base).setPackage(it) }
                    .firstOrNull { it.resolveActivity(packageManager) != null }
                if (target == null) {
                    result.error("WHATSAPP_NO_INSTALADO", "Instale WhatsApp o WhatsApp Business para abrir el PDF.", null)
                } else {
                    startActivity(target)
                    result.success(null) // Apertura, no comprobante de envío.
                }
            } catch (_: ActivityNotFoundException) {
                result.error("WHATSAPP_NO_DISPONIBLE", "No se pudo abrir WhatsApp.", null)
            } catch (_: Exception) {
                result.error("PDF_NO_DISPONIBLE", "No se pudo preparar el PDF para WhatsApp.", null)
            }
        }
    }
}
