package io.maestro.ui

import android.graphics.pdf.PdfRenderer
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import io.maestro.R
import io.maestro.utils.toastLong

class VisualizarDanfeActivity : AppCompatActivity() {

    private lateinit var pdfRenderer: PdfRenderer
    private var currentPage = 0
    private var pageCount = 0
    private lateinit var imageView: ImageView
    private lateinit var tvPageInfo: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_visualizar_danfe)

        val pdfPath = intent.getStringExtra("pdf_path")
        val pdfName = intent.getStringExtra("pdf_name") ?: "DANFE"

        imageView = findViewById(R.id.ivPdfPage)
        tvPageInfo = findViewById(R.id.tvPageInfo)

        findViewById<TextView>(R.id.tvTitle).text = pdfName

        findViewById<android.widget.ImageButton>(R.id.btnFechar).setOnClickListener { finish() }
        findViewById<android.widget.ImageButton>(R.id.btnAnterior).setOnClickListener { mostrarPagina(currentPage - 1) }
        findViewById<android.widget.ImageButton>(R.id.btnProximo).setOnClickListener { mostrarPagina(currentPage + 1) }
        findViewById<android.widget.Button>(R.id.btnImprimir).setOnClickListener { imprimir() }

        if (pdfPath != null) {
            abrirPdf(pdfPath)
        }
    }

    private fun abrirPdf(path: String) {
        try {
            val file = java.io.File(path)
            val fd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            pdfRenderer = PdfRenderer(fd)
            pageCount = pdfRenderer.pageCount
            mostrarPagina(0)
        } catch (e: Exception) {
            tvPageInfo.text = "Erro ao abrir PDF: ${e.message}"
        }
    }

    private fun mostrarPagina(index: Int) {
        if (index < 0 || index >= pageCount) return
        currentPage = index

        val page = pdfRenderer.openPage(index)
        val bitmap = android.graphics.Bitmap.createBitmap(
            page.width, page.height, android.graphics.Bitmap.Config.ARGB_8888
        )
        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
        imageView.setImageBitmap(bitmap)
        page.close()

        tvPageInfo.text = "Página ${index + 1} de $pageCount"
        findViewById<android.widget.ImageButton>(R.id.btnAnterior).isEnabled = index > 0
        findViewById<android.widget.ImageButton>(R.id.btnProximo).isEnabled = index < pageCount - 1
    }

    private fun imprimir() {
        try {
            val printHelper = androidx.print.PrintHelper(this)
            printHelper.setScaleMode(androidx.print.PrintHelper.SCALE_MODE_FIT)
            printHelper.setColorMode(androidx.print.PrintHelper.COLOR_MODE_COLOR)
            val path = intent.getStringExtra("pdf_path")
            if (path != null) {
                printHelper.printBitmap("DANFE", android.graphics.BitmapFactory.decodeFile(path))
            }
        } catch (e: Exception) {
            this.toastLong("Erro ao imprimir: ${e.message}")
        }
    }

    override fun onDestroy() {
        try { pdfRenderer.close() } catch (_: Exception) {}
        super.onDestroy()
    }
}