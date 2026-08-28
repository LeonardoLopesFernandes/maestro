package io.maestro.ui.scanner

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.View
import android.widget.ImageButton
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.maestro.R
import io.maestro.utils.toast
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class ScannerImeiActivity : AppCompatActivity() {

    companion object {
        const val RESULT_IMEI = "imei"
    }

    private lateinit var previewView: PreviewView
    private lateinit var btnFechar: ImageButton
    private lateinit var tvStatus: TextView
    private lateinit var cameraExecutor: ExecutorService
    private var processando = false

    private val cameraPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) {
                iniciarCamera()
            } else {
                toast(getString(R.string.scanner_imei_permissao))
                finish()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_scanner_imei)

        previewView = findViewById(R.id.previewScanner)
        btnFechar = findViewById(R.id.btnFecharScanner)
        tvStatus = findViewById(R.id.tvScannerStatus)

        btnFechar.setOnClickListener { finish() }
        cameraExecutor = Executors.newSingleThreadExecutor()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            iniciarCamera()
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    private fun iniciarCamera() {
        val providerFuture = androidx.camera.lifecycle.ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            val cameraProvider = providerFuture.get()

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()

            imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                processarBarcode(imageProxy)
            }

            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    imageAnalysis
                )
            } catch (e: Exception) {
                e.printStackTrace()
                toast(getString(R.string.scanner_imei_erro))
                finish()
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun processarBarcode(imageProxy: ImageProxy) {
        if (processando) {
            imageProxy.close()
            return
        }

        val mediaImage = imageProxy.image
        if (mediaImage != null) {
            val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
            val scanner = BarcodeScanning.getClient(
                BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(
                        Barcode.FORMAT_CODE_128,
                        Barcode.FORMAT_EAN_13,
                        Barcode.FORMAT_EAN_8,
                        Barcode.FORMAT_CODE_39,
                        Barcode.FORMAT_CODE_93,
                        Barcode.FORMAT_CODABAR,
                        Barcode.FORMAT_UPC_A,
                        Barcode.FORMAT_UPC_E,
                        Barcode.FORMAT_ITF
                    )
                    .build()
            )

            scanner.process(image)
                .addOnSuccessListener { barcodes ->
                    val imei = extrairImei(barcodes)
                    if (imei != null && !processando) {
                        processando = true
                        runOnUiThread {
                            setResult(RESULT_OK, android.content.Intent().putExtra(RESULT_IMEI, imei))
                            finish()
                        }
                    }
                }
                .addOnCompleteListener { imageProxy.close() }
        } else {
            imageProxy.close()
        }
    }

    private fun extrairImei(barcodes: List<Barcode>): String? {
        for (barcode in barcodes) {
            val raw = barcode.rawValue ?: barcode.displayValue ?: continue
            val digitado = raw.replace(Regex("[^0-9]"), "")
            if (digitado.length >= 15) {
                return digitado.take(15)
            }
        }
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }
}
