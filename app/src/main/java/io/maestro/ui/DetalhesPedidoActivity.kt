package io.maestro.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.content.res.ColorStateList
import android.graphics.PorterDuff
import android.graphics.drawable.GradientDrawable
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.*
import androidx.activity.viewModels
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.text.HtmlCompat
import android.widget.LinearLayout
import com.google.android.material.bottomsheet.BottomSheetDialog
import androidx.lifecycle.lifecycleScope
import io.maestro.BuildConfig
import io.maestro.R
import io.maestro.utils.toast
import io.maestro.utils.toastLong
import io.maestro.network.SessionManager
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import io.maestro.network.Motivo
import io.maestro.network.RecusaMotivo
import io.maestro.network.RecusaSubItem
import io.maestro.network.models.*
import io.maestro.ui.dialogs.ItemQuantidadeNovoDialog
import io.maestro.ui.dialogs.SmartphoneConfirmacaoDialog
import io.maestro.utils.Colors
import io.maestro.utils.Constants
import io.maestro.utils.RecaptchaManager
import java.text.SimpleDateFormat
import java.util.*

class DetalhesPedidoActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "DetalhesPedido"
    }

    private val viewModel: PedidoViewModel by viewModels()
    private var pedidoAtual: Pedido? = null
    private var tokenInsucessoAtual: String? = null
    private var confirmacaoEntregadorPending = false
    private var pollingConfirmacaoJob: kotlinx.coroutines.Job? = null
    private var btnConfirmarRetiradaDialog: TextView? = null

    // ============================================
    // VIEWS - HEADER
    // ============================================
    private lateinit var tvNumeroPedido: TextView
    private lateinit var tvStatus: TextView
    private lateinit var tvClienteBadge: TextView
    private lateinit var badgePedidoCliente: LinearLayout
    private var corResIdAtual: Int = R.color.btn_novo
    private lateinit var tvIdadePedido: TextView

    // ============================================
    // VIEWS - CLIENTE
    // ============================================
    private lateinit var tvClienteNome: TextView
    private lateinit var tvClienteCpf: TextView
    private lateinit var tvClienteEmail: TextView
    private lateinit var tvClienteTelefone: TextView
    private lateinit var tvClienteEndereco: TextView

    // ============================================
    // VIEWS - RESUMO
    // ============================================
    private lateinit var tvCanal: TextView
    private lateinit var tvTipoEntrega: TextView
    private lateinit var tvSubtotal: TextView
    private lateinit var tvDesconto: TextView
    private lateinit var tvValorEntrega: TextView
    private lateinit var tvValorTotal: TextView

    // ============================================
    // VIEWS - ITENS
    // ============================================
    private lateinit var layoutItensDetalhe: LinearLayout

    // ============================================
    // VIEWS - TIMELINE
    // ============================================
    private lateinit var timelineContainer: LinearLayout
    private lateinit var scrollTimeline: android.widget.HorizontalScrollView
    private lateinit var btnToggleTimeline: ImageButton
    private lateinit var tvTimelineLabel: TextView
    private var timelineExpandida = false

    // ============================================
    // VIEWS - TOKENS
    // ============================================
    private lateinit var tvTokenCliente: TextView
    private lateinit var tvTokenRetirada: TextView
    private lateinit var tvTokenInsucesso: TextView

    // ============================================
    // VIEWS - RECEBEDOR
    // ============================================
    private lateinit var tvRecebedorNome: TextView
    private lateinit var tvRecebedorDocumento: TextView

    // ============================================
    // VIEWS - INFO ADICIONAIS
    // ============================================
    private lateinit var layoutMotivosBadges: LinearLayout
    private lateinit var layoutMotivoCancelamento: View
    private lateinit var tvTempoConfirmacaoHeader: TextView
    private lateinit var layoutDuracaoDetalhe: LinearLayout
    private lateinit var viewBarraProgressoDetalhe: View
    private var tickJob: kotlinx.coroutines.Job? = null

    // ============================================
    // VIEWS - LOADING E CONTEUDO
    // ============================================
    private lateinit var layoutLoading: View
    private lateinit var layoutConteudo: View
    private lateinit var scrollViewContent: ScrollView
    private lateinit var badgeCentered: TextView
    private lateinit var badgeCancelarRetirada: TextView
    private lateinit var fabScannerImei: com.google.android.material.floatingactionbutton.FloatingActionButton
    private var smartphoneConfirmacaoDialog: SmartphoneConfirmacaoDialog? = null
    private var itemQuantidadeNovoDialog: ItemQuantidadeNovoDialog? = null

    private val scannerImeiLauncher =
        registerForActivityResult(androidx.activity.result.contract.ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode == RESULT_OK) {
                val imei = result.data?.getStringExtra(io.maestro.ui.scanner.ScannerImeiActivity.RESULT_IMEI)
                if (!imei.isNullOrEmpty()) {
                    smartphoneConfirmacaoDialog?.preencherImeiEscaneado(imei)
                }
            }
        }
    private var badgePending = false
    private var badgeCancelPending = false

    // ============================================
    // FUNÇÕES DE SEGURANÇA
    // ============================================
    private fun logDebug(msg: String) {
        if (BuildConfig.DEBUG) Log.d(TAG, msg)
    }

    private fun logError(msg: String, e: Throwable? = null) {
        if (BuildConfig.DEBUG) {
            if (e != null) Log.e(TAG, msg, e) else Log.e(TAG, msg)
        }
    }

    private fun toStringSafe(value: Any?): String = value?.toString() ?: ""
    private fun toDoubleSafe(value: Any?): Double = when (value) {
        is Number -> value.toDouble()
        is String -> value.toDoubleOrNull() ?: 0.0
        else -> 0.0
    }
    private fun toIntSafe(value: Any?): Int = when (value) {
        is Number -> value.toInt()
        is String -> value.toIntOrNull() ?: 0
        else -> 0
    }

    private fun toListTimeline(value: Any?): List<Timeline> {
        return try {
            when (value) {
                is List<*> -> value.filterIsInstance<Timeline>()
                else -> emptyList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao converter timeline", e)
            emptyList()
        }
    }

    private fun toListItem(value: Any?): List<Item> {
        return try {
            when (value) {
                is List<*> -> value.filterIsInstance<Item>()
                else -> emptyList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao converter itens", e)
            emptyList()
        }
    }

    // ============================================
    // FUNÇÕES DE EXTENSÃO PARA PEDIDO
    // ============================================
    private fun Pedido.getValorTotalFormatado(): String {
        return "R$ ${String.format("%.2f", valorTotal ?: 0.0)}"
    }

    private fun Pedido.getValorSubtotalFormatado(): String {
        return "R$ ${String.format("%.2f", valorSubtotal ?: 0.0)}"
    }

    private fun Pedido.getValorDescontoFormatado(): String {
        return "R$ ${String.format("%.2f", valorDesconto ?: 0.0)}"
    }

    private fun Pedido.getValorEntregaFormatado(): String {
        return "R$ ${String.format("%.2f", valorEntrega ?: 0.0)}"
    }

    private fun Pedido.getClienteNome(): String {
        return cliente?.nome ?: "N/A"
    }

    private fun Pedido.getClienteDocumento(): String {
        return cliente?.cpf?.takeIf { it.isNotBlank() }
            ?: cliente?.cnpj?.takeIf { it.isNotBlank() }
            ?: "N/A"
    }

    private fun Pedido.getClienteEmail(): String {
        return cliente?.email ?: "N/A"
    }

    private fun Pedido.getClienteTelefone(): String {
        val raw = cliente?.telefone ?: return "N/A"
        val digits = raw.replace(Regex("[^0-9]"), "")
        return when (digits.length) {
            11 -> "(${digits.substring(0,2)}) ${digits[2]}.${digits.substring(3,7)}-${digits.substring(7)}"
            10 -> "(${digits.substring(0,2)}) ${digits.substring(2,6)}-${digits.substring(6)}"
            else -> raw
        }
    }

    private fun Pedido.getClienteEnderecoCompleto(): String {
        val c = cliente ?: return "Endereço não informado"
        return buildString {
            append(c.endereco ?: "")
            if (!c.numero.isNullOrEmpty()) append(", ${c.numero}")
            if (!c.complemento.isNullOrEmpty()) append(" - ${c.complemento}")
            if (!c.bairro.isNullOrEmpty()) append(" - ${c.bairro}")
            if (!c.city.isNullOrEmpty()) append(" - ${c.city}")
            if (!c.uf.isNullOrEmpty()) append("/${c.uf}")
            if (!c.cep.isNullOrEmpty()) append(" - CEP: ${c.cep}")
        }.ifEmpty { "Endereço não informado" }
    }

    private fun Pedido.getItens(): List<Item> {
        return itens ?: emptyList()
    }

    private fun Pedido.podeDevolver(): Boolean {
        return status == "RETORNAR_PARA_ESTOQUE"
    }

    // ============================================
    // CICLO DE VIDA
    // ============================================

    override fun onStop() {
        super.onStop()
        removerTimerDetalhe()
        pararSkeletonPulse()
        pollingConfirmacaoJob?.cancel()
        pollingConfirmacaoJob = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_detalhes_pedido)
        Log.d(TAG, "=== onCreate INICIADO ===")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
            window.statusBarColor = ContextCompat.getColor(this, R.color.white)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            }
        }

        if (!viewModel.isLoggedIn()) {
            Log.e(TAG, "Usuário não logado")
            redirectToLogin()
            return
        }

        initViews()
        setupListeners()

        val pedido = intent.getSerializableExtra("PEDIDO") as? Pedido

        if (pedido != null) {
            Log.d(TAG, "✅ Pedido recebido via Intent: ${pedido.numero} - ${pedido.codigoExterno}")
            pedidoAtual = pedido
            val corResId = if (intent.hasExtra("COR_ABA")) {
                intent.getIntExtra("COR_ABA", R.color.btn_novo)
            } else {
                corBadgeParaStatus(pedido.status)
            }
            corResIdAtual = corResId
            aplicarCorBadge(corResId)
            exibirDetalhes(pedido)
            Log.d(TAG, "Itens no Intent: ${pedido.itens?.size}")

            // Buscar dados completos do pedido da API
            val pedidoNumero = intent.getStringExtra("PEDIDO_NUMERO") ?: pedido.numero.takeIf { it.isNotBlank() }
            if (pedidoNumero != null) {
                viewModel.getPedidoById(pedidoNumero) { pedidoApi ->
                    if (pedidoApi != null && pedidoApi.itens != null) {
                        Log.d(TAG, "API items: ${pedidoApi.itens?.size}")
                        pedidoAtual = pedidoApi
                        exibirDetalhes(pedidoApi)
                    } else if (pedidoApi != null) {
                        // API sem itens: preservar itens do pedido recebido e mesclar deliveryToken/status da API
                        Log.w(TAG, "API sem itens, mesclando deliveryToken")
                        val itensLocal = pedido.itens ?: run {
                            try {
                                val itensJson = SessionManager(this).getPedidoItens(toStringSafe(pedido.numero))
                                if (itensJson != null) {
                                    val salvos: Array<Item> = com.google.gson.Gson().fromJson(itensJson, Array<Item>::class.java)
                                    salvos.toList().ifEmpty { null }
                                } else null
                            } catch (e: Exception) {
                                Log.w(TAG, "Erro ao carregar itens salvos", e)
                                null
                            }
                        }
                        pedidoAtual = pedido.copy(
                            itens = itensLocal,
                            deliveryToken = pedidoApi.deliveryToken ?: pedido.deliveryToken,
                            status = pedidoApi.status ?: pedido.status,
                            codigoExterno = pedidoApi.codigoExterno ?: pedido.codigoExterno
                        )
                        exibirDetalhes(pedidoAtual!!)
                    } else {
                        Log.w(TAG, "API null, tentando local storage")
                        // Fallback: itens salvos localmente
                        try {
                            val itensJson = SessionManager(this).getPedidoItens(toStringSafe(pedido.numero))
                            if (itensJson != null) {
                                val itensSalvos: Array<Item> = com.google.gson.Gson().fromJson(itensJson, Array<Item>::class.java)
                                if (itensSalvos.isNotEmpty()) {
                                    pedidoAtual = pedido.copy(itens = itensSalvos.toList())
                                    exibirDetalhes(pedidoAtual!!)
                                }
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Erro ao carregar itens salvos", e)
                        }
                    }
                }
            }
        } else {
            Log.e(TAG, "❌ Nenhum pedido encontrado na Intent")
            this.toast("Pedido não encontrado")
            finish()
        }
    }

    // ============================================
    // INICIALIZAÇÃO DAS VIEWS
    // ============================================

    private fun initViews() {
        tvNumeroPedido = findViewById(R.id.tvNumeroPedido)
        tvIdadePedido = findViewById(R.id.tvIdadePedido)
        tvStatus = findViewById(R.id.tvStatus)
        tvClienteBadge = findViewById(R.id.tvClienteBadge)
        badgePedidoCliente = findViewById(R.id.badgePedidoCliente)

        tvClienteNome = findViewById(R.id.tvClienteNome)
        tvClienteCpf = findViewById(R.id.tvClienteCpf)
        tvClienteEmail = findViewById(R.id.tvClienteEmail)
        tvClienteTelefone = findViewById(R.id.tvClienteTelefone)
        tvClienteEndereco = findViewById(R.id.tvClienteEndereco)

        tvCanal = findViewById(R.id.tvCanal)
        tvTipoEntrega = findViewById(R.id.tvTipoEntrega)
        tvSubtotal = findViewById(R.id.tvSubtotal)
        tvDesconto = findViewById(R.id.tvDesconto)
        tvValorEntrega = findViewById(R.id.tvValorEntrega)
        tvValorTotal = findViewById(R.id.tvValorTotal)

        layoutItensDetalhe = findViewById(R.id.layoutItensDetalhe)
        timelineContainer = findViewById(R.id.timelineContainer)
        scrollTimeline = findViewById(R.id.scrollTimeline)
        btnToggleTimeline = findViewById(R.id.btnToggleTimeline)
        tvTimelineLabel = findViewById(R.id.tvTimelineLabel)

        btnToggleTimeline.setOnClickListener {
            toggleTimeline()
        }
        tvTimelineLabel.setOnClickListener {
            toggleTimeline()
        }

        tvTokenCliente = findViewById(R.id.tvTokenCliente)
        tvTokenRetirada = findViewById(R.id.tvTokenRetirada)
        tvTokenInsucesso = findViewById(R.id.tvTokenInsucesso)

        tvRecebedorNome = findViewById(R.id.tvRecebedorNome)
        tvRecebedorDocumento = findViewById(R.id.tvRecebedorDocumento)

        tvTempoConfirmacaoHeader = findViewById(R.id.tvTempoConfirmacaoHeader)
        layoutDuracaoDetalhe = findViewById(R.id.layoutDuracaoDetalhe)
        viewBarraProgressoDetalhe = findViewById(R.id.viewBarraProgressoDetalhe)
        layoutMotivosBadges = findViewById(R.id.layoutMotivosBadges)
        layoutMotivoCancelamento = findViewById(R.id.layoutMotivoCancelamento)

        layoutLoading = findViewById(R.id.layoutLoading)
        layoutConteudo = findViewById(R.id.layoutConteudo)
        scrollViewContent = findViewById(R.id.scrollViewContent)
        badgeCentered = findViewById(R.id.badgeCentered)
        badgeCancelarRetirada = findViewById(R.id.badgeCancelarRetirada)
        fabScannerImei = findViewById(R.id.fabScannerImei)

        // FAB Scanner IMEI (só aparece em confirmação de smartphone)
        fabScannerImei.setOnClickListener { abrirScannerImei() }

        // Forçar cores
        tvStatus.setTextColor(ContextCompat.getColor(this, R.color.green_dark))

        tvClienteNome.setTextColor(ContextCompat.getColor(this, R.color.black_text))
        tvClienteCpf.setTextColor(ContextCompat.getColor(this, R.color.gray_medium))
        tvClienteEmail.setTextColor(ContextCompat.getColor(this, R.color.gray_medium))
        tvClienteTelefone.setTextColor(ContextCompat.getColor(this, R.color.gray_medium))
        tvClienteEndereco.setTextColor(ContextCompat.getColor(this, R.color.gray_medium))

        tvCanal.setTextColor(ContextCompat.getColor(this, R.color.white))
        tvTipoEntrega.setTextColor(ContextCompat.getColor(this, R.color.white))
        tvSubtotal.setTextColor(ContextCompat.getColor(this, R.color.black_text))
        tvDesconto.setTextColor(ContextCompat.getColor(this, R.color.green_dark))
        tvValorEntrega.setTextColor(ContextCompat.getColor(this, R.color.black_text))
        tvValorTotal.setTextColor(ContextCompat.getColor(this, R.color.verde))
    }

    private fun toggleTimeline() {
        if (timelineExpandida) {
            recolherTimeline()
        } else {
            expandirTimeline()
        }
    }

    private fun expandirTimeline() {
        timelineExpandida = true
        scrollTimeline.visibility = android.view.View.VISIBLE
        btnToggleTimeline.setImageResource(R.drawable.ic_arrow_up)
        btnToggleTimeline.contentDescription = "Recolher timeline"
    }

    private fun recolherTimeline() {
        timelineExpandida = false
        scrollTimeline.visibility = android.view.View.GONE
        btnToggleTimeline.setImageResource(R.drawable.ic_arrow_down)
        btnToggleTimeline.contentDescription = "Expandir timeline"
    }

    private fun setupListeners() {
        scrollViewContent.setOnScrollChangeListener { _, _, scrollY, _, oldScrollY ->
            val view = scrollViewContent.getChildAt(0)
            if (view != null) {
                val diff = view.bottom - (scrollViewContent.height + scrollY)
                if (diff <= 0 && badgePending) {
                    if (badgeCentered.visibility != View.VISIBLE) {
                        badgeCentered.alpha = 0f
                        badgeCentered.visibility = View.VISIBLE
                        badgeCentered.animate().alpha(1f).setDuration(200).start()
                    }
                    if (badgeCancelPending && badgeCancelarRetirada.visibility != View.VISIBLE) {
                        badgeCancelarRetirada.alpha = 0f
                        badgeCancelarRetirada.visibility = View.VISIBLE
                        badgeCancelarRetirada.animate().alpha(1f).setDuration(200).start()
                    }
                } else {
                    if (badgeCentered.visibility == View.VISIBLE) {
                        badgeCentered.animate().cancel()
                        badgeCentered.visibility = View.GONE
                    }
                    if (badgeCancelarRetirada.visibility == View.VISIBLE) {
                        badgeCancelarRetirada.animate().cancel()
                        badgeCancelarRetirada.visibility = View.GONE
                    }
                }
            }
        }
    }

    // ============================================
    // EXIBIR DETALHES - COM IMEIS
    // ============================================

    private fun ajustarTamanhoBadge(view: TextView, texto: String) {
        view.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 12f)
    }

    private fun corBadgeParaStatus(status: String?): Int {
        return when (status?.uppercase()) {
            "NOVO_PEDIDO", "NOVO" -> R.color.btn_novo
            "EM_SEPARACAO", "SEPARACAO", "EDITADO" -> R.color.btn_separacao
            "PRONTO_PARA_SAIR", "PRONTO" -> R.color.btn_pronto
            "SAIU_PARA_ENTREGA" -> R.color.btn_entrega
            "RETORNAR_ESTOQUE", "CANCELADO", "DEVOLVIDO" -> R.color.btn_estoque
            else -> R.color.btn_historico
        }
    }

    private fun aplicarCorBadge(corResId: Int) {
        val raio = android.util.TypedValue.applyDimension(
            android.util.TypedValue.COMPLEX_UNIT_DIP, 8f, resources.displayMetrics
        )
        badgePedidoCliente.background = android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.RECTANGLE
            setColor(androidx.core.content.ContextCompat.getColor(this@DetalhesPedidoActivity, corResId))
            cornerRadius = raio
        }
    }

    private fun exibirDetalhes(pedido: Pedido) {
        try {
            aplicarCorBadge(corResIdAtual)
            Log.d(TAG, "=== EXIBINDO DETALHES ===")
            Log.d(TAG, "Pedido: ${pedido.numero}")
            Log.d(TAG, "Cliente: ${pedido.cliente?.nome}")
            Log.d(TAG, "Itens: ${pedido.itens?.size}")

            tvNumeroPedido.text = toStringSafe(pedido.codigoExterno)
            tvStatus.text = formatStatus(toStringSafe(pedido.status))
            tvStatus.visibility = android.view.View.VISIBLE

            when (toStringSafe(pedido.status)) {
                "PRONTO_PARA_SAIR", "PRONTO" -> {
                    tvStatus.background = ContextCompat.getDrawable(this, R.drawable.bg_badge_orange)
                    tvStatus.setTextColor(ContextCompat.getColor(this, R.color.white))
                    tvStatus.text = "Pronto para Retirada"
                }
                "SAIU_PARA_ENTREGA" -> {
                    tvStatus.background = ContextCompat.getDrawable(this, R.drawable.bg_badge_purple)
                    tvStatus.setTextColor(ContextCompat.getColor(this, R.color.white))
                    tvStatus.text = "Saiu Para Entrega"
                }
                "FINALIZADO", "ENTREGUE" -> {
                    tvStatus.background = ContextCompat.getDrawable(this, R.drawable.bg_badge_green)
                    tvStatus.setTextColor(ContextCompat.getColor(this, R.color.white))
                    tvStatus.text = "Entregue"
                }
                "CANCELADO" -> {
                    tvStatus.background = ContextCompat.getDrawable(this, R.drawable.bg_badge_red)
                    tvStatus.setTextColor(ContextCompat.getColor(this, R.color.white))
                    tvStatus.text = "Cancelado"
                }
                "DEVOLVIDO" -> {
                    tvStatus.background = ContextCompat.getDrawable(this, R.drawable.bg_badge_red)
                    tvStatus.setTextColor(ContextCompat.getColor(this, R.color.white))
                    tvStatus.text = "Devolvido"
                }
                "RETORNAR_PARA_ESTOQUE" -> {
                    tvStatus.background = ContextCompat.getDrawable(this, R.drawable.bg_badge_red)
                    tvStatus.setTextColor(ContextCompat.getColor(this, R.color.white))
                    tvStatus.text = "DEVOLVER PARA O ESTOQUE"
                }
                "NOVO_PEDIDO", "NOVO" -> {
                    tvStatus.background = ContextCompat.getDrawable(this, R.drawable.bg_badge_green)
                    tvStatus.setTextColor(ContextCompat.getColor(this, R.color.white))
                    tvStatus.text = "NOVO"
                }
                "EM_SEPARACAO" -> {
                    tvStatus.background = ContextCompat.getDrawable(this, R.drawable.bg_badge_green)
                    tvStatus.setTextColor(ContextCompat.getColor(this, R.color.white))
                    tvStatus.text = "Em Separação"
                }
                "EDITADO" -> {
                    tvStatus.background = ContextCompat.getDrawable(this, R.drawable.bg_badge_green)
                    tvStatus.setTextColor(ContextCompat.getColor(this, R.color.white))
                    tvStatus.text = "Editado"
                }
                else -> {
                    tvStatus.background = null
                    tvStatus.setTextColor(android.graphics.Color.parseColor(Colors.GRAY_700))
                }
            }
            ajustarTamanhoBadge(tvStatus, tvStatus.text.toString())

            tvClienteNome.text = pedido.getClienteNome()
            tvClienteBadge.text = pedido.getClienteNome()
            tvClienteBadge.setTextSize(
                android.util.TypedValue.COMPLEX_UNIT_SP,
                if (pedido.getClienteNome().length > 40) 12f else 14f
            )
            tvClienteCpf.text = "CPF / CNPJ: ${formatarDocumento(pedido.getClienteDocumento())}"
            tvClienteEmail.text = pedido.getClienteEmail()
            tvClienteTelefone.text = pedido.getClienteTelefone()
            tvClienteEndereco.text = pedido.getClienteEnderecoCompleto()

            findViewById<ImageView>(R.id.btnLigarCliente).setOnClickListener {
                val telefone = pedido.getClienteTelefone()
                if (telefone.isNullOrBlank()) {
                    toast("Cliente sem telefone cadastrado")
                } else {
                    val numero = telefone.replace(Regex("[^0-9+]"), "")
                    try {
                        startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$numero")))
                    } catch (e: Exception) {
                        toast("Não foi possível abrir o discador")
                    }
                }
            }

            val canal = toStringSafe(pedido.canalDeVendas)
            if (canal.isNotEmpty()) {
                tvCanal.text = when {
                    canal.equals("EXTERNA", ignoreCase = true) -> "Delivery"
                    canal.equals("Americanas Externa", ignoreCase = true) -> "Americanas Delivery"
                    else -> canal
                }
                ajustarTamanhoBadge(tvCanal, tvCanal.text.toString())
                tvCanal.setBackgroundResource(
                    if (canal.contains("Magazine", ignoreCase = true)) R.drawable.bg_badge_blue
                    else R.drawable.bg_badge_red
                )
                tvCanal.visibility = View.VISIBLE
            } else {
                tvCanal.visibility = View.GONE
            }

            val tipoEntrega = toStringSafe(pedido.tipoEntrega)
            if (tipoEntrega.isNotEmpty()) {
                tvTipoEntrega.text = when {
                    tipoEntrega.uppercase() == "RETIRADA" && canal.equals("Americanas", ignoreCase = true) -> "Pegue na Loja Hoje"
                    tipoEntrega.uppercase() == "RETIRADA" -> "Pegue na Loja Hoje"
                    tipoEntrega.uppercase() == "EXTERNA" && (canal.equals("Ifood", ignoreCase = true) || canal.equals("Americanas", ignoreCase = true) || canal.equals("Americanas Externa", ignoreCase = true)) -> "Delivery"
                    tipoEntrega.uppercase() == "EXTERNA" -> "Delivery"
                    else -> tipoEntrega
                }
                ajustarTamanhoBadge(tvTipoEntrega, tvTipoEntrega.text.toString())
                tvTipoEntrega.setBackgroundResource(R.drawable.bg_badge_wine)
                tvTipoEntrega.visibility = View.VISIBLE
            } else {
                tvTipoEntrega.visibility = View.GONE
            }

            pedido.recebedor?.let { recebedor ->
                tvRecebedorNome.text = recebedor.nome ?: "-"
                tvRecebedorDocumento.text = "Documento: ${formatarDocumento(recebedor.documento ?: "-")}"
            }

            val statusPedido = toStringSafe(pedido.status)
            if (statusPedido == "NOVO_PEDIDO" || statusPedido == "EM_SEPARACAO") {
                val tempo = pedido.tempoConfirmacao
                if (tempo != null) {
                    iniciarTimerDetalhe(tempo)
                } else {
                    tvTempoConfirmacaoHeader.text = ""
                    layoutDuracaoDetalhe.visibility = View.GONE
                }
            } else {
                removerTimerDetalhe()
                tvTempoConfirmacaoHeader.text = ""
                layoutDuracaoDetalhe.visibility = View.GONE
            }

            // ============================================
            // EXIBIR MOTIVO DE CANCELAMENTO/DEVOLUÇÃO - CORRIGIDO
            // ============================================
            val motivos = pedido.motivo
            layoutMotivosBadges.removeAllViews()
            if (!motivos.isNullOrEmpty()) {
                for (motivo in motivos) {
                    val texto = motivo.texto
                    if (texto.isNullOrBlank()) continue
                    val badge = TextView(this).apply {
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            bottomMargin = 6
                        }
                        text = texto
                        setTextColor(android.graphics.Color.parseColor(Colors.RED_600))
                        textSize = 14f
                        setTypeface(null, android.graphics.Typeface.BOLD)
                    }
                    layoutMotivosBadges.addView(badge)
                }
                layoutMotivoCancelamento.visibility = View.VISIBLE
            } else if (pedido.status == "CANCELADO" || pedido.status == "DEVOLVIDO") {
                val origem = if (pedido.status == "CANCELADO") "Cancelado" else "Devolvido"
                val badge = TextView(this).apply {
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    )
                    text = "$origem sem motivo informado"
                    setTextColor(android.graphics.Color.parseColor(Colors.RED_600))
                    textSize = 14f
                    setTypeface(null, android.graphics.Typeface.BOLD)
                }
                layoutMotivosBadges.addView(badge)
                layoutMotivoCancelamento.visibility = View.VISIBLE
            } else {
                layoutMotivoCancelamento.visibility = View.GONE
            }

            tvSubtotal.text = pedido.getValorSubtotalFormatado()
            tvDesconto.text = "- ${pedido.getValorDescontoFormatado()}"
            tvValorEntrega.text = "+ ${pedido.getValorEntregaFormatado()}"
            tvValorTotal.text = pedido.getValorTotalFormatado()

            // ============================================
            // EXIBIR ITENS (diretamente, sem RecyclerView)
            // ============================================
            layoutItensDetalhe.removeAllViews()
            val itensList = pedido.getItens()
            if (itensList.isNotEmpty()) {
                val status = pedido.status
                for (i in itensList.indices) {
                    val item = itensList[i]
                    val itemView = LayoutInflater.from(this).inflate(R.layout.item_detalhe_item, layoutItensDetalhe, false)
                    val tvQuantidade = itemView.findViewById<TextView>(R.id.tvQuantidade)
                    val tvDescricao = itemView.findViewById<TextView>(R.id.tvDescricao)
                    val tvCodigo = itemView.findViewById<TextView>(R.id.tvCodigo)
                    val tvValorTotal = itemView.findViewById<TextView>(R.id.tvValorTotal)
                    val tvValorUnitario = itemView.findViewById<TextView>(R.id.tvValorUnitario)
                    val tvImeis = itemView.findViewById<TextView>(R.id.tvImeis)
                    val tvImeisLabel = itemView.findViewById<TextView>(R.id.tvImeisLabel)
                    val layoutImeis = itemView.findViewById<View>(R.id.layoutImeis)
                    val tvEstoqueBadge = itemView.findViewById<TextView>(R.id.tvEstoqueBadge)
                    val layoutEstoqueBadge = itemView.findViewById<View>(R.id.layoutEstoqueBadge)
                    val divider = itemView.findViewById<View>(R.id.dividerItem)
                    val layoutCodigo = itemView.findViewById<LinearLayout>(R.id.layoutCodigo)
                    val btnToggleEans = itemView.findViewById<ImageButton>(R.id.btnToggleEans)
                    val layoutEansExtras = itemView.findViewById<LinearLayout>(R.id.layoutEansExtras)

                    val qtd = item.quantidadeTotal ?: item.quantidade
                    tvQuantidade.text = "${qtd}x"
                    tvDescricao.text = item.descricao ?: "Produto sem descrição"

                    val ean = item.codigoEAN ?: "---"
                    val sap = item.codigoSAP ?: "---"
                    tvCodigo.text = "EAN: $ean / SAP: $sap"

                    val eansExtras = item.eans?.filter { it != item.codigoEAN }?.distinct() ?: emptyList()
                    if (eansExtras.isNotEmpty()) {
                        btnToggleEans.visibility = View.VISIBLE
                        layoutEansExtras.removeAllViews()
                        for (eanExtra in eansExtras) {
                            val tvEan = TextView(this).apply {
                                layoutParams = LinearLayout.LayoutParams(
                                    LinearLayout.LayoutParams.WRAP_CONTENT,
                                    LinearLayout.LayoutParams.WRAP_CONTENT
                                )
                                text = "EAN: $eanExtra"
                                textSize = 11f
                                setTextColor(android.graphics.Color.parseColor("#888888"))
                            }
                            layoutEansExtras.addView(tvEan)
                        }
                        var expandido = false
                        val alternar = {
                            expandido = !expandido
                            layoutEansExtras.visibility = if (expandido) View.VISIBLE else View.GONE
                            btnToggleEans.setImageResource(if (expandido) R.drawable.ic_arrow_up else R.drawable.ic_arrow_down)
                        }
                        btnToggleEans.setOnClickListener { alternar() }
                        layoutCodigo.setOnClickListener { alternar() }
                    } else {
                        btnToggleEans.visibility = View.GONE
                        layoutEansExtras.visibility = View.GONE
                    }

                    val valorUnitario = item.valorUnitario ?: 0.0
                    tvValorTotal.text = String.format("R$ %.2f", valorUnitario * qtd)
                    tvValorUnitario.text = "${qtd}x R$ ${String.format("%.2f", valorUnitario).replace(".", ",")}"

                    val imeis = item.imeis
                    if (!imeis.isNullOrEmpty() && (item.quantidadeImeis ?: 0) > 0) {
                        tvImeisLabel.text = "IMEI(s) do item ${item.quantidadeImeis}:"
                        tvImeis.text = imeis.flatten().joinToString(separator = "\n")
                        tvImeis.visibility = View.VISIBLE
                        layoutImeis.visibility = View.VISIBLE
                        tvImeisLabel.visibility = View.VISIBLE
                    } else {
                        tvImeis.visibility = View.GONE
                        layoutImeis.visibility = View.GONE
                        tvImeisLabel.visibility = View.GONE
                    }

                    val estoque = item.estoque
                    val st = status?.uppercase()?.trim()
                    if (estoque != null && st in listOf("NOVO_PEDIDO", "NOVO", "EM_SEPARACAO", "SEPARACAO", "PRONTO_PARA_SAIR", "PRONTO")) {
                        tvEstoqueBadge.text = "Estoque estimado: $estoque"
                        layoutEstoqueBadge.visibility = View.VISIBLE
                    } else {
                        layoutEstoqueBadge.visibility = View.GONE
                    }

                    divider.visibility = if (i == itensList.size - 1) View.GONE else View.VISIBLE

                    if (qtd == 0) {
                        val vermelho = android.graphics.Color.parseColor("#DC2626")
                        tvQuantidade.setTextColor(vermelho)
                        tvDescricao.setTextColor(vermelho)
                        tvCodigo.setTextColor(vermelho)
                        tvValorTotal.setTextColor(vermelho)
                        tvValorUnitario.setTextColor(vermelho)
                    } else {
                        tvQuantidade.setTextColor(android.graphics.Color.parseColor("#2B2B2B"))
                        tvDescricao.setTextColor(android.graphics.Color.parseColor("#4A4A4A"))
                        tvCodigo.setTextColor(android.graphics.Color.parseColor("#888888"))
                        tvValorTotal.setTextColor(android.graphics.Color.parseColor("#2B2B2B"))
                        tvValorUnitario.setTextColor(android.graphics.Color.parseColor("#555555"))
                    }

                    layoutItensDetalhe.addView(itemView)
                }
                layoutItensDetalhe.visibility = View.VISIBLE
            } else {
                layoutItensDetalhe.visibility = View.GONE
            }

            try {
                val timelinesList = toListTimeline(pedido.timelines)
                if (timelinesList.isNotEmpty()) {
                    timelineContainer.removeAllViews()
                    var previousDate: Date? = null
                    for (i in timelinesList.indices) {
                        val view = LayoutInflater.from(this).inflate(R.layout.item_timeline_horizontal, timelineContainer, false)
                        val ivIcon = view.findViewById<ImageView>(R.id.ivTimelineIcon)
                        val iconWrapper = view.findViewById<FrameLayout>(R.id.iconWrapper)
                        val tvNome = view.findViewById<TextView>(R.id.tvTimelineNome)
                        val tvData = view.findViewById<TextView>(R.id.tvTimelineData)
                        val tvDuracao = view.findViewById<TextView>(R.id.tvTimelineDuracao)
                        val timeline = timelinesList[i]
                        val (displayNome, iconRes, borderColor) = getTimelineStepStyle(timeline.nome)
                        tvNome.text = displayNome
                        tvData.text = formatarDataHora(timeline.data ?: "")
                        ivIcon.setImageResource(iconRes)
                        if (timeline.nome?.uppercase()?.trim() == "EDITADO") {
                            ivIcon.colorFilter = null
                        } else {
                            ivIcon.setColorFilter(borderColor, PorterDuff.Mode.SRC_IN)
                        }
                        val currentDate = parseIsoDate(timeline.data)
                        if (previousDate != null && currentDate != null) {
                            val diffMs = currentDate.time - previousDate.time
                            tvDuracao.text = "Duração: ${formatarDuracao(diffMs)}"
                            tvDuracao.setTextColor(
                                if (diffMs > 30 * 60 * 1000L) android.graphics.Color.parseColor(Colors.RED_600)
                                else android.graphics.Color.parseColor(Colors.GRAY_200)
                            )
                        } else {
                            tvDuracao.text = "Duração: 0s"
                            tvDuracao.setTextColor(android.graphics.Color.parseColor(Colors.GRAY_200))
                        }
                        if (currentDate != null) {
                            previousDate = currentDate
                        }
                        timelineContainer.addView(view)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao carregar timeline", e)
            }

            try {
                val timelinesList = toListTimeline(pedido.timelines)
                if (timelinesList.size >= 2) {
                    val firstDate = parseIsoDate(timelinesList.first().data)
                    val lastDate = parseIsoDate(timelinesList.last().data)
                    if (firstDate != null && lastDate != null) {
                        tvIdadePedido.text = "Tempo total: " + formatarDuracao(lastDate.time - firstDate.time)
                        tvIdadePedido.visibility = android.view.View.VISIBLE
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao calcular idade do pedido", e)
            }

// ============================================
// EXIBIR TOKENS - CORRIGIDO
// ============================================
            fun tokenHtml(label: String, valor: String?): android.text.Spanned {
                val v = valor ?: "--"
                return if (v == "--") {
                    HtmlCompat.fromHtml("<b>$label</b>: <font color='#888888'>--</font>", HtmlCompat.FROM_HTML_MODE_LEGACY)
                } else {
                    HtmlCompat.fromHtml("<b>$label</b>: <b><font color='#000000'>$v</font></b>", HtmlCompat.FROM_HTML_MODE_LEGACY)
                }
            }
            pedido.deliveryToken?.let { token ->
                tvTokenCliente.text = tokenHtml("Token Cliente", token.tokenCliente)
                tvTokenRetirada.text = tokenHtml("Token Retirada", token.tokenRetirada)
                tvTokenInsucesso.text = tokenHtml("Token Insucesso", token.tokenInsucesso)
            }

            val storedToken = viewModel.getDeliveryToken(pedido.numero)
            if (storedToken != null) {
                if (pedido.deliveryToken?.tokenRetirada.isNullOrBlank()) {
                    tvTokenRetirada.text = tokenHtml("Token Retirada", storedToken)
                }
                if (pedido.deliveryToken == null) {
                    tvTokenCliente.text = tokenHtml("Token Cliente", null)
                    tvTokenInsucesso.text = tokenHtml("Token Insucesso", null)
                }
            }

            // Buscar tokens de delivery da API para exibir no detalhe
            val statusTokens = toStringSafe(pedido.status).uppercase().trim()
            if (statusTokens == "SAIU_PARA_ENTREGA" || statusTokens == "PRONTO_PARA_SAIR") {
                viewModel.getDeliveryTokens(toStringSafe(pedido.numero)) { tokenRetirada, tokenInsucesso, isSuccess ->
                    if (isSuccess) {
                        if (!tokenInsucesso.isNullOrBlank()) {
                            tvTokenInsucesso.text = tokenHtml("Token Insucesso", tokenInsucesso)
                            tokenInsucessoAtual = tokenInsucesso
                        }
                        if (!tokenRetirada.isNullOrBlank()) {
                            tvTokenRetirada.text = tokenHtml("Token Retirada", tokenRetirada)
                        }
                    }
                }
            }

            layoutConteudo.visibility = View.VISIBLE
            atualizarFab(toStringSafe(pedido.status))

        } catch (e: Exception) {
            Log.e(TAG, "exibirDetalhes ERRO", e)
            this.toast("Erro ao exibir detalhes: ${e.message}")
        }
    }

    // ============================================
    // FUNÇÕES AUXILIARES
    // ============================================

    private fun getTimelineStepStyle(nome: String?): Triple<String, Int, Int> {
        val borderColor: Int
        val iconRes: Int
        val displayNome: String
        when (nome?.uppercase()?.trim()) {
            "NOVO_PEDIDO", "INCLUIDO", "CHEGADA" -> {
                displayNome = "Chegada"
                iconRes = R.drawable.criado
                borderColor = android.graphics.Color.parseColor(Colors.GREEN_500)
            }
            "CRIADO" -> {
                displayNome = "Criado"
                iconRes = R.drawable.criado
                borderColor = android.graphics.Color.parseColor(Colors.GREEN_500)
            }
            "VISUALIZACAO", "VISUALIZADO" -> {
                displayNome = "Visualizado"
                iconRes = R.drawable.criado
                borderColor = android.graphics.Color.parseColor(Colors.GREEN_500)
            }
            "EM_SEPARACAO", "SEPARACAO" -> {
                displayNome = "Em Separação"
                iconRes = R.drawable.em_separacao
                borderColor = android.graphics.Color.parseColor(Colors.BLUE_500)
            }
            "EDITADO" -> {
                displayNome = "Editado"
                iconRes = R.drawable.editado
                borderColor = android.graphics.Color.parseColor(Colors.ORANGE_600)
            }
            "PRONTO_PARA_SAIR", "PRONTO" -> {
                displayNome = "Pronto para Retirada"
                iconRes = R.drawable.pronto_para_retirada
                borderColor = android.graphics.Color.parseColor(Colors.ORANGE_500)
            }
            "SAIU_PARA_ENTREGA" -> {
                displayNome = "Saiu para Entrega"
                iconRes = R.drawable.saiu_para_entrega
                borderColor = android.graphics.Color.parseColor(Colors.PURPLE_500)
            }
            "FINALIZADO", "ENTREGUE" -> {
                displayNome = "Entregue"
                iconRes = R.drawable.entregue
                borderColor = android.graphics.Color.parseColor(Colors.GREEN_500)
            }
            "RETORNAR_PARA_ESTOQUE" -> {
                displayNome = "Retornar para Estoque"
                iconRes = R.drawable.retornar_para_estoque
                borderColor = android.graphics.Color.parseColor(Colors.RED_600)
            }
            "CANCELADO" -> {
                displayNome = "Cancelado"
                iconRes = R.drawable.cancelado
                borderColor = android.graphics.Color.parseColor(Colors.RED_600)
            }
            "CANCELADO_PELA_LOJA" -> {
                displayNome = "Cancelado pela loja"
                iconRes = R.drawable.cancelado
                borderColor = android.graphics.Color.parseColor(Colors.RED_600)
            }
            "DEVOLVIDO" -> {
                displayNome = "Devolvido"
                iconRes = R.drawable.devolvido
                borderColor = android.graphics.Color.parseColor(Colors.RED_600)
            }
            else -> {
                displayNome = nome ?: "Evento"
                iconRes = R.drawable.criado
                borderColor = android.graphics.Color.parseColor(Colors.GRAY_400)
            }
        }
        return Triple(displayNome, iconRes, borderColor)
    }

    private fun formatarCpf(cpf: String): String {
        return if (cpf.length == 11) {
            "${cpf.substring(0, 3)}.${cpf.substring(3, 6)}.${cpf.substring(6, 9)}-${cpf.substring(9, 11)}"
        } else {
            cpf
        }
    }

    private fun formatarCnpj(cnpj: String): String {
        return if (cnpj.length == 14) {
            "${cnpj.substring(0, 2)}.${cnpj.substring(2, 5)}.${cnpj.substring(5, 8)}/${cnpj.substring(8, 12)}-${cnpj.substring(12, 14)}"
        } else {
            cnpj
        }
    }

    private fun formatarDocumento(doc: String): String {
        val digits = doc.replace(Regex("[^0-9]"), "")
        return when (digits.length) {
            11 -> formatarCpf(digits)
            14 -> formatarCnpj(digits)
            else -> doc
        }
    }

    private fun formatarDataHora(data: String): String {
        return try {
            if (data.isEmpty()) return ""
            val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).apply {
                timeZone = java.util.TimeZone.getTimeZone("UTC")
            }
            val date = inputFormat.parse(data)
            val outputFormat = SimpleDateFormat("dd/MM/yyyy HH:mm:ss", Locale("pt", "BR")).apply {
                timeZone = java.util.TimeZone.getDefault()
            }
            date?.let { outputFormat.format(it) } ?: data
        } catch (e: Exception) {
            data
        }
    }

    private fun parseIsoDate(data: String?): Date? {
        if (data.isNullOrEmpty()) return null
        return try {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).apply {
                timeZone = java.util.TimeZone.getTimeZone("UTC")
            }.parse(data)
        } catch (e: Exception) {
            null
        }
    }

    private fun formatarDuracao(diffMs: Long): String {
        val totalSec = kotlin.math.abs(diffMs).coerceAtLeast(1000L) / 1000
        val dias = totalSec / (24 * 3600)
        val horas = (totalSec % (24 * 3600)) / 3600
        val minutos = (totalSec % 3600) / 60
        val segundos = totalSec % 60
        return buildString {
            if (dias > 0) append("${dias}d ")
            if (horas > 0 || dias > 0) append("${horas}h ")
            if (minutos > 0 || horas > 0 || dias > 0) append("${minutos}m ")
            append("${segundos}s")
        }
    }

    private fun formatarTempoConfirmacao(tempoMs: Long): String {
        val totalSec = kotlin.math.abs(tempoMs) / 1000
        if (totalSec < 60) return "${totalSec}s"
        val minutos = totalSec / 60
        val segundos = totalSec % 60
        if (minutos >= 60) {
            val horas = minutos / 60
            val minRest = minutos % 60
            return "${horas}h ${minRest}min ${segundos}s"
        }
        return "${minutos}min ${segundos}s"
    }

    private fun atualizarBarraProgressoDetalhe(totalMin: Int) {
        val porcentagem = ((totalMin.toFloat() / 35f) * 100f).coerceAtMost(100f)
        val params = viewBarraProgressoDetalhe.layoutParams
        params.width = ((layoutDuracaoDetalhe.width * porcentagem / 100f).toInt()).coerceAtLeast(0)
        viewBarraProgressoDetalhe.layoutParams = params

        val fillColor = if (totalMin <= 35) 0xFF28A745.toInt() else 0xFFDC3545.toInt()
        val drawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setCornerRadius(4f * viewBarraProgressoDetalhe.resources.displayMetrics.density)
            setColor(fillColor)
        }
        viewBarraProgressoDetalhe.background = drawable
    }

    private fun iniciarTimerDetalhe(tempoConfirmacaoMs: Long) {
        removerTimerDetalhe()
        val momentoReferencia = System.currentTimeMillis()

        tickJob = lifecycleScope.launch {
            while (isActive) {
                val decorrido = tempoConfirmacaoMs + (System.currentTimeMillis() - momentoReferencia)
                val totalMin = (kotlin.math.abs(decorrido) / 60000).toInt()
                val texto = formatarTempoConfirmacao(decorrido)
                tvTempoConfirmacaoHeader.text = "Confirmação: $texto"
                tvTempoConfirmacaoHeader.setTextColor(ContextCompat.getColor(this@DetalhesPedidoActivity,
                    if (totalMin <= 35) R.color.verde else R.color.vermelho
                ))
                layoutDuracaoDetalhe.visibility = View.VISIBLE
                atualizarBarraProgressoDetalhe(totalMin)
                delay(1000)
            }
        }
    }

    private fun removerTimerDetalhe() {
        tickJob?.cancel()
        tickJob = null
    }

    private fun isRetiradaReserva(pedido: Pedido): Boolean {
        val canais = "${toStringSafe(pedido.canalDeVendas)} ${toStringSafe(pedido.canalVendas)}"
        return pedido.tipoEntrega == "EXTERNA" && (canais.contains("Magazine", ignoreCase = true) || canais.contains("Americanas", ignoreCase = true))
    }

    private fun formatStatus(status: String): String {
        return when (status) {
            "NOVO_PEDIDO" -> "NOVO PEDIDO"
            "PREVISTO" -> "PREVISTO"
            "EM_SEPARACAO" -> "EM SEPARAÇÃO"
            "EDITADO" -> "EDITADO"
            "PRONTO_PARA_SAIR" -> "PRONTO PARA SAIR"
            "SAIU_PARA_ENTREGA" -> "SAIU PARA ENTREGA"
            "RETORNAR_PARA_ESTOQUE" -> "RETORNAR ESTOQUE"
            "FINALIZADO", "ENTREGUE" -> "Entregue"
            "CANCELADO" -> "CANCELADO"
            "DEVOLVIDO" -> "DEVOLVIDO"
            else -> status
        }
    }

    // ============================================
    // FAB - CORES DINÂMICAS
    // ============================================

    private fun atualizarFab(status: String) {
        try {
            Log.d(TAG, "=== atualizarFab CHAMADO ===")
            Log.d(TAG, "Status recebido: '$status'")

            badgeCentered.visibility = View.GONE
            badgeCancelarRetirada.visibility = View.GONE
            badgePending = false
            badgeCancelPending = false

            val statusNormalized = status.trim().uppercase()

            when (statusNormalized) {
                "NOVO_PEDIDO", "NOVO PEDIDO" -> {
                    Log.d(TAG, "✅ Configurando badge VERDE - EM SEPARAÇÃO")
                    badgeCentered.text = "POR EM SEPARAÇÃO"
                    badgeCentered.setBackgroundResource(R.drawable.bg_badge_green)
                    badgePending = true
                    badgeCentered.setOnClickListener { pedidoAtual?.let { separarPedido(it) } }
                }
                "EM_SEPARACAO", "EDITADO", "EM SEPARAÇÃO" -> {
                    Log.d(TAG, "✅ Configurando badge VERDE - CONFIRMAR")
                    badgeCentered.text = "CONFIRMAR"
                    badgeCentered.setBackgroundResource(R.drawable.bg_badge_green)
                    badgePending = true
                    badgeCentered.setOnClickListener { pedidoAtual?.let { confirmarPedido(it) } }
                }
                "PRONTO_PARA_SAIR", "PRONTO PARA SAIR" -> {
                    if (confirmacaoEntregadorPending) {
                        Log.d(TAG, "✅ Entregador confirmou - badge CONFIRMAR")
                        badgeCentered.text = "CONFIRMAR"
                        badgeCentered.setBackgroundResource(R.drawable.bg_badge_green)
                        badgePending = true
                        badgeCentered.setOnClickListener { pedidoAtual?.let { confirmarRetiradaInversa(it) } }
                    } else {
                    Log.d(TAG, "✅ Configurando badge LARANJA - RETIRAR PEDIDO")
                    badgeCentered.text = "RETIRAR PEDIDO"
                    badgeCentered.setBackgroundResource(R.drawable.bg_badge_orange)
                    badgePending = true
                    badgeCentered.setOnClickListener { pedidoAtual?.let { retirarPedido(it) } }

                    // Cancel badge for orders > 3 days without pickup or with error
                    badgeCancelPending = false
                    val dataCriacaoStr = pedidoAtual?.dataCriacao
                    val temErro = !toStringSafe(pedidoAtual?.erro).isBlank()
                    var cancelaPermitido = temErro
                    if (!dataCriacaoStr.isNullOrEmpty() && !cancelaPermitido) {
                        try {
                            val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).apply {
                                timeZone = TimeZone.getTimeZone("UTC")
                            }
                            val dataCriacao = fmt.parse(dataCriacaoStr)
                            if (dataCriacao != null) {
                                val diffMs = System.currentTimeMillis() - dataCriacao.time
                                val diffDays = diffMs / (1000 * 60 * 60 * 24)
                                if (diffDays >= 3) {
                                    cancelaPermitido = true
                                }
                            }
                        } catch (_: Exception) { }
                    }
                    if (cancelaPermitido) {
                        badgeCancelPending = true
                        badgeCancelarRetirada.setOnClickListener { pedidoAtual?.let { cancelarPedidoRetiradaPendente(it) } }
                    }
                    }
                }
                "SAIU_PARA_ENTREGA" -> {
                    Log.d(TAG, "✅ Configurando badge ROXO - SAIU PARA ENTREGA")
                    badgeCentered.text = "ENTREGADOR VOLTOU"
                    badgeCentered.setBackgroundResource(R.drawable.bg_badge_red)
                    badgePending = true
                    badgeCentered.setOnClickListener { pedidoAtual?.let { mostrarMotivosInsucesso(it) } }
                }
                "RETORNAR_PARA_ESTOQUE" -> {
                    Log.d(TAG, "✅ Configurando badge VERMELHO - DEVOLVER PARA O ESTOQUE")
                    badgeCentered.text = "DEVOLVER PARA O ESTOQUE"
                    badgeCentered.setBackgroundResource(R.drawable.bg_badge_red)
                    badgePending = true
                    badgeCentered.setOnClickListener { pedidoAtual?.let { mostrarDialogDevolverEstoque(it) } }
                }
                "FINALIZADO", "ENTREGUE" -> {
                    Log.d(TAG, "✅ Configurando badge VERMELHO - CANCELAR")
                    badgeCentered.text = "CANCELAR"
                    badgeCentered.setBackgroundResource(R.drawable.bg_badge_red)
                    badgePending = true
                    badgeCentered.setOnClickListener { pedidoAtual?.let { cancelarPedidoHistorico(it) } }
                }
                "CANCELADO", "DEVOLVIDO" -> {
                    badgeCentered.visibility = View.GONE
                    badgePending = false
                }
                else -> {
                    Log.d(TAG, "⚠️ Status não reconhecido: $status")
                }
            }

            // Mostrar badges se couber na tela
            scrollViewContent.post {
                val child = scrollViewContent.getChildAt(0)
                if (child != null && badgePending) {
                    val contentHeight = child.height
                    val scrollHeight = scrollViewContent.height
                    val fits = contentHeight <= scrollHeight
                    if (fits) {
                        if (badgeCentered.visibility != View.VISIBLE) {
                            badgeCentered.alpha = 0f
                            badgeCentered.visibility = View.VISIBLE
                            badgeCentered.animate().alpha(1f).setDuration(200).start()
                        }
                        if (badgeCancelPending && badgeCancelarRetirada.visibility != View.VISIBLE) {
                            badgeCancelarRetirada.alpha = 0f
                            badgeCancelarRetirada.visibility = View.VISIBLE
                            badgeCancelarRetirada.animate().alpha(1f).setDuration(200).start()
                        }
                    }
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "atualizarFab ERRO", e)
            e.printStackTrace()
        }
    }

    // ============================================
    // AÇÕES DO PEDIDO
    // ============================================

    private fun separarPedido(pedido: Pedido) {
        mostrarLoading(true, "Separando pedido...")
        val origem = toStringSafe(pedido.origem).ifEmpty { "SHIP_FROM_STORE" }
        val codigoExterno = toStringSafe(pedido.codigoExterno)
        viewModel.separarPedido(origem, codigoExterno) { isSuccess ->
            mostrarLoading(false)
            if (isSuccess) {
                this.toast("✅ Pedido enviado para separação!")
                // ✅ ATUALIZAR O PEDIDO LOCALMENTE
                pedidoAtual = pedido.copy(status = "EM_SEPARACAO")
                // ✅ ATUALIZAR A UI
                exibirDetalhes(pedidoAtual!!)
                // ✅ ATUALIZAR O BADGE
                atualizarFab("EM_SEPARACAO")
            } else {
                if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                else this.toast("❌ Erro ao separar")
            }
        }
    }

    private fun cancelarPedidoRetiradaPendente(pedido: Pedido) {
        val view = LayoutInflater.from(this).inflate(R.layout.dialog_cancelar_retirada, null)
        val btnSim = view.findViewById<Button>(R.id.btnSimCancelar)
        val btnNao = view.findViewById<Button>(R.id.btnNaoCancelar)

        val dialog = AlertDialog.Builder(this)
            .setView(view)
            .setCancelable(false)
            .create()
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        btnSim.setOnClickListener {
            dialog.dismiss()
            executarCancelamentoProntoRetirada(pedido)
        }
        btnNao.setOnClickListener { dialog.dismiss() }

        dialog.show()
        dialog.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.85).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    private fun executarCancelamentoProntoRetirada(pedido: Pedido) {
        mostrarLoading(true, "Cancelando pedido...")
        val origem = pedido.origem ?: run { mostrarLoading(false); return }
        val codigoExterno = pedido.codigoExterno
        viewModel.cancelarPedidoProntoRetirada(origem, codigoExterno, "") { isSuccess, code, errorBody ->
            mostrarLoading(false)
            if (isSuccess) {
                this.toast("✅ Pedido cancelado!")
                finish()
            } else {
                if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                else this.toast("❌ Erro ao cancelar: $code - $errorBody")
            }
        }
    }

    private fun cancelarPedidoHistorico(pedido: Pedido) {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_devolver_historico, null)
        val etMotivo = dialogView.findViewById<EditText>(R.id.etMotivoDevolucao)
        val cbRecaptcha = dialogView.findViewById<androidx.appcompat.widget.AppCompatCheckBox>(R.id.cbDevolucaoRecaptcha)
        val btnNao = dialogView.findViewById<Button>(R.id.btnNaoDevolver)
        val btnSim = dialogView.findViewById<Button>(R.id.btnSimDevolver)

        etMotivo.hint = "Motivo do cancelamento"
        btnSim.text = "CANCELAR PEDIDO"
        btnSim.textSize = 12f

        var captchaObtido = false
        var atualizandoViaCodigo = false

        fun validar() {
            val motivoOk = etMotivo.text.toString().trim().isNotEmpty()
            btnSim.isEnabled = motivoOk && captchaObtido && cbRecaptcha.isChecked
            btnSim.setTextColor(if (btnSim.isEnabled) android.graphics.Color.WHITE else android.graphics.Color.parseColor(Colors.GRAY_300))
            btnSim.backgroundTintList = if (btnSim.isEnabled) {
                ContextCompat.getColorStateList(this, R.color.vermelho_maestro)
            } else {
                ContextCompat.getColorStateList(this, android.R.color.darker_gray)
            }
        }

        etMotivo.addTextChangedListener(object : android.text.TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: android.text.Editable?) { validar() }
        })

        cbRecaptcha.setOnCheckedChangeListener { _, isChecked ->
            if (atualizandoViaCodigo) return@setOnCheckedChangeListener
            if (isChecked) {
                if (!captchaObtido) {
                    atualizandoViaCodigo = true
                    cbRecaptcha.isChecked = false
                    atualizandoViaCodigo = false
                    RecaptchaManager.showRecaptchaDialog(
                        this,
                        onError = { msg -> toastLong(msg) }
                    ) { token ->
                        captchaObtido = true
                        atualizandoViaCodigo = true
                        cbRecaptcha.isChecked = true
                        atualizandoViaCodigo = false
                        validar()
                    }
                }
            } else {
                captchaObtido = false
            }
            validar()
        }

        val dialog = AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(false)
            .create()

        btnNao.setOnClickListener { dialog.dismiss() }

        btnSim.setOnClickListener {
            if (!btnSim.isEnabled) return@setOnClickListener
            dialog.dismiss()
            val token = RecaptchaManager.getToken()
            if (token != null) {
                executarCancelamentoHistorico(pedido, token)
            }
        }

        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
        dialog.show()
        dialog.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.92).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    private fun executarCancelamentoHistorico(pedido: Pedido, captchaToken: String) {
        mostrarLoading(true, "Cancelando pedido...")
        val origem = pedido.origem ?: ""
        val codigoExterno = pedido.codigoExterno
        viewModel.cancelarPedido(origem, codigoExterno, "Cancelamento solicitado pelo cliente") { isSuccess, code ->
            mostrarLoading(false)
            if (isSuccess) {
                this.toast("✅ Pedido cancelado!")
                finish()
            } else {
                if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                else this.toast("❌ Erro ao cancelar: $code")
            }
        }
    }

    private fun recusarPedido(pedido: Pedido) {
        mostrarLoading(true, "Carregando motivos de recusa...")
        val origem = pedido.origem ?: run { mostrarLoading(false); toast("Origem não informada"); return }
        val status = pedido.status ?: run { mostrarLoading(false); toast("Status não informado"); return }
        viewModel.carregarMotivosRecusa(origem, status) { motivos, success ->
            mostrarLoading(false)
            if (!success || motivos == null) {
                if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                else toast("Erro ao carregar motivos")
                return@carregarMotivosRecusa
            }
            mostrarDialogoRecusa(pedido, motivos)
        }
    }

    private fun mostrarDialogoRecusa(pedido: Pedido, motivos: List<RecusaMotivo>) {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_motivo_radio, null)
        val tvTitle = dialogView.findViewById<TextView>(R.id.tvTitle)
        val rgMotivos = dialogView.findViewById<RadioGroup>(R.id.rgMotivos)
        val btnCancelar = dialogView.findViewById<Button>(R.id.btnCancelar)
        val btnConfirmar = dialogView.findViewById<Button>(R.id.btnConfirmar)

        tvTitle.text = "Selecione o motivo da recusa"

        var motivoCodeSelecionado = ""

        for (motivo in motivos) {
            val rb = LayoutInflater.from(this).inflate(R.layout.item_motivo_radio, rgMotivos, false) as RadioButton
            rb.id = android.view.View.generateViewId()
            rb.text = motivo.description
            rb.setOnClickListener {
                if (motivo.subItems.isEmpty()) {
                    motivoCodeSelecionado = motivo.code
                }
            }
            rgMotivos.addView(rb)

            if (motivo.subItems.isNotEmpty()) {
                for (sub in motivo.subItems) {
                    val subRb = LayoutInflater.from(this).inflate(R.layout.item_motivo_radio, rgMotivos, false) as RadioButton
                    subRb.id = android.view.View.generateViewId()
                    subRb.text = "    ↳ ${sub.description}"
                    subRb.setTextSize(13f)
                    subRb.setOnClickListener {
                        motivoCodeSelecionado = sub.code
                    }
                    rgMotivos.addView(subRb)
                }
            }
        }

        val dialog = AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(true)
            .create()
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        btnCancelar.setOnClickListener { dialog.dismiss() }

        btnConfirmar.setOnClickListener {
            if (motivoCodeSelecionado.isEmpty()) {
                toast("Selecione um motivo")
                return@setOnClickListener
            }
            Log.d(TAG, "Recusa total - motivo selecionado: $motivoCodeSelecionado")
            dialog.dismiss()
            executarRecusa(pedido, motivoCodeSelecionado)
        }

        dialog.show()
        dialog.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.92).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    private fun executarRecusa(pedido: Pedido, motivoCode: String) {
        val origem = pedido.origem ?: run { toast("Origem não informada"); return }
        val codigoExterno = pedido.codigoExterno ?: run { toast("Código externo não informado"); return }
        mostrarLoading(true, "Atualizando inventário...")
        viewModel.updateInventory(pedido.numero ?: "", emptyList(), 0.0, corpoVazio = true) { invSuccess ->
            Log.d(TAG, "updateInventory na recusa: $invSuccess")
            mostrarLoading(true, "Enviando recusa...")
            viewModel.recusarPedido(origem, codigoExterno, motivoCode) { isSuccess, code ->
                mostrarLoading(false)
                if (isSuccess) {
                    this.toast("✅ Pedido recusado com sucesso!")
                    finish()
                } else {
                    if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                    else this.toast("❌ Erro ao recusar: $code")
                }
            }
        }
    }

    private fun abrirScannerImei() {
        val intent = android.content.Intent(this, io.maestro.ui.scanner.ScannerImeiActivity::class.java)
        scannerImeiLauncher.launch(intent)
    }

    private fun mostrarFabScannerImei() {
        if (::fabScannerImei.isInitialized) {
            fabScannerImei.visibility = android.view.View.VISIBLE
        }
    }

    private fun esconderFabScannerImei() {
        if (::fabScannerImei.isInitialized) {
            fabScannerImei.visibility = android.view.View.GONE
        }
    }

    private fun confirmarPedido(pedido: Pedido) {
        if (pedido.itens.isNullOrEmpty()) {
            this.toast("Pedido sem itens para confirmar")
            return
        }

        val temSmartphone = pedido.itens?.any { it.quantidadeImeis > 0 } == true

        if (temSmartphone) {
            val dialogConfirmacao = SmartphoneConfirmacaoDialog(
                context = this,
                pedido = pedido,
                onScanRequested = { abrirScannerImei() },
                onConfirm = { quantidades, imeis ->
                    esconderFabScannerImei()
                    val isEmSeparacao = toStringSafe(pedido.status).trim().uppercase() == "EM_SEPARACAO"

                    if (isEmSeparacao) {
                        val houveAlteracao = pedido.itens?.any { item ->
                            val key = item.codigoSAP ?: item.codigoEAN ?: item.descricao ?: ""
                            quantidades[key] != (item.quantidadeTotal ?: item.quantidade)
                        } ?: false
                        if (houveAlteracao) {
                            carregarMotivosConfirmacao(pedido, quantidades, imeis, "")
                        } else {
                            executarConfirmacaoPedido(pedido, quantidades, imeis, null, "")
                        }
                    } else {
                        val houveAlteracao = pedido.itens?.any { item ->
                            val key = item.codigoSAP ?: item.codigoEAN ?: item.descricao ?: ""
                            quantidades[key] != (item.quantidadeTotal ?: item.quantidade)
                        } ?: false
                        if (houveAlteracao) {
                            carregarMotivosConfirmacao(pedido, quantidades, imeis, "")
                        } else {
                            executarConfirmacaoPedido(pedido, quantidades, imeis, null, "")
                        }
                    }
                },
                onCancel = {
                    esconderFabScannerImei()
                    this.toast("Confirmação cancelada")
                }
            )
            smartphoneConfirmacaoDialog = dialogConfirmacao
            dialogConfirmacao.show()
        } else {
            val dialog = ItemQuantidadeNovoDialog(
                context = this,
                pedido = pedido,
                onConfirm = { quantidades: Map<String, Int> ->
                    val imeisEditados = emptyMap<String, List<String>>()
                    val houveAlteracao = pedido.itens?.any { item ->
                        val codigoSap = item.codigoSAP ?: ""
                        quantidades[codigoSap] != (item.quantidadeTotal ?: item.quantidade)
                    } ?: false

                    // Recusa total: todos os itens do pedido ficaram zerados
                    val recusaTotal = pedido.itens?.isNotEmpty() == true && pedido.itens.all { item ->
                        val codigoSap = item.codigoSAP ?: ""
                        (quantidades[codigoSap] ?: item.quantidade) == 0
                    }

                    if (recusaTotal) {
                        recusarPedido(pedido)
                    } else if (houveAlteracao) {
                        carregarMotivosConfirmacao(pedido, quantidades, imeisEditados, "")
                    } else {
                        mostrarDialogTudoCerto(pedido, quantidades, imeisEditados)
                    }
                },
                onRecusar = { recusarPedido(pedido) }
            )
            itemQuantidadeNovoDialog = dialog
            dialog.show()
        }
    }

    private fun mostrarDialogTudoCerto(pedido: Pedido, quantidades: Map<String, Int>, imeis: Map<String, List<String>>) {
        val dialogView = layoutInflater.inflate(R.layout.dialog_confirmar_tudo_certo, null)
        val btnConfirmar = dialogView.findViewById<Button>(R.id.btnDialogConfirmar)
        val btnCancelar = dialogView.findViewById<Button>(R.id.btnDialogCancelar)
        val tvPergunta = dialogView.findViewById<TextView>(R.id.tvDialogConfirmarPergunta)

        val totalItens = quantidades.values.sum()
        tvPergunta.text = "Confirma a separação de $totalItens itens?"

        val dialog = AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(true)
            .create()

        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        btnConfirmar.setOnClickListener {
            dialog.dismiss()
            executarConfirmacaoPedido(pedido, quantidades, imeis, null, "")
        }

        btnCancelar.setOnClickListener {
            dialog.dismiss()
        }

        dialog.show()
        dialog.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.80).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    // ============================================
    // RETIRAR PEDIDO - CORRIGIDO COM VERIFICAÇÃO DE ORIGEM
    // ============================================

    private fun retirarPedido(pedido: Pedido) {
        mostrarLoading(true, "Buscando dados do pedido...")
        val numero = toStringSafe(pedido.numero)
        
        viewModel.getDeliveryTokens(numero) { tokenRetirada, tokenInsucesso, isSuccess ->
            // ✅ Delivery EXTERNA (Magazine/Americanas): mostrar token pro entregador e aguardar confirmação dele (fluxo inverso)
            if (isRetiradaReserva(pedido)) {
                abrirFluxoInversoRetirada(pedido, tokenRetirada, tokenInsucesso, isSuccess)
                return@getDeliveryTokens
            }

            mostrarLoading(false)
            
            // ✅ Se já existe token de insucesso, mostrar ele primeiro
            if (isSuccess && !tokenInsucesso.isNullOrEmpty()) {
                mostrarDialogTokenInsucesso(tokenInsucesso, pedido)
                return@getDeliveryTokens
            }
            
            val dialogView = layoutInflater.inflate(R.layout.dialog_token, null)
            dialogView.findViewById<TextView>(R.id.tvTokenNumeroPedido).text = "#${toStringSafe(pedido.codigoExterno)}"
            dialogView.findViewById<TextView>(R.id.tvTokenClienteNome).text = pedido.cliente?.nome ?: "Cliente não informado"

            val etCodigo = dialogView.findViewById<EditText>(R.id.etTokenCodigo)
            val btnConfirmar = dialogView.findViewById<TextView>(R.id.btnTokenConfirmar)
            btnConfirmar.isEnabled = false

            etCodigo.addTextChangedListener(object : android.text.TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                override fun afterTextChanged(s: android.text.Editable?) {
                    btnConfirmar.isEnabled = !s.toString().trim().isEmpty()
                }
            })

            val dialog = AlertDialog.Builder(this@DetalhesPedidoActivity, R.style.DialogPerfilTheme)
                .setView(dialogView)
                .create()

            btnConfirmar.setOnClickListener {
                val codigo = etCodigo.text.toString().trim()
                if (codigo.isEmpty()) {
                    this@DetalhesPedidoActivity.toast("Digite o código de retirada")
                    return@setOnClickListener
                }
                dialog.dismiss()
                
                // Se já tem token validado, não precisa verificar o código
                if (isSuccess && !tokenRetirada.isNullOrEmpty()) {
                    if (codigo != tokenRetirada) {
                        this@DetalhesPedidoActivity.toast("Código inválido!")
                        return@setOnClickListener
                    }
                    confirmarRetirada(pedido, codigo, tokenValidado = true)
                } else {
                    confirmarRetirada(pedido, codigo, tokenValidado = false)
                }
            }

            dialogView.findViewById<TextView>(R.id.btnTokenCancelar).setOnClickListener { dialog.dismiss() }
            dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
            dialog.show()
            dialog.window?.setLayout(
                (resources.displayMetrics.widthPixels * 0.88).toInt(),
                WindowManager.LayoutParams.WRAP_CONTENT
            )
        }
    }

    private fun abrirFluxoInversoRetirada(
        pedido: Pedido,
        tokenRetiradaApi: String?,
        tokenInsucessoApi: String?,
        isSuccess: Boolean
    ) {
        val temToken = !tokenRetiradaApi.isNullOrBlank()
            || !tokenInsucessoApi.isNullOrBlank()
            || !pedido.deliveryToken?.tokenRetirada.isNullOrBlank()
            || !pedido.deliveryToken?.tokenInsucesso.isNullOrBlank()

        Log.d(TAG, "abrirFluxoInverso apiRetirada=$tokenRetiradaApi apiInsucesso=$tokenInsucessoApi isSuccess=$isSuccess embedded=${pedido.deliveryToken} temToken=$temToken")

        fun mostrar(p: Pedido) {
            val token = tokenRetiradaApi?.takeIf { it.isNotBlank() }
                ?: tokenInsucessoApi?.takeIf { it.isNotBlank() }
                ?: p.deliveryToken?.tokenRetirada?.takeIf { it.isNotBlank() }
                ?: p.deliveryToken?.tokenInsucesso?.takeIf { it.isNotBlank() }
                ?: "---"
            Log.d(TAG, "Retirada inversa (Americanas/Magazine): token=$token, isSuccess=$isSuccess")
            mostrarDialogTokenInsucesso(
                token = token,
                pedido = p,
                isRetirada = true,
                isFluxoInverso = true,
                onConfirm = { confirmarRetirada(p, token, tokenValidado = true, isRetiradaReserva = true) }
            )
            iniciarPollingConfirmacaoEntregador(p)
        }

        if (temToken) {
            mostrarLoading(false)
            mostrar(pedido)
            return
        }

        // Sem token na API nem no pedido atual: buscar o pedido completo (deliveryToken embutido)
        mostrarLoading(true, "Buscando token do pedido...")
        viewModel.getPedidoById(toStringSafe(pedido.numero)) { pedidoApi ->
            mostrarLoading(false)
            val completo = pedidoApi ?: pedido
            pedidoAtual = completo
            Log.d(TAG, "getPedidoById fallback deliveryToken=${completo.deliveryToken}")
            mostrar(completo)
        }
    }

    private fun confirmarRetirada(pedido: Pedido, codigo: String, tokenValidado: Boolean, isRetiradaReserva: Boolean = false) {
        val isRetiradaLoja = pedido.tipoEntrega == "RETIRADA"

        fun salvarTokenEPedido() {
            viewModel.saveDeliveryToken(pedido.numero, codigo)
            pedidoAtual = pedido.copy(
                status = if (isRetiradaLoja) "FINALIZADO" else "SAIU_PARA_ENTREGA",
                deliveryToken = DeliveryToken(
                    tokenRetirada = if (isRetiradaReserva) pedido.deliveryToken?.tokenRetirada else codigo,
                    tokenCliente = pedido.deliveryToken?.tokenCliente,
                    tokenInsucesso = if (isRetiradaReserva) codigo else pedido.deliveryToken?.tokenInsucesso
                )
            )
        }

        if (tokenValidado) {
            mostrarLoading(true, "Confirmando retirada...")
            viewModel.retirarPedido(pedido) { isSuccess, code ->
                mostrarLoading(false)
                if (isSuccess) {
                    this.toast("✅ Pedido retirado com sucesso!")
                    salvarTokenEPedido()
                    exibirDetalhes(pedidoAtual!!)
                    if (isRetiradaLoja) {
                        atualizarFab("FINALIZADO")
                    } else {
                        atualizarFab("SAIU_PARA_ENTREGA")
                    }
                } else {
                    if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                    else {
                        val msg = when (code) {
                            400 -> "❌ Código inválido ou pedido não está pronto"
                            401 -> "❌ Sessão expirada. Faça login novamente."
                            404 -> "❌ Pedido não encontrado"
                            409 -> "❌ Pedido já foi retirado"
                            422 -> "❌ Erro de validação. Verifique os dados do pedido."
                            else -> "❌ Erro ao retirar (HTTP $code)"
                        }
                        toast(msg)
                    }
                }
            }
            return
        }
        mostrarLoading(true, "Verificando código de retirada...")
        viewModel.verificarCodigoRetirada(codigo, pedido.numero) { isValid ->
            if (!isValid) {
                mostrarLoading(false)
                this.toast("❌ Código inválido!")
                return@verificarCodigoRetirada
            }
            viewModel.retirarPedido(pedido) { isSuccess, code ->
                mostrarLoading(false)
                if (isSuccess) {
                    this.toast("✅ Pedido retirado com sucesso!")
                    salvarTokenEPedido()
                    exibirDetalhes(pedidoAtual!!)
                    if (isRetiradaLoja) {
                        atualizarFab("FINALIZADO")
                    } else {
                        atualizarFab("SAIU_PARA_ENTREGA")
                    }
                } else {
                    if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                    else {
                        val msg = when (code) {
                            400 -> "❌ Código inválido ou pedido não está pronto"
                            401 -> "❌ Sessão expirada. Faça login novamente."
                            404 -> "❌ Pedido não encontrado"
                            409 -> "❌ Pedido já foi retirado"
                            422 -> "❌ Erro de validação. Verifique os dados do pedido."
                            else -> "❌ Erro ao retirar (HTTP $code)"
                        }
                        toast(msg)
                    }
                }
            }
        }
    }

    // ============================================
    // FLUXO INVERSO: POLLING DA CONFIRMAÇÃO DO ENTREGADOR (BEE)
    // ============================================

    private fun iniciarPollingConfirmacaoEntregador(pedido: Pedido) {
        pollingConfirmacaoJob?.cancel()
        pollingConfirmacaoJob = lifecycleScope.launch {
            Log.d(TAG, "Polling confirmação entregador INICIADO para pedido ${toStringSafe(pedido.numero)}")
            var rodadas = 0
            while (isActive) {
                delay(5000)
                rodadas++
                Log.d(TAG, "Polling confirmação entregador: rodada $rodadas (máx 60)")
                if (rodadas > 60) break
                viewModel.getPedidoById(toStringSafe(pedido.numero)) { pedidoApi ->
                    if (pedidoApi != null) {
                        val statusApi = toStringSafe(pedidoApi.status).uppercase()
                        Log.d(TAG, "Polling confirmação entregador: status atual = $statusApi")
                        if (statusApi == "SAIU_PARA_ENTREGA" || statusApi == "FINALIZADO" || statusApi == "ENTREGUE") {
                            pollingConfirmacaoJob?.cancel()
                            runOnUiThread {
                                confirmacaoEntregadorPending = true
                                pedidoAtual = pedidoApi
                                exibirDetalhes(pedidoAtual!!)
                                atualizarFab(statusApi)
                                this@DetalhesPedidoActivity.toast("✅ Entregador confirmou a coleta! Toque em CONFIRMAR.")
                            }
                        }
                    }
                }
            }
        }
    }

    private fun confirmarRetiradaInversa(pedido: Pedido) {
        val codigo = pedido.deliveryToken?.tokenRetirada?.takeIf { it.isNotBlank() }
            ?: pedido.deliveryToken?.tokenInsucesso?.takeIf { it.isNotBlank() }
            ?: tokenInsucessoAtual?.takeIf { it.isNotBlank() }
            ?: "---"
        confirmarRetirada(pedido, codigo, tokenValidado = true, isRetiradaReserva = true)
    }

    // ============================================
    // FLUXO: ENTREGADOR VOLTOU (INSUCESSO)
    // ============================================

    private fun mostrarMotivosInsucesso(pedido: Pedido) {
        // Prioridade 1: usar tokenInsucessoAtual (carregado em exibirDetalhes)
        // Prioridade 2: ler direto do TextView que JÁ MOSTRA o token no detalhe
        var tokenParaDialog = tokenInsucessoAtual

        if (tokenParaDialog.isNullOrBlank()) {
            // Tentar ler do TextView do detalhe (tvTokenInsucesso mostra "Token Insucesso: XXXX")
            val textoToken = tvTokenInsucesso.text.toString()
            if (textoToken.startsWith("Token Insucesso: ")) {
                tokenParaDialog = textoToken.substring("Token Insucesso: ".length)
                Log.d(TAG, "Lido do TextView detalhe: $tokenParaDialog")
            }
        }

        if (!tokenParaDialog.isNullOrBlank()) {
            Log.d(TAG, "Usando token para dialog: $tokenParaDialog")
            mostrarLoading(true, "Carregando motivos...")
            viewModel.getMotivosInsucesso { motivos, motivosSuccess ->
                mostrarLoading(false)
                if (motivosSuccess && motivos != null) {
                    mostrarDialogoMotivosInsucesso(pedido, motivos, tokenParaDialog)
                } else {
                    if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                    else this.toast("Erro ao carregar motivos")
                }
            }
        } else {
            Log.d(TAG, "Token ainda vazio, buscando da API...")
            mostrarLoading(true, "Carregando dados...")
            val numero = toStringSafe(pedido.numero)
            viewModel.getDeliveryTokens(numero) { tokenRetirada, tokenInsucesso, isSuccess ->
                tokenInsucessoAtual = if (isSuccess) tokenInsucesso else null
                viewModel.getMotivosInsucesso { motivos, motivosSuccess ->
                    mostrarLoading(false)
                    if (motivosSuccess && motivos != null) {
                        mostrarDialogoMotivosInsucesso(pedido, motivos, tokenInsucessoAtual)
                    } else {
                        if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                        else this.toast("Erro ao carregar motivos")
                    }
                }
            }
        }
    }

    private fun mostrarDialogoMotivosInsucesso(pedido: Pedido, motivos: List<Motivo>, tokenInsucessoExistente: String? = null) {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_entregador_voltou, null)
        val layoutMotivoSelector = dialogView.findViewById<View>(R.id.layoutMotivoSelector)
        val tvMotivoSelecionado = dialogView.findViewById<TextView>(R.id.tvMotivoSelecionado)
        val etObservacao = dialogView.findViewById<EditText>(R.id.etObservacao)
        val cbRecaptcha = dialogView.findViewById<CheckBox>(R.id.cbRecaptcha)
        val layoutRecaptcha = dialogView.findViewById<View>(R.id.layoutRecaptcha)
        val tvTokenInsucessoGrande = dialogView.findViewById<TextView>(R.id.tvTokenInsucessoGrande)
        val btnConfirmar = dialogView.findViewById<TextView>(R.id.btnConfirmar)
        val btnCancelar = dialogView.findViewById<TextView>(R.id.btnCancelar)

        val nomes = motivos.map { it.nome }
        var motivoSelecionadoIndex = -1

        var captchaObtido = false
        var atualizandoViaCodigo = false
        var processando = false

        fun atualizarBotao() {
            val motivoOk = motivoSelecionadoIndex >= 0
            val obsOk = etObservacao.text.toString().trim().isNotEmpty()
            val habilitado = motivoOk && obsOk && captchaObtido && !processando
            btnConfirmar.isEnabled = habilitado
            btnConfirmar.alpha = if (habilitado) 1f else 0.5f
            btnConfirmar.setBackgroundColor(ContextCompat.getColor(this, if (habilitado) R.color.green_600 else R.color.gray_300))
        }

        btnConfirmar.isEnabled = false
        btnConfirmar.alpha = 0.5f

        layoutMotivoSelector.setOnClickListener {
            val motivoDialogView = LayoutInflater.from(this).inflate(R.layout.dialog_motivo_radio, null)
            val rgMotivos = motivoDialogView.findViewById<RadioGroup>(R.id.rgMotivos)
            val btnCancelarMotivo = motivoDialogView.findViewById<Button>(R.id.btnCancelar)
            val btnConfirmarMotivo = motivoDialogView.findViewById<Button>(R.id.btnConfirmar)

            val motivoDialog = AlertDialog.Builder(this)
                .setView(motivoDialogView)
                .setCancelable(true)
                .create()
            motivoDialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

            for ((i, nome) in nomes.withIndex()) {
                val rb = LayoutInflater.from(this).inflate(R.layout.item_motivo_radio, rgMotivos, false) as RadioButton
                rb.id = android.view.View.generateViewId()
                rb.text = nome
                rb.isChecked = i == motivoSelecionadoIndex
                rb.setOnClickListener {
                    motivoSelecionadoIndex = i
                    tvMotivoSelecionado.text = nome
                    tvMotivoSelecionado.setTextColor(android.graphics.Color.parseColor("#374151"))
                    atualizarBotao()
                    motivoDialog.dismiss()
                }
                rgMotivos.addView(rb)
            }

            btnCancelarMotivo.setOnClickListener { motivoDialog.dismiss() }

            btnConfirmarMotivo.setOnClickListener {
                val selectedId = rgMotivos.checkedRadioButtonId
                if (selectedId != -1) {
                    val rb = motivoDialogView.findViewById<RadioButton>(selectedId)
                    val index = nomes.indexOf(rb.text.toString())
                    motivoSelecionadoIndex = index
                    tvMotivoSelecionado.text = nomes[index]
                    tvMotivoSelecionado.setTextColor(android.graphics.Color.parseColor("#374151"))
                    atualizarBotao()
                }
                motivoDialog.dismiss()
            }

            motivoDialog.show()
        }

        etObservacao.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) { atualizarBotao() }
        })

        cbRecaptcha.setOnCheckedChangeListener { _, isChecked ->
            if (atualizandoViaCodigo) return@setOnCheckedChangeListener
            if (isChecked) {
                if (!captchaObtido) {
                    atualizandoViaCodigo = true
                    cbRecaptcha.isChecked = false
                    atualizandoViaCodigo = false
                    RecaptchaManager.showRecaptchaDialog(
                        this,
                        onError = { msg -> toastLong(msg) }
                    ) { token ->
                        captchaObtido = true
                        atualizandoViaCodigo = true
                        cbRecaptcha.isChecked = true
                        atualizandoViaCodigo = false
                        atualizarBotao()
                    }
                }
            } else {
                captchaObtido = false
            }
            atualizarBotao()
        }

        layoutRecaptcha.setOnClickListener {
            cbRecaptcha.isChecked = !cbRecaptcha.isChecked
        }

        Log.d(TAG, "tokenInsucessoExistente: '$tokenInsucessoExistente'")

        val dialog = AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(true)
            .create()
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        btnCancelar.setOnClickListener { dialog.dismiss() }

        // Mostrar token existente se disponível
        if (!tokenInsucessoExistente.isNullOrBlank()) {
            Log.d(TAG, "Mostrando token insucesso existente: ${tokenInsucessoExistente.trim()}")
            tvTokenInsucessoGrande.text = tokenInsucessoExistente.trim()
            tvTokenInsucessoGrande.visibility = View.VISIBLE
        } else {
            Log.d(TAG, "Nenhum token insucesso existente para exibir")
        }

        btnConfirmar.setOnClickListener {
            if (!btnConfirmar.isEnabled || processando) {
                val faltando = mutableListOf<String>()
                if (motivoSelecionadoIndex < 0) faltando.add("motivo")
                if (etObservacao.text.toString().trim().isEmpty()) faltando.add("observação")
                if (!captchaObtido) faltando.add("reCAPTCHA")
                toast("Preencha: ${faltando.joinToString(", ")}")
                return@setOnClickListener
            }
            processando = true
            btnConfirmar.isEnabled = false
            btnConfirmar.alpha = 0.5f
            btnConfirmar.text = "AGUARDE..."

            val position = motivoSelecionadoIndex
            val motivo = motivos[position]
            val observacao = etObservacao.text.toString()
            val recaptchaToken = RecaptchaManager.getToken() ?: ""

            if (recaptchaToken.isEmpty()) {
                this.toast("Erro: Token de segurança não obtido")
                processando = false
                atualizarBotao()
                return@setOnClickListener
            }

            val origem = pedido.origem ?: "SHIP_FROM_STORE"
            val codigoExterno = toStringSafe(pedido.codigoExterno)

            viewModel.devolverPedido(origem, codigoExterno, motivo.id, motivo.nome, observacao, recaptchaToken) { isSuccess, tokenInsucesso ->
                if (isSuccess && !tokenInsucesso.isNullOrEmpty()) {
                    tvTokenInsucessoGrande.text = tokenInsucesso.trim()
                    tvTokenInsucessoGrande.visibility = View.VISIBLE

                    btnConfirmar.text = "FECHAR"
                    btnConfirmar.setBackgroundResource(R.drawable.bg_badge_red)
                    btnConfirmar.isEnabled = true
                    btnConfirmar.alpha = 1f
                    processando = false
                    btnConfirmar.setOnClickListener { dialog.dismiss() }
                } else {
                    processando = false
                    atualizarBotao()
                    btnConfirmar.text = "CONFIRMAR"
                    if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                    else this.toastLong("Erro ao registrar devolução")
                }
            }
        }

        dialog.show()
        dialog.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.92).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    private fun mostrarDialogTokenInsucesso(
        token: String,
        pedido: Pedido,
        isRetirada: Boolean = false,
        isFluxoInverso: Boolean = false,
        onConfirm: (() -> Unit)? = null
    ) {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_token_insucesso, null)
        val tvToken = dialogView.findViewById<TextView>(R.id.tvTokenInsucesso)
        val tvInstrucao = dialogView.findViewById<TextView>(R.id.tvInstrucao)
        val btnFechar = dialogView.findViewById<TextView>(R.id.btnFechar)
        val btnConfirmarRetirada = dialogView.findViewById<TextView>(R.id.btnConfirmarRetirada)

        val imgStatusValidacao = dialogView.findViewById<ImageView>(R.id.imgStatusValidacao)
        val tvStatusValidacaoDetalhe = dialogView.findViewById<TextView>(R.id.tvStatusValidacaoDetalhe)
        val imgStatusLiberado = dialogView.findViewById<ImageView>(R.id.imgStatusLiberado)
        val tvStatusLiberadoDetalhe = dialogView.findViewById<TextView>(R.id.tvStatusLiberadoDetalhe)
        val layoutAjudaHeader = dialogView.findViewById<View>(R.id.layoutAjudaHeader)
        val layoutAjudaBody = dialogView.findViewById<View>(R.id.layoutAjudaBody)
        val imgSetaAjuda = dialogView.findViewById<ImageView>(R.id.imgSetaAjuda)

        tvToken.text = token

        fun iniciarGirarSpinners() {
            imgStatusValidacao.startAnimation(
                android.view.animation.AnimationUtils.loadAnimation(this, R.anim.rotate_loading)
            )
            imgStatusLiberado.startAnimation(
                android.view.animation.AnimationUtils.loadAnimation(this, R.anim.rotate_loading)
            )
        }

        fun marcarValidacaoOk() {
            imgStatusValidacao.clearAnimation()
            imgStatusValidacao.setImageResource(R.drawable.ic_check_circle)
            tvStatusValidacaoDetalhe.text = "Entregador validou o código"
        }

        fun marcarLiberadoOk() {
            imgStatusLiberado.clearAnimation()
            imgStatusLiberado.setImageResource(R.drawable.ic_check_circle)
            tvStatusLiberadoDetalhe.text = "Pedido liberado para entrega"
        }

        fun ativarBotaoConfirmar() {
            btnConfirmarRetirada.background = ContextCompat.getDrawable(this, R.drawable.bg_btn_confirm_enabled)
            btnConfirmarRetirada.setTextColor(ContextCompat.getColor(this, android.R.color.white))
            btnConfirmarRetirada.isEnabled = true
            btnConfirmarRetirada.isClickable = true
            btnConfirmarRetirada.isFocusable = true
        }

        var ajudaLiberado = false
        layoutAjudaHeader.setOnClickListener {
            ajudaLiberado = !ajudaLiberado
            layoutAjudaBody.visibility = if (ajudaLiberado) View.VISIBLE else View.GONE
            imgSetaAjuda.setImageResource(if (ajudaLiberado) R.drawable.ic_arrow_up else R.drawable.ic_arrow_down)
        }

        val dialog = AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(false)
            .create()

        fun iniciarAnimacaoConfirmacao() {
            iniciarGirarSpinners()
            // Etapa 1 (validação): ~2s
            dialogView.postDelayed({
                marcarValidacaoOk()
            }, 2000)
            // Etapa 2 (liberação + botão verde): ~4s
            dialogView.postDelayed({
                marcarLiberadoOk()
                ativarBotaoConfirmar()
            }, 4000)
        }

        fun habilitarConfirmacaoRetirada() {
            btnFechar.text = "CANCELAR"
            btnFechar.background = ContextCompat.getDrawable(this, R.drawable.bg_btn_close_outline)
            btnFechar.visibility = View.VISIBLE
            btnFechar.setOnClickListener { dialog.dismiss() }

            btnConfirmarRetirada.visibility = View.VISIBLE
            btnConfirmarRetirada.setOnClickListener {
                dialog.dismiss()
                pollingConfirmacaoJob?.cancel()
                pollingConfirmacaoJob = null
                onConfirm?.invoke()
            }
            btnConfirmarRetiradaDialog = btnConfirmarRetirada
        }

        if (isRetirada && isFluxoInverso) {
            tvInstrucao.text = "Informe o código para o entregador e aguarde a validação para liberar o pedido."
            habilitarConfirmacaoRetirada()
            iniciarAnimacaoConfirmacao()
        } else if (isRetirada) {
            tvInstrucao.text = "Informe o código para o entregador e aguarde a validação para liberar o pedido."
            habilitarConfirmacaoRetirada()
            marcarValidacaoOk()
            marcarLiberadoOk()
            ativarBotaoConfirmar()
        } else {
            tvInstrucao.text = "Token de insucesso gerado!\n\n" +
                               "📍 INFORME AO ENTREGADOR:\n" +
                               "1. Copie este token\n" +
                               "2. Entregue ao entregador\n" +
                               "3. Ele deve inserir no app dele\n" +
                               "4. Após inserir, o pedido será finalizado"
            btnFechar.visibility = View.VISIBLE
            btnConfirmarRetirada.visibility = View.GONE
            btnFechar.setOnClickListener {
                dialog.dismiss()
                pollingConfirmacaoJob?.cancel()
                pollingConfirmacaoJob = null
                finish()
            }
        }

        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
        dialog.setOnDismissListener {
            pollingConfirmacaoJob?.cancel()
            pollingConfirmacaoJob = null
        }
        dialog.show()
    }

    // ============================================
    // RETORNAR PARA ESTOQUE
    // ============================================

    private fun mostrarDialogDevolverEstoque(pedido: Pedido) {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_confirmar_devolver_estoque, null)
        val tvNumero = dialogView.findViewById<TextView>(R.id.tvDialogNumeroPedido)
        val btnNao = dialogView.findViewById<TextView>(R.id.btnNao)
        val btnSim = dialogView.findViewById<TextView>(R.id.btnSim)

        tvNumero.text = "N° do Pedido: ${toStringSafe(pedido.codigoExterno)}"

        val dialog = AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(true)
            .create()

        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        btnNao.setOnClickListener { dialog.dismiss() }

        btnSim.setOnClickListener {
            dialog.dismiss()
            mostrarLoading(true, "Devolvendo ao estoque...")
            val origem = toStringSafe(pedido.origem)
            val codigoExterno = toStringSafe(pedido.codigoExterno)
            val body = mapOf<String, Any?>(
                "editado" to null,
                "recusado" to null,
                "retry" to false
            )
            viewModel.retornarParaEstoque(origem, codigoExterno, body) { isSuccess ->
                mostrarLoading(false)
                if (isSuccess) {
                    this.toast("✅ Pedido devolvido ao estoque!")
                    finish()
                } else {
                    if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                    else this.toast("❌ Erro ao devolver")
                }
            }
        }

        dialog.show()
        dialog.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.85).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    private fun retornarParaEstoque(pedido: Pedido) {
        mostrarLoading(true, "Carregando...")
        viewModel.getDeliveryTokens(pedido.numero) { tokenRetirada, tokenInsucesso, isSuccess ->
            mostrarLoading(false)
            if (isSuccess && !tokenRetirada.isNullOrEmpty()) {
                mostrarDialogTokenInsucesso(tokenRetirada, pedido)
            } else {
                mostrarDialogRetornarEstoque(pedido)
            }
        }
    }

    private fun mostrarDialogRetornarEstoque(pedido: Pedido) {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_retornar_estoque, null)
        val etMotivo = dialogView.findViewById<EditText>(R.id.etMotivoRetorno)
        val cbRecaptcha = dialogView.findViewById<CheckBox>(R.id.cbRetornoRecaptcha)
        val btnNao = dialogView.findViewById<Button>(R.id.btnNaoRetornar)
        val btnSim = dialogView.findViewById<Button>(R.id.btnSimRetornar)

        var captchaObtido = false
        var atualizandoViaCodigo = false

        fun validar() {
            val motivoOk = etMotivo.text.toString().trim().isNotEmpty()
            btnSim.isEnabled = motivoOk && captchaObtido && cbRecaptcha.isChecked
            btnSim.alpha = if (btnSim.isEnabled) 1f else 0.5f
        }

        etMotivo.addTextChangedListener(object : android.text.TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: android.text.Editable?) { validar() }
        })

        cbRecaptcha.setOnCheckedChangeListener { _, isChecked ->
            if (atualizandoViaCodigo) return@setOnCheckedChangeListener
            if (isChecked) {
                if (!captchaObtido) {
                    atualizandoViaCodigo = true
                    cbRecaptcha.isChecked = false
                    atualizandoViaCodigo = false
                    RecaptchaManager.showRecaptchaDialog(
                        this,
                        onError = { msg -> toastLong(msg) }
                    ) { token ->
                        captchaObtido = true
                        atualizandoViaCodigo = true
                        cbRecaptcha.isChecked = true
                        atualizandoViaCodigo = false
                        validar()
                    }
                }
            } else {
                captchaObtido = false
            }
            validar()
        }

        val dialog = AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(false)
            .create()

        btnNao.setOnClickListener { dialog.dismiss() }

        btnSim.setOnClickListener {
            if (!btnSim.isEnabled) return@setOnClickListener
            dialog.dismiss()
            val token = RecaptchaManager.getToken()
            if (token != null) {
                executarRetornarParaEstoque(pedido, token)
            }
        }

        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
        dialog.show()
        dialog.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.92).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    private fun executarRetornarParaEstoque(pedido: Pedido, captchaToken: String) {
        mostrarLoading(true, "Devolvendo ao estoque...")
        val origem = toStringSafe(pedido.origem)
        val codigoExterno = toStringSafe(pedido.codigoExterno)

        viewModel.retornarParaEstoque(origem, codigoExterno, captchaToken) { isSuccess ->
            mostrarLoading(false)
            if (isSuccess) {
                this.toast("✅ Pedido devolvido ao estoque!")
                finish()
            } else {
                if (viewModel.getToken().isNullOrEmpty()) redirectToLogin()
                else this.toast("❌ Erro ao devolver")
            }
        }
    }

    // ============================================
    // FUNÇÕES DE CONFIRMAÇÃO DE PEDIDO
    // ============================================

    private fun carregarMotivosConfirmacao(
        pedido: Pedido,
        quantidadesEditadas: Map<String, Int>,
        imeisEditados: Map<String, List<String>>,
        captchaToken: String = ""
    ) {
        mostrarLoading(true, "Carregando motivos...")
        val origem = toStringSafe(pedido.origem).ifEmpty { "SHIP_FROM_STORE" }
        val status = toStringSafe(pedido.status)

        viewModel.carregarMotivosRecusa(origem, status) { motivos, isSuccess ->
            mostrarLoading(false)
            if (isSuccess && motivos != null && motivos.isNotEmpty()) {
                mostrarDialogoSelecaoMotivo(pedido, motivos, quantidadesEditadas, imeisEditados, captchaToken)
            } else {
                executarConfirmacaoPedido(pedido, quantidadesEditadas, imeisEditados, null, captchaToken)
            }
        }
    }

    private fun mostrarDialogoSelecaoMotivo(
        pedido: Pedido,
        motivos: List<RecusaMotivo>,
        quantidadesEditadas: Map<String, Int>,
        imeisEditados: Map<String, List<String>>,
        captchaToken: String
    ) {
        if (motivos.isEmpty()) {
            executarConfirmacaoPedido(pedido, quantidadesEditadas, imeisEditados, null, captchaToken)
            return
        }

        val totalItens = quantidadesEditadas.values.sum()

        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_confirmacao_parcial, null)
        val layoutMotivos = dialogView.findViewById<LinearLayout>(R.id.layoutMotivos)
        val btnSim = dialogView.findViewById<Button>(R.id.btnSim)
        val btnFechar = dialogView.findViewById<TextView>(R.id.btnFechar)
        val btnBack = dialogView.findViewById<TextView>(R.id.btnBack)
        val tvTitulo = dialogView.findViewById<TextView>(R.id.tvTituloParcial)

        tvTitulo.text = "Confirmação Parcial de $totalItens itens. Selecione o motivo para o(s) produto(s) recusado(s):"

        var motivoSelecionado: RecusaMotivo? = null
        var subItemSelecionado: RecusaSubItem? = null

        fun atualizarBotaoSim() {
            val habilitado = motivoSelecionado != null
            btnSim.isEnabled = habilitado
            btnSim.backgroundTintList = null
            btnSim.setTextColor(ContextCompat.getColor(this@DetalhesPedidoActivity,
                if (habilitado) android.R.color.white else R.color.btn_disabled_text
            ))
            btnSim.background = ContextCompat.getDrawable(
                this@DetalhesPedidoActivity,
                if (habilitado) R.drawable.bg_btn_confirm_enabled else R.drawable.bg_btn_disabled
            )
        }

        btnSim.isEnabled = false
        btnSim.backgroundTintList = null
        btnSim.setTextColor(ContextCompat.getColor(this@DetalhesPedidoActivity, R.color.btn_disabled_text))
        btnSim.background = ContextCompat.getDrawable(this@DetalhesPedidoActivity, R.drawable.bg_btn_disabled)

        fun resetAllSelections() {
            for (i in 0 until layoutMotivos.childCount) {
                val child = layoutMotivos.getChildAt(i)
                if (child is ViewGroup) {
                    val radio = child.findViewById<View>(R.id.viewRadioCircle)
                    if (radio != null) {
                        radio.setBackgroundResource(R.drawable.bg_radio_unselected)
                    }
                    val submenu = child.findViewById<LinearLayout>(R.id.layoutSubmenu)
                    if (submenu != null) {
                        for (j in 0 until submenu.childCount) {
                            val subChild = submenu.getChildAt(j)
                            subChild.isSelected = false
                            subChild.findViewById<View>(R.id.viewRadioCircle)?.setBackgroundResource(R.drawable.bg_radio_unselected)
                        }
                    }
                }
            }
        }

        layoutMotivos.removeAllViews()

        for (motivo in motivos) {
            if (motivo.subItems.isNullOrEmpty()) {
                val itemView = LayoutInflater.from(this).inflate(R.layout.item_motivo_opcao, layoutMotivos, false)
                val tvMotivo = itemView.findViewById<TextView>(R.id.tvMotivoOpcao)
                val viewRadio = itemView.findViewById<View>(R.id.viewRadioCircle)

                tvMotivo.text = motivo.description

                itemView.setOnClickListener {
                    resetAllSelections()
                    viewRadio.setBackgroundResource(R.drawable.bg_radio_selected)
                    motivoSelecionado = motivo
                    subItemSelecionado = null
                    atualizarBotaoSim()
                }

                layoutMotivos.addView(itemView)

                // divider
                val divider = View(this)
                divider.layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, 1
                )
                divider.setBackgroundColor(ContextCompat.getColor(this, R.color.divider_color))
                layoutMotivos.addView(divider)

            } else {
                val groupView = LayoutInflater.from(this).inflate(R.layout.item_motivo_grupo, layoutMotivos, false)
                val tvGroupTitle = groupView.findViewById<TextView>(R.id.tvGroupTitle)
                val layoutSubmenu = groupView.findViewById<LinearLayout>(R.id.layoutSubmenu)
                val tvToggle = groupView.findViewById<TextView>(R.id.tvToggleIcon)

                tvGroupTitle.text = motivo.description
                layoutSubmenu.visibility = View.GONE
                tvToggle.text = "+"

                var isExpanded = false
                groupView.setOnClickListener {
                    isExpanded = !isExpanded
                    layoutSubmenu.visibility = if (isExpanded) View.VISIBLE else View.GONE
                    tvToggle.text = if (isExpanded) "−" else "+"
                }

                for (subItem in motivo.subItems) {
                    val subView = LayoutInflater.from(this).inflate(R.layout.item_motivo_subitem, layoutSubmenu, false)
                    val tvSubItem = subView.findViewById<TextView>(R.id.tvSubItem)
                    val viewRadio = subView.findViewById<View>(R.id.viewRadioCircle)

                    tvSubItem.text = subItem.description

                    subView.setOnClickListener {
                        resetAllSelections()
                        viewRadio.setBackgroundResource(R.drawable.bg_radio_selected)
                        subItemSelecionado = subItem
                        motivoSelecionado = motivo
                        atualizarBotaoSim()
                    }

                    layoutSubmenu.addView(subView)

                    // divider
                    val divider = View(this)
                    divider.layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT, 1
                    )
                    divider.setBackgroundColor(ContextCompat.getColor(this, R.color.divider_color))
                    layoutSubmenu.addView(divider)
                }

                layoutMotivos.addView(groupView)

                // group divider
                val groupDivider = View(this)
                groupDivider.layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, 1
                )
                groupDivider.setBackgroundColor(ContextCompat.getColor(this, R.color.divider_color))
                layoutMotivos.addView(groupDivider)
            }
        }

        val dialog = BottomSheetDialog(this)
        dialog.setContentView(dialogView)
        dialog.setCancelable(true)

        btnSim.setOnClickListener {
            if (!btnSim.isEnabled) return@setOnClickListener
            dialog.dismiss()
            val codigoMotivo = if (subItemSelecionado != null) subItemSelecionado!!.code else motivoSelecionado?.code
            Log.d(TAG, "Motivo selecionado: subItem=${subItemSelecionado?.code} motivo=${motivoSelecionado?.code} codigoMotivo=$codigoMotivo")
            mostrarDialogConfirmacaoFinal(pedido, quantidadesEditadas, imeisEditados, codigoMotivo, captchaToken)
        }

        btnFechar.setOnClickListener { dialog.dismiss() }
        btnBack.setOnClickListener {
            dialog.dismiss()
            if (itemQuantidadeNovoDialog != null) {
                itemQuantidadeNovoDialog?.reabrir()
            } else {
                smartphoneConfirmacaoDialog?.reabrir()
            }
        }

        dialog.show()
    }

    private fun mostrarDialogConfirmacaoFinal(
        pedido: Pedido,
        quantidades: Map<String, Int>,
        imeisEditados: Map<String, List<String>>,
        motivoCode: String?,
        captchaToken: String
    ) {
        val view = LayoutInflater.from(this).inflate(R.layout.dialog_confirmar_retirada, null)
        val btnSim = view.findViewById<Button>(R.id.btnSim)
        val btnNao = view.findViewById<Button>(R.id.btnNao)

        val builder = AlertDialog.Builder(this)
        builder.setView(view)
        builder.setCancelable(false)

        val dialogConfirm = builder.create()
        dialogConfirm.window?.setBackgroundDrawableResource(android.R.color.transparent)

        btnSim.setOnClickListener {
            dialogConfirm.dismiss()
            executarConfirmacaoPedido(pedido, quantidades, imeisEditados, motivoCode, captchaToken)
        }

        btnNao.setOnClickListener {
            dialogConfirm.dismiss()
        }

        dialogConfirm.show()
        dialogConfirm.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.85).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    private fun executarConfirmacaoPedido(
        pedido: Pedido,
        quantidadesEditadas: Map<String, Int>,
        imeisEditados: Map<String, List<String>>,
        motivoCode: String? = null,
        captchaToken: String = ""
    ) {
        val origem = toStringSafe(pedido.origem).ifEmpty { "SHIP_FROM_STORE" }
        val codigoExterno = toStringSafe(pedido.codigoExterno)
        val numero = toStringSafe(pedido.numero)

        var houveAlteracao = false
        val codigosSapAlterados = mutableListOf<String>()

        val itensAtualizados = pedido.itens?.map { item ->
            val codigoSap = item.codigoSAP ?: ""
            val novaQuantidade = quantidadesEditadas[codigoSap] ?: item.quantidade
            val quantidadeTotal = if (novaQuantidade == 0) 0 else novaQuantidade

            if (novaQuantidade != item.quantidade) {
                houveAlteracao = true
                codigosSapAlterados.add(codigoSap)
            }

            val imeisDigitados = imeisEditados[codigoSap] ?: emptyList()
            val imeisFinal = if (imeisDigitados.isNotEmpty()) {
                listOf(imeisDigitados)
            } else {
                item.imeis ?: emptyList()
            }

            mapOf(
                "codigoEAN" to (item.codigoEAN ?: ""),
                "codigoSAP" to codigoSap,
                "descricao" to (item.descricao ?: ""),
                "quantidade" to item.quantidade,
                "quantidadeTotal" to quantidadeTotal,
                "valorUnitario" to item.valorUnitario,
                "valorTotal" to (item.valorUnitario * quantidadeTotal),
                "estoque" to (item.estoque ?: 0),
                "estoqueInicial" to (item.estoqueInicial ?: 0),
                "precoVenda" to (item.precoVenda ?: 0.0),
                "peso" to (item.peso ?: 0.0),
                "quantidadeImeis" to (if (imeisFinal.isNotEmpty()) imeisFinal.sumOf { it.size } else 0),
                "imeis" to imeisFinal,
                "preVenda" to false
            )
        } ?: emptyList()

        val subtotalItens = itensAtualizados.sumOf {
            (it["valorTotal"] as? Double) ?: 0.0
        }
        val novoValorTotal = subtotalItens - (pedido.valorDesconto ?: 0.0) + (pedido.valorEntrega ?: 0.0)

        val body = mutableMapOf<String, Any?>(
            "valorTotal" to novoValorTotal,
            "valorDesconto" to pedido.valorDesconto,
            "valorEntrega" to pedido.valorEntrega,
            "editado" to houveAlteracao,
            "recusado" to null,
            "retry" to false,
            "itens" to itensAtualizados
        )
        if (motivoCode != null) {
            body["motivo"] = motivoCode
        }
        if (captchaToken.isNotEmpty()) {
            body["captchaToken"] = captchaToken
        }

        if (houveAlteracao) {
            mostrarLoading(true, "Atualizando inventário...")
            // Salvar itens originais localmente pra exibir no histórico
            try {
                val itensJson = com.google.gson.Gson().toJson(pedido.itens)
                SessionManager(this).savePedidoItens(numero, itensJson)
                SessionManager(this).saveEditFlag(numero)
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao salvar itens localmente", e)
            }
            // ✅ Confirmação parcial: atualizar inventário SOMENTE dos itens com erro (alterados/recusados)
            val itensComErro = itensAtualizados.filter { itemMap ->
                codigosSapAlterados.contains((itemMap["codigoSAP"] as? String) ?: "")
            }
            viewModel.updateInventory(numero, itensComErro, novoValorTotal) { inventoryOk ->
                if (!inventoryOk) {
                    mostrarLoading(false)
                    this.toast("Erro ao atualizar inventário")
                    return@updateInventory
                }
                finishConfirmacao(origem, codigoExterno, body, houveAlteracao, motivoCode, codigosSapAlterados)
            }
        } else {
            finishConfirmacao(origem, codigoExterno, body, houveAlteracao, motivoCode, codigosSapAlterados)
        }
    }

    private fun finishConfirmacao(
        origem: String,
        codigoExterno: String,
        body: Map<String, Any?>,
        houveAlteracao: Boolean,
        motivoCode: String?,
        codigosSapAlterados: List<String>
    ) {
        mostrarLoading(true, "Confirmando pedido...")
        val itensQuery = if (codigosSapAlterados.isNotEmpty()) codigosSapAlterados.joinToString(",") else null
        Log.d(TAG, "Confirmando pedido: $body")
        viewModel.confirmarPedido(origem, codigoExterno, houveAlteracao, body, motivoCode, itensQuery) { isSuccess, code, errorBody ->
            mostrarLoading(false)
            if (isSuccess) {
                this.toast("✅ Pedido confirmado! Pronto para sair.")
                // ✅ ATUALIZAR O PEDIDO LOCALMENTE
                pedidoAtual = pedidoAtual?.copy(status = "PRONTO_PARA_SAIR")
                // ✅ ATUALIZAR A UI
                pedidoAtual?.let { exibirDetalhes(it) }
                // ✅ ATUALIZAR O BADGE
                atualizarFab("PRONTO_PARA_SAIR")
            } else {
                if (viewModel.getToken().isNullOrEmpty()) { redirectToLogin(); return@confirmarPedido }
                Log.e(TAG, "Erro ao confirmar pedido: $code - $errorBody")
                this.toastLong("❌ Erro ao confirmar pedido: $code")
            }
        }
    }

    // ============================================
    // FUNÇÕES DE UI
    // ============================================

    private fun mostrarLoading(mostrar: Boolean, status: String? = null) {
        if (mostrar) {
            status?.let { findViewById<TextView>(R.id.tvLoadingStatus)?.text = it }
            layoutLoading.alpha = 0f
            layoutLoading.visibility = View.VISIBLE
            layoutLoading.animate().alpha(1f).setDuration(200).withEndAction {
                iniciarSkeletonPulse()
            }.start()
            if (layoutConteudo.visibility == View.VISIBLE) {
                layoutConteudo.animate().alpha(0f).setDuration(200).withEndAction {
                    layoutConteudo.visibility = View.GONE
                }.start()
            }
        } else {
            layoutConteudo.alpha = 0f
            layoutConteudo.visibility = View.VISIBLE
            layoutConteudo.animate().alpha(1f).setDuration(200).start()
            layoutLoading.animate().alpha(0f).setDuration(200).withEndAction {
                layoutLoading.visibility = View.GONE
                pararSkeletonPulse()
            }.start()
            scrollViewContent.post { scrollViewContent.smoothScrollTo(0, 0) }
        }
    }

    private var skeletonAnimator: android.animation.ValueAnimator? = null

    private fun iniciarSkeletonPulse() {
        val skeleton = findViewById<View>(R.id.layoutSkeleton) ?: return
        skeletonAnimator?.cancel()
        val animator = android.animation.ValueAnimator.ofFloat(0.4f, 1f)
        animator.duration = 800
        animator.repeatMode = android.animation.ValueAnimator.REVERSE
        animator.repeatCount = android.animation.ValueAnimator.INFINITE
        animator.addUpdateListener { skeleton.alpha = it.animatedValue as Float }
        animator.start()
        skeletonAnimator = animator
    }

    private fun pararSkeletonPulse() {
        skeletonAnimator?.cancel()
        skeletonAnimator = null
        findViewById<View>(R.id.layoutSkeleton)?.alpha = 1f
    }

    private fun redirectToLogin() {
        val intent = Intent(this, LoginActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
        finish()
    }
}