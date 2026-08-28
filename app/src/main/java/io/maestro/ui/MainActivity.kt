// app/src/main/java/io/maestro/ui/MainActivity.kt
package io.maestro.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PorterDuff
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.HorizontalScrollView
import android.app.Activity
import android.app.Dialog
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatEditText
import androidx.cardview.widget.CardView
import androidx.core.content.ContextCompat
import com.google.android.material.bottomsheet.BottomSheetDialog
import androidx.recyclerview.widget.ItemTouchHelper
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import io.maestro.R
import io.maestro.adapters.PedidoAdapter
import io.maestro.network.ApiClient
import io.maestro.network.SessionManager
import io.maestro.network.models.Pedido
import io.maestro.utils.toast
import io.maestro.utils.toastLong
import io.maestro.utils.Colors
import io.maestro.utils.Constants
import io.maestro.utils.SessionExpiredHandler
import io.maestro.workers.PedidoPollingWorker
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import retrofit2.HttpException
import java.io.IOException

class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "MainActivity"
    }

    private enum class ModalityFilter {
        ALL, PEGUE_NA_LOJA, DELIVERY, IFOOD, CANCELADO, DEVOLVIDO
    }

    private lateinit var sessionManager: SessionManager
    private lateinit var apiService: io.maestro.network.ApiService
    private lateinit var adapter: PedidoAdapter
    
    // Views - Header
    private lateinit var cardHeader: CardView
    
    // Navegação inferior (tabs)
    private lateinit var tabNovo: View
    private var corHeaderAtual: Int = R.color.btn_novo
    private lateinit var tabSeparacao: View
    private lateinit var tabRetirada: View
    private lateinit var tabEntrega: View
    private lateinit var tabEstoque: View
    private lateinit var tabHistorico: View
    
    // Quantidades (badges)
    private lateinit var tvQtdNovo: TextView
    private lateinit var tvQtdSeparacao: TextView
    private lateinit var tvQtdPronto: TextView
    private lateinit var tvQtdEntrega: TextView
    private lateinit var tvQtdEstoque: TextView
    private lateinit var tvQtdHistorico: TextView
    
    // Labels
    private lateinit var tvLabelNovo: TextView
    private lateinit var tvLabelSeparacao: TextView
    private lateinit var tvLabelRetirada: TextView
    private lateinit var tvLabelEntrega: TextView
    private lateinit var tvLabelEstoque: TextView
    private lateinit var tvLabelHistorico: TextView
    
    // Ícones
    private lateinit var imgIconNovo: ImageView
    private lateinit var imgIconSeparacao: ImageView
    private lateinit var imgIconRetirada: ImageView
    private lateinit var imgIconEntrega: ImageView
    private lateinit var imgIconEstoque: ImageView
    private lateinit var imgIconHistorico: ImageView
    
    // Header
    private lateinit var imgLogo: ImageView
    private lateinit var btnProfile: ImageButton
    
    // Status bar
    private lateinit var tvNovosCount: TextView
    private lateinit var btnFiltrar: TextView
    private lateinit var tvSubtitle: TextView

    // Tabs da aba PRONTO PARA RETIRADA
    private lateinit var layoutTabsRetirada: HorizontalScrollView
    private lateinit var tabRetiradaGeral: TextView
    private lateinit var tabRetiradaColetaTardia: TextView
    private lateinit var tabRetiradaEmAnalise: TextView
    private lateinit var tabRetiradaParado3Dias: TextView

    // Busca e filtros da aba PRONTO PARA RETIRADA
    private lateinit var layoutBuscaRetirada: LinearLayout
    private lateinit var etBuscaRetirada: EditText
    private lateinit var spinnerCanalRetirada: Spinner
    private lateinit var spinnerOrigemRetirada: Spinner
    private var buscaRetiradaTexto: String = ""
    private var filtroCanalRetirada: String? = null // null = todos, "AMERICANAS", "IFOOD", "MAGALU", "SHOPEE"
    private var filtroOrigemRetirada: String? = null // null = todos, "DELIVERY", "PEGUE_LOJA"
    
    // Lista
    private lateinit var rvPedidos: RecyclerView
    private lateinit var layoutLoading: View
    private lateinit var layoutEmpty: View
    private lateinit var tvEmptyTitle: TextView
    private lateinit var imgEmptyIllustration: ImageView

    private lateinit var swipeRefreshLayout: SwipeRefreshLayout

    // Histórico
    private lateinit var layoutHistorico: View
    private lateinit var etBuscarHistorico: AppCompatEditText
    private lateinit var btnLimparBusca: ImageButton
    private lateinit var rvHistorico: RecyclerView
    private lateinit var layoutHistoricoLoading: View
    private lateinit var layoutHistoricoEmpty: View
    private lateinit var tvHistoricoEmptyMessage: TextView
    private lateinit var btnFiltroTodos: TextView
    private lateinit var btnFiltroPegueLoja2: TextView
    private lateinit var btnFiltroDelivery: TextView
    private lateinit var btnFiltroIfood2: TextView
    private lateinit var btnFiltroCancelado: TextView
    private lateinit var btnFiltroDevolvido: TextView
    private lateinit var historicoAdapter: PedidoAdapter
    private var historicoAllItems = mutableListOf<Pedido>()
    private var historicoCurrentPage = 0
    private var historicoIsLoading = false
    private var historicoIsLastPage = false
    private var historicoTotalPedidos = 0
    private var historicoSearchQuery = ""
    private var historicoSelectedFilter = ModalityFilter.ALL
    private var historicoLoadingFilter: ModalityFilter? = null
    private val historicoLimit = 100
    private val historicoCountsMap = mutableMapOf<String, Int>()
    
    private var currentStatus = Constants.STATUS_NOVO
    private var currentPage = 0
    private var isLoading = false
    private var isLastPage = false
    private var loadRequestId = 0
    private var filterSearch = ""
    private var filterMinDias = 0
    private var filterOrigem = ""
    private var filterAbaRetirada: String? = null // null = GERAL, "COLETA_TARDIA", "EM_ANALISE", "PARADO_3_DIAS"
    private val limit = 20

    private var countNovo = 0
    private var countSeparacao = 0
    private var countPronto = 0
    private var countEntrega = 0
    private var countEstoque = 0
    private var countHistorico = 0
    
    private val tabs = mutableListOf<View>()
    private val qtds = mutableListOf<TextView>()
    private var tabSelecionadaAtual: View? = null
    
    private val allItems = mutableListOf<Pedido>()
    
    private lateinit var statusMap: Map<View, String>

    private val searchHandler = Handler(Looper.getMainLooper())
    private val searchRunnable = Runnable { loadHistorico(reset = true) }

    private data class CountsCache(
        val novo: Int, val separacao: Int, val pronto: Int,
        val entrega: Int, val estoque: Int, val historico: Int,
        val timestamp: Long
    )
    private var countsCache: CountsCache? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "=== MAINACTIVITY ONCREATE INICIADO ===")
        
        try {
            setContentView(R.layout.activity_main)
            Log.d(TAG, "setContentView OK")
            
            // ========== STATUS BAR ==========
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    window.decorView.systemUiVisibility = 0
                }
            }
            // =================================

            sessionManager = SessionManager(this)
            Log.d(TAG, "SessionManager criado")
            
            if (!sessionManager.isLoggedIn()) {
                Log.d(TAG, "Usuário NÃO logado, redirecionando")
                redirectToLogin()
                return
            }
            
            val token = sessionManager.getToken()
            if (token.isNullOrEmpty()) {
                Log.d(TAG, "Token vazio, redirecionando")
                redirectToLogin()
                return
            }
            Log.d(TAG, "Token encontrado: ${token.take(30)}...")

            apiService = ApiClient.getInstance(this).getApiService()
            Log.d(TAG, "ApiService criado")

            // Iniciar notificações de novos pedidos
            PedidoPollingWorker.iniciar(this)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1002)
                }
            }

            initViews()
            Log.d(TAG, "initViews OK")
            
            statusMap = mapOf(
                tabNovo to Constants.STATUS_NOVO,
                tabSeparacao to Constants.STATUS_EM_SEPARACAO,
                tabRetirada to Constants.STATUS_PRONTO_PARA_SAIR,
                tabEntrega to Constants.STATUS_SAIU_PARA_ENTREGA,
                tabEstoque to Constants.STATUS_RETORNAR_ESTOQUE,
                tabHistorico to Constants.STATUS_HISTORICO
            )
            Log.d(TAG, "statusMap OK")
            
            setupSwipeRefresh()
            Log.d(TAG, "setupSwipeRefresh OK")
            
            setupListeners()
            Log.d(TAG, "setupListeners OK")
            
            selecionarTab(tabNovo)
            atualizarTituloAba()
            tvSubtitle.text = "O ideal é sempre entregar até o prazo estimado para o cliente"
            tvSubtitle.visibility = View.VISIBLE
            
            setupRecyclerView()
            Log.d(TAG, "setupRecyclerView OK")
            setupHistoricoRecyclerView()
            Log.d(TAG, "setupHistoricoRecyclerView OK")

            lifecycleScope.launch {
                while (isActive) {
                    adapter.tick()
                    if (::historicoAdapter.isInitialized) historicoAdapter.tick()
                    delay(1000)
                }
            }

            carregarCounts()
            loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
            
            Log.d(TAG, "=== MAINACTIVITY ONCREATE FINALIZADO ===")

        } catch (e: Exception) {
            Log.e(TAG, "ERRO no onCreate", e)
            this.toastLong("Erro ao iniciar: ${e.message}")
            redirectToLogin()
        }
    }

    override fun onResume() {
        super.onResume()
        carregarCounts()
        if (::adapter.isInitialized) {
            loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1002 && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            Log.d(TAG, "Permissão de notificação concedida")
        }
    }

    private fun initViews() {
        try {
            cardHeader = findViewById(R.id.cardHeader)
            
            imgLogo = findViewById(R.id.imgLogo)
            btnProfile = findViewById(R.id.btnProfile)
            
            tvNovosCount = findViewById(R.id.tvNovosCount)
            tvSubtitle = findViewById(R.id.tvSubtitle)
            btnFiltrar = findViewById(R.id.btnFiltrar)

            layoutTabsRetirada = findViewById(R.id.layoutTabsRetirada)
            tabRetiradaGeral = findViewById(R.id.tabRetiradaGeral)
            tabRetiradaColetaTardia = findViewById(R.id.tabRetiradaColetaTardia)
            tabRetiradaEmAnalise = findViewById(R.id.tabRetiradaEmAnalise)
            tabRetiradaParado3Dias = findViewById(R.id.tabRetiradaParado3Dias)

            layoutBuscaRetirada = findViewById(R.id.layoutBuscaRetirada)
            etBuscaRetirada = findViewById(R.id.etBuscaRetirada)
            spinnerCanalRetirada = findViewById(R.id.spinnerCanalRetirada)
            spinnerOrigemRetirada = findViewById(R.id.spinnerOrigemRetirada)

            val opcoesCanal = listOf("Canal de Venda", "Americanas", "iFood", "Magalu", "Shopee")
            val opcoesOrigem = listOf("Origem", "Delivery", "Pegue na Loja Hoje")
            spinnerCanalRetirada.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, opcoesCanal).apply {
                setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            }
            spinnerOrigemRetirada.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, opcoesOrigem).apply {
                setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            }
            
            tabNovo = findViewById(R.id.tabNovo)
            tabSeparacao = findViewById(R.id.tabSeparacao)
            tabRetirada = findViewById(R.id.tabRetirada)
            tabEntrega = findViewById(R.id.tabEntrega)
            tabEstoque = findViewById(R.id.tabEstoque)
            tabHistorico = findViewById(R.id.tabHistorico)
            
            tvQtdNovo = findViewById(R.id.tvQtdNovo)
            tvQtdSeparacao = findViewById(R.id.tvQtdSeparacao)
            tvQtdPronto = findViewById(R.id.tvQtdPronto)
            tvQtdEntrega = findViewById(R.id.tvQtdEntrega)
            tvQtdEstoque = findViewById(R.id.tvQtdEstoque)
            tvQtdHistorico = findViewById(R.id.tvQtdHistorico)
            
            tvLabelNovo = findViewById(R.id.tvLabelNovo)
            tvLabelSeparacao = findViewById(R.id.tvLabelSeparacao)
            tvLabelRetirada = findViewById(R.id.tvLabelRetirada)
            tvLabelEntrega = findViewById(R.id.tvLabelEntrega)
            tvLabelEstoque = findViewById(R.id.tvLabelEstoque)
            tvLabelHistorico = findViewById(R.id.tvLabelHistorico)
            
            imgIconNovo = findViewById(R.id.imgIconNovo)
            imgIconSeparacao = findViewById(R.id.imgIconSeparacao)
            imgIconRetirada = findViewById(R.id.imgIconRetirada)
            imgIconEntrega = findViewById(R.id.imgIconEntrega)
            imgIconEstoque = findViewById(R.id.imgIconEstoque)
            imgIconHistorico = findViewById(R.id.imgIconHistorico)
            
            rvPedidos = findViewById(R.id.rvPedidos)
            swipeRefreshLayout = findViewById(R.id.swipeRefreshLayout)
            
            layoutLoading = findViewById(R.id.layoutLoading)
            layoutEmpty = findViewById(R.id.layoutEmpty)
            tvEmptyTitle = findViewById(R.id.tvEmptyTitle)
            imgEmptyIllustration = findViewById(R.id.imgEmptyIllustration)

            // Histórico
            layoutHistorico = findViewById(R.id.layoutHistorico)
            etBuscarHistorico = findViewById(R.id.etBuscarHistorico)
            btnLimparBusca = findViewById(R.id.btnLimparBusca)
            rvHistorico = findViewById(R.id.rvHistorico)
            layoutHistoricoLoading = findViewById(R.id.layoutHistoricoLoading)
            layoutHistoricoEmpty = findViewById(R.id.layoutHistoricoEmpty)
            tvHistoricoEmptyMessage = findViewById(R.id.tvHistoricoEmptyMessage)
            btnFiltroTodos = findViewById(R.id.btnFiltroTodos)
            btnFiltroPegueLoja2 = findViewById(R.id.btnFiltroPegueLoja)
            btnFiltroDelivery = findViewById(R.id.btnFiltroDelivery)
            btnFiltroIfood2 = findViewById(R.id.btnFiltroIfood)
            btnFiltroCancelado = findViewById(R.id.btnFiltroCancelado)
            btnFiltroDevolvido = findViewById(R.id.btnFiltroDevolvido)
            
            tabs.addAll(listOf(
                tabNovo, tabSeparacao, tabRetirada, tabEntrega, tabEstoque, tabHistorico
            ))
            
            qtds.addAll(listOf(
                tvQtdNovo, tvQtdSeparacao, tvQtdPronto, tvQtdEntrega, tvQtdEstoque, tvQtdHistorico
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "initViews ERRO", e)
            throw e
        }
    }

    private fun setupListeners() {
        try {
            val tabSubtitleMap = mapOf(
                tabNovo to "O ideal é sempre entregar até o prazo estimado para o cliente",
                tabSeparacao to "Sempre confira os itens antes de confirmar o pedido.",
                tabRetirada to "Aguardando o cliente/entregador para coleta do pedido.",
                tabEntrega to "Saiba onde o entregador está em tempo real. Algumas não são rastreáveis.",
                tabEstoque to "Pedidos cujos itens precisam ser retornados ao estoque."
            )

            tabs.forEach { tab ->
                tab.setOnClickListener {
                    swipeRefreshLayout.isEnabled = tab == tabNovo
                    try {
                        if (tab == tabHistorico) {
                            swipeRefreshLayout.visibility = View.GONE
                            layoutLoading.visibility = View.GONE
                            layoutEmpty.visibility = View.GONE
                            layoutHistorico.visibility = View.VISIBLE
                            currentStatus = Constants.STATUS_HISTORICO
                            atualizarTituloAba()
                            tvSubtitle.text = "Os pedidos sempre ficam registrados."
                            tvSubtitle.visibility = View.VISIBLE
                            selecionarTab(tab)
                            carregarCountsHistorico()
                            loadHistorico(reset = true)
                            return@setOnClickListener
                        }
                        layoutHistorico.visibility = View.GONE
                        swipeRefreshLayout.visibility = View.VISIBLE
                        val status = statusMap[tab] ?: Constants.STATUS_NOVO
                        currentStatus = status
                        atualizarTituloAba()
                        tvSubtitle.text = tabSubtitleMap[tab] ?: ""
                        tvSubtitle.visibility = if (tabSubtitleMap[tab] != null) View.VISIBLE else View.GONE
                        selecionarTab(tab)
                        val sort = if (tab == tabRetirada || tab == tabEntrega) "desc" else "asc"
                        loadPedidos(currentStatus, sort, 0, reset = true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Erro ao clicar na tab", e)
                        this.toast("Erro ao carregar pedidos")
                    }
                }
            }

            btnProfile.setOnClickListener {
                mostrarPerfilDialog()
            }

            tabRetiradaGeral.setOnClickListener {
                filterAbaRetirada = null
                atualizarFiltroAbaRetirada()
                loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
            }

            tabRetiradaColetaTardia.setOnClickListener {
                filterAbaRetirada = if (filterAbaRetirada == "COLETA_TARDIA") null else "COLETA_TARDIA"
                atualizarFiltroAbaRetirada()
                loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
            }

            tabRetiradaEmAnalise.setOnClickListener {
                filterAbaRetirada = if (filterAbaRetirada == "EM_ANALISE") null else "EM_ANALISE"
                atualizarFiltroAbaRetirada()
                loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
            }

            tabRetiradaParado3Dias.setOnClickListener {
                filterAbaRetirada = if (filterAbaRetirada == "PARADO_3_DIAS") null else "PARADO_3_DIAS"
                atualizarFiltroAbaRetirada()
                loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
            }

            // Busca da aba PRONTO PARA RETIRADA (por nº do pedido ou cliente)
            etBuscaRetirada.addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                override fun afterTextChanged(s: Editable?) {
                    buscaRetiradaTexto = s.toString().trim()
                    loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
                }
            })

            // Filtro de canal (Americanas, iFood, Magalu, Shopee)
            spinnerCanalRetirada.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                    val selecionado = parent?.getItemAtPosition(position)?.toString() ?: ""
                    filtroCanalRetirada = when {
                        selecionado.contains("Americanas", ignoreCase = true) -> "AMERICANAS"
                        selecionado.contains("iFood", ignoreCase = true) -> "IFOOD"
                        selecionado.contains("Magalu", ignoreCase = true) -> "MAGALU"
                        selecionado.contains("Shopee", ignoreCase = true) -> "SHOPEE"
                        else -> null
                    }
                    loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
                }
                override fun onNothingSelected(parent: AdapterView<*>?) {}
            }

            // Filtro de origem (Delivery, Pegue Na Loja Hoje)
            spinnerOrigemRetirada.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                    val selecionado = parent?.getItemAtPosition(position)?.toString() ?: ""
                    filtroOrigemRetirada = when {
                        selecionado.contains("Delivery", ignoreCase = true) -> "DELIVERY"
                        selecionado.contains("Pegue", ignoreCase = true) -> "PEGUE_LOJA"
                        else -> null
                    }
                    loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
                }
                override fun onNothingSelected(parent: AdapterView<*>?) {}
            }

            // Histórico: busca com debounce
            etBuscarHistorico.addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                override fun afterTextChanged(s: Editable?) {
                    historicoSearchQuery = s.toString()
                    btnLimparBusca.visibility = if (historicoSearchQuery.isNotEmpty()) View.VISIBLE else View.GONE
                    searchHandler.removeCallbacks(searchRunnable)
                    searchHandler.postDelayed(searchRunnable, 400)
                }
            })

            btnLimparBusca.setOnClickListener {
                etBuscarHistorico.text?.clear()
                historicoSearchQuery = ""
                btnLimparBusca.visibility = View.GONE
                loadHistorico(reset = true)
            }

            // Histórico: filtros
            btnFiltroTodos.setOnClickListener { onHistoricoFilterSelected(ModalityFilter.ALL) }
            btnFiltroPegueLoja2.setOnClickListener { onHistoricoFilterSelected(ModalityFilter.PEGUE_NA_LOJA) }
            btnFiltroDelivery.setOnClickListener { onHistoricoFilterSelected(ModalityFilter.DELIVERY) }
            btnFiltroIfood2.setOnClickListener { onHistoricoFilterSelected(ModalityFilter.IFOOD) }
            btnFiltroCancelado.setOnClickListener { onHistoricoFilterSelected(ModalityFilter.CANCELADO) }
            btnFiltroDevolvido.setOnClickListener { onHistoricoFilterSelected(ModalityFilter.DEVOLVIDO) }
            updateHistoricoFilterButtons()

        } catch (e: Exception) {
            Log.e(TAG, "setupListeners ERRO", e)
        }
    }

    private val cachedBadgeDrawables = mutableMapOf<Int, android.graphics.drawable.GradientDrawable>()

    private fun selecionarTab(tabSelecionada: View) {
        try {
            tabSelecionadaAtual = tabSelecionada
            val mapHeaderColor = mapOf(
                tabNovo to R.color.btn_novo,
                tabSeparacao to R.color.btn_separacao,
                tabRetirada to R.color.btn_pronto,
                tabEntrega to R.color.btn_entrega,
                tabEstoque to R.color.btn_estoque,
                tabHistorico to R.color.btn_historico
            )
            val mapCor = mapOf(
                tabNovo to R.color.btn_novo,
                tabSeparacao to R.color.btn_separacao,
                tabRetirada to R.color.btn_pronto,
                tabEntrega to R.color.btn_entrega,
                tabEstoque to R.color.btn_estoque,
                tabHistorico to R.color.btn_historico
            )
            val mapIcon = mapOf(
                tabNovo to imgIconNovo,
                tabSeparacao to imgIconSeparacao,
                tabRetirada to imgIconRetirada,
                tabEntrega to imgIconEntrega,
                tabEstoque to imgIconEstoque,
                tabHistorico to imgIconHistorico
            )
            val mapLabel = mapOf(
                tabNovo to tvLabelNovo,
                tabSeparacao to tvLabelSeparacao,
                tabRetirada to tvLabelRetirada,
                tabEntrega to tvLabelEntrega,
                tabEstoque to tvLabelEstoque,
                tabHistorico to tvLabelHistorico
            )
            val mapQtd = mapOf(
                tabNovo to tvQtdNovo,
                tabSeparacao to tvQtdSeparacao,
                tabRetirada to tvQtdPronto,
                tabEntrega to tvQtdEntrega,
                tabEstoque to tvQtdEstoque,
                tabHistorico to tvQtdHistorico
            )

            val mapQtdBg = mapOf(
                tabNovo to R.drawable.bg_badge_count_green,
                tabSeparacao to R.drawable.bg_badge_count_blue,
                tabRetirada to R.drawable.bg_badge_count_orange,
                tabEntrega to R.drawable.bg_badge_count_purple,
                tabEstoque to R.drawable.bg_badge_count_red,
                tabHistorico to R.drawable.bg_badge_count_gray
            )

            tabs.forEach { tab ->
                val context = this
                val icon = mapIcon[tab]
                val label = mapLabel[tab]
                val qtd = mapQtd[tab]
                val cor = mapCor[tab] ?: R.color.btn_novo
                if (tab == tabSelecionada) {
                    icon?.setColorFilter(ContextCompat.getColor(context, cor), android.graphics.PorterDuff.Mode.SRC_IN)
                    label?.setTextColor(ContextCompat.getColor(context, cor))
                    qtd?.setTextColor(ContextCompat.getColor(context, android.R.color.white))
                    qtd?.background = cachedBadgeDrawables.getOrPut(cor) {
                        android.graphics.drawable.GradientDrawable().apply {
                            shape = android.graphics.drawable.GradientDrawable.OVAL
                            setColor(ContextCompat.getColor(context, cor))
                        }
                    }
                } else {
                    icon?.setColorFilter(ContextCompat.getColor(context, R.color.gray_dark), android.graphics.PorterDuff.Mode.SRC_IN)
                    label?.setTextColor(ContextCompat.getColor(context, R.color.gray_dark))
                    qtd?.setTextColor(ContextCompat.getColor(context, R.color.white))
                    qtd?.background = ContextCompat.getDrawable(context, R.drawable.bg_badge_count_gray)
                }
            }

            val corHeader = mapHeaderColor[tabSelecionada] ?: R.color.btn_novo
            corHeaderAtual = corHeader
            cardHeader.setCardBackgroundColor(ContextCompat.getColor(this, corHeader))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                window.statusBarColor = ContextCompat.getColor(this, corHeader)
            }

            val mapTitleBadge = mapOf(
                tabNovo to R.drawable.bg_badge_title_green,
                tabSeparacao to R.drawable.bg_badge_title_blue,
                tabRetirada to R.drawable.bg_badge_title_orange,
                tabEntrega to R.drawable.bg_badge_title_purple,
                tabEstoque to R.drawable.bg_badge_title_red,
                tabHistorico to R.drawable.bg_badge_title_gray
            )
            tvNovosCount.background = ContextCompat.getDrawable(this, mapTitleBadge[tabSelecionada] ?: R.drawable.bg_badge_title_green)

            // Mostrar busca/filtros apenas na aba RETIRADA
            val isRetirada = tabSelecionada == tabRetirada
            layoutTabsRetirada.visibility = if (isRetirada) View.VISIBLE else View.GONE
            layoutBuscaRetirada.visibility = if (isRetirada) View.VISIBLE else View.GONE
            if (!isRetirada && filterAbaRetirada != null) {
                filterAbaRetirada = null
                atualizarFiltroAbaRetirada()
            }
            if (!isRetirada && (buscaRetiradaTexto.isNotEmpty() || filtroCanalRetirada != null || filtroOrigemRetirada != null)) {
                buscaRetiradaTexto = ""
                filtroCanalRetirada = null
                filtroOrigemRetirada = null
                etBuscaRetirada.setText("")
                spinnerCanalRetirada.setSelection(0)
                spinnerOrigemRetirada.setSelection(0)
            }

            if (layoutEmpty.visibility == View.VISIBLE) {
                atualizarIconeEmptyState()
            }

        } catch (e: Exception) {
            Log.e(TAG, "selecionarTab ERRO", e)
        }
    }

    private fun hideKeyboard() {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager ?: return
        currentFocus?.windowToken?.let { imm.hideSoftInputFromWindow(it, 0) }
    }

    private fun mostrarPerfilDialog() {
        val nome = sessionManager.getUserName() ?: "Usuário"
        val email = sessionManager.getUserEmail() ?: "email@exemplo.com"
        val loja = sessionManager.getUserStore() ?: "-"
        val versao = try {
            packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0"
        } catch (e: Exception) { "1.0" }

        val dialogView = layoutInflater.inflate(R.layout.dialog_perfil, null)
        dialogView.findViewById<TextView>(R.id.tvPerfilNome).text = nome
        dialogView.findViewById<TextView>(R.id.tvPerfilEmail).text = email
        dialogView.findViewById<TextView>(R.id.tvPerfilLoja).text = "Loja $loja"
        dialogView.findViewById<TextView>(R.id.tvPerfilVersao).text = "versão $versao"

        val dialog = Dialog(this)
        dialog.setContentView(dialogView)
        dialog.window?.setLayout(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT
        )
        val statusBarColorOriginal = window.statusBarColor
        val perfilBkgColor = androidx.core.content.ContextCompat.getColor(this, R.color.perfil_bkg)
        dialog.window?.statusBarColor = perfilBkgColor
        dialog.setOnDismissListener { window.statusBarColor = statusBarColorOriginal }

        dialogView.findViewById<View>(R.id.btnPerfilVoltar).setOnClickListener {
            dialog.dismiss()
        }

        val btnPerfilSair = dialogView.findViewById<TextView>(R.id.btnPerfilSair)
        btnPerfilSair.setOnClickListener {
            btnPerfilSair.text = "SAINDO..."
            dialog.dismiss()
            sessionManager.clearTokenKeepUserInfo()
            redirectToLogin()
        }

        dialog.show()
    }

    private fun mostrarFiltroDialog() {
        if (!::btnFiltrar.isInitialized) return
        val dialog = BottomSheetDialog(this)
        val dialogView = layoutInflater.inflate(R.layout.dialog_filter, null)
        dialog.setContentView(dialogView)

        val etSearch = dialogView.findViewById<EditText>(R.id.etFilterSearch)
        etSearch.setText(filterSearch)

        val originChips = listOf(
            dialogView.findViewById<TextView>(R.id.chipOrigemDelivery),
            dialogView.findViewById<TextView>(R.id.chipOrigemPegueHoje)
        )
        val originValues = listOf("Delivery", "Pegue na Loja Hoje")

        fun atualizarChip(chip: TextView, active: Boolean) {
            chip.isSelected = active
            chip.setTextColor(ContextCompat.getColor(this,
                if (active) android.R.color.white else R.color.chip_text
            ))
            chip.background = ContextCompat.getDrawable(this,
                if (active) R.drawable.bg_chip_selected_dark else R.drawable.bg_chip_filter_blue
            )
        }

        originChips.forEachIndexed { i, chip ->
            val origens = filterOrigem.split(",").filter { it.isNotEmpty() }
            atualizarChip(chip, origens.contains(originValues[i]))
            chip.setOnClickListener {
                chip.isSelected = !chip.isSelected
                atualizarChip(chip, chip.isSelected)
            }
        }

        dialogView.findViewById<TextView>(R.id.btnFilterClose).setOnClickListener { dialog.dismiss() }
        dialogView.findViewById<TextView>(R.id.btnFilterClear).setOnClickListener {
            filterSearch = ""
            filterOrigem = ""
            etSearch.setText("")
            originChips.forEach { chip -> atualizarChip(chip, false) }
        }
        dialogView.findViewById<TextView>(R.id.btnFilterApply).setOnClickListener {
            filterSearch = etSearch.text.toString().trim()
            filterOrigem = originChips.filter { it.isSelected }
                .mapIndexedNotNull { i, _ -> originValues[i] }
                .joinToString(",")
            dialog.dismiss()
            val hasFilter = filterSearch.isNotEmpty() || filterOrigem.isNotEmpty()
            btnFiltrar.text = if (hasFilter) "Filtrar (1)" else "Filtrar"
            loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
        }

        dialog.show()
    }

    private fun atualizarFiltroAbaRetirada() {
        try {
            tabRetiradaGeral.isSelected = filterAbaRetirada == null
            tabRetiradaColetaTardia.isSelected = filterAbaRetirada == "COLETA_TARDIA"
            tabRetiradaEmAnalise.isSelected = filterAbaRetirada == "EM_ANALISE"
            tabRetiradaParado3Dias.isSelected = filterAbaRetirada == "PARADO_3_DIAS"

            val tabsAba = listOf(tabRetiradaGeral, tabRetiradaColetaTardia, tabRetiradaEmAnalise, tabRetiradaParado3Dias)
            val iconesAba = mapOf(
                tabRetiradaGeral to R.drawable.geral,
                tabRetiradaColetaTardia to R.drawable.coleta_tardia,
                tabRetiradaEmAnalise to R.drawable.analise,
                tabRetiradaParado3Dias to R.drawable.parado
            )
            for (tab in tabsAba) {
                tab.background = ContextCompat.getDrawable(
                    this,
                    if (tab.isSelected) R.drawable.bg_tab_retirada_selected else R.drawable.bg_tab_retirada_unselected
                )
                val cor = ContextCompat.getColor(this, if (tab.isSelected) R.color.vermelho_maestro else R.color.gray_medium)
                tab.setTextColor(cor)
                val icone = iconeAbaRetirada(iconesAba[tab] ?: 0, cor)
                tab.setCompoundDrawablesWithIntrinsicBounds(icone, null, null, null)
                tab.setCompoundDrawablePadding((6 * resources.displayMetrics.density).toInt())
            }
        } catch (e: Exception) {
            Log.e(TAG, "atualizarFiltroAbaRetirada ERRO", e)
        }
    }

    private fun iconeAbaRetirada(resId: Int, cor: Int): Drawable? {
        if (resId == 0) return null
        return try {
            val bitmap = android.graphics.BitmapFactory.decodeResource(resources, resId) ?: return null
            val tamanho = (18 * resources.displayMetrics.density).toInt()
            val escalado = android.graphics.Bitmap.createScaledBitmap(bitmap, tamanho, tamanho, true)
            val drawable = BitmapDrawable(resources, escalado)
            drawable.setColorFilter(cor, PorterDuff.Mode.SRC_IN)
            drawable
        } catch (e: Exception) {
            Log.e(TAG, "iconeAbaRetirada ERRO", e)
            null
        }
    }

    private fun atualizarCountsAbaRetirada(counts: io.maestro.network.models.PedidoCounts?) {
        try {
            if (counts == null) return
            tabRetiradaColetaTardia.text = "COLETA TARDIA (${counts.coletaTardia})"
            tabRetiradaEmAnalise.text = "EM ANÁLISE (${counts.emAnalise})"
            tabRetiradaParado3Dias.text = "+3 DIAS PARADO (${counts.parado3Dias})"
        } catch (e: Exception) {
            Log.e(TAG, "atualizarCountsAbaRetirada ERRO", e)
        }
    }

    private fun getFilteredItems(): List<Pedido> {
        if (currentStatus != Constants.STATUS_PRONTO_PARA_SAIR) return allItems
        if (filtroCanalRetirada == null && filtroOrigemRetirada == null) return allItems
        return allItems.filter { pedido ->
            val canalOk = when (filtroCanalRetirada) {
                null -> true
                "AMERICANAS" -> pedido.canalDeVendas?.contains("Americanas", ignoreCase = true) == true
                "IFOOD" -> pedido.canalDeVendas?.contains("iFood", ignoreCase = true) == true
                "MAGALU" -> pedido.canalDeVendas?.contains("Magazine", ignoreCase = true) == true ||
                        pedido.canalDeVendas?.contains("Magalu", ignoreCase = true) == true
                "SHOPEE" -> pedido.canalDeVendas?.contains("Shopee", ignoreCase = true) == true
                else -> true
            }
            val origemOk = when (filtroOrigemRetirada) {
                null -> true
                "DELIVERY" -> pedido.tipoEntrega?.uppercase() == "EXTERNA"
                "PEGUE_LOJA" -> pedido.tipoEntrega?.uppercase() == "RETIRADA"
                else -> true
            }
            canalOk && origemOk
        }
    }

    // ============================================
    // ✅ ABRIR DETALHES - CORRIGIDO
    // ============================================
    
    private fun abrirDetalhesPedido(pedido: Pedido) {
        try {
            val intent = Intent(this, DetalhesPedidoActivity::class.java)
            // ✅ SOMENTE o objeto, sem PEDIDO_ID
            intent.putExtra("PEDIDO", pedido as java.io.Serializable)
            intent.putExtra("COR_ABA", corHeaderAtual)
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao abrir detalhes", e)
            this.toast("Erro ao abrir detalhes")
        }
    }

    override fun onBackPressed() {
        val dialogView = layoutInflater.inflate(R.layout.dialog_sair, null)
        val btnSim = dialogView.findViewById<TextView>(R.id.btnSimSair)
        val btnNao = dialogView.findViewById<TextView>(R.id.btnNaoSair)

        val dialog = AlertDialog.Builder(this, R.style.DialogPerfilTheme)
            .setView(dialogView)
            .create()

        btnSim.setOnClickListener {
            dialog.dismiss()
            finishAffinity()
        }
        btnNao.setOnClickListener { dialog.dismiss() }

        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
        dialog.show()
        dialog.window?.setLayout(
            (resources.displayMetrics.widthPixels * 0.88).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    private fun carregarCounts() {
        val agora = System.currentTimeMillis()
        val cache = countsCache
        if (cache != null && agora - cache.timestamp < 30_000) {
            aplicarCountsCache(cache)
            return
        }

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val token = sessionManager.getToken()
                if (token.isNullOrEmpty()) {
                    Log.e(TAG, "Token vazio ao carregar counts")
                    return@launch
                }
                
                val loja = sessionManager.getUserStore() ?: Constants.DEFAULT_STORE
                Log.d(TAG, "Carregando counts para loja: $loja")
                
                val response = apiService.getCounts(
                    auth = "Bearer $token",
                    loja = loja
                )
                
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful) {
                        val body = response.body()
                        body?.data?.let { items ->
                            var novo = 0
                            var separacao = 0
                            var pronto = 0
                            var entrega = 0
                            var estoque = 0
                            var historico = 0
                            
                            items.forEach { item ->
                                when (item.status) {
                                    "NOVO_PEDIDO" -> novo = item.count
                                    "EM_SEPARACAO", "EDITADO" -> separacao += item.count
                                    "PRONTO_PARA_SAIR" -> pronto = item.count
                                    "SAIU_PARA_ENTREGA" -> entrega = item.count
                                    "RETORNAR_PARA_ESTOQUE" -> estoque = item.count
                                    "FINALIZADO", "CANCELADO", "DEVOLVIDO" -> historico += item.count
                                }
                            }
                            
                            countsCache = CountsCache(novo, separacao, pronto, entrega, estoque, historico, System.currentTimeMillis())
                            aplicarCountsCache(countsCache!!)
                            Log.d(TAG, "Counts carregados")
                        }
                    } else {
                        Log.e(TAG, "carregarCounts: Erro ${response.code()}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "carregarCounts: Erro", e)
                withContext(Dispatchers.Main) {
                    this@MainActivity.toast("Erro ao carregar contagens")
                }
            }
        }
    }

    private fun aplicarCountsCache(cache: CountsCache) {
        tvQtdNovo.text = cache.novo.toString()
        tvQtdSeparacao.text = cache.separacao.toString()
        tvQtdPronto.text = cache.pronto.toString()
        tvQtdEntrega.text = cache.entrega.toString()
        tvQtdEstoque.text = cache.estoque.toString()
        tvQtdHistorico.text = if (cache.historico > 99) "99+" else cache.historico.toString()
        countNovo = cache.novo
        countSeparacao = cache.separacao
        countPronto = cache.pronto
        countEntrega = cache.entrega
        countEstoque = cache.estoque
        countHistorico = cache.historico
        atualizarTituloAba()
    }

    private fun setupRecyclerView() {
        try {
            adapter = PedidoAdapter(
                pedidos = emptyList(),
                onItemClick = { pedido -> abrirDetalhesPedido(pedido) }
            )
            
            val layoutManager = LinearLayoutManager(this)
            rvPedidos.layoutManager = layoutManager
            rvPedidos.setHasFixedSize(true)
            rvPedidos.adapter = adapter
            
            val swipeCallback = object : ItemTouchHelper.SimpleCallback(0, ItemTouchHelper.LEFT or ItemTouchHelper.RIGHT) {
                override fun onMove(recyclerView: RecyclerView, viewHolder: RecyclerView.ViewHolder, target: RecyclerView.ViewHolder): Boolean = false
                override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) {
                    val position = viewHolder.adapterPosition
                    if (position != RecyclerView.NO_POSITION) {
                        val pedido = adapter.getItem(position)
                        if (direction == ItemTouchHelper.RIGHT) {
                            abrirDetalhesPedido(pedido)
                        }
                    }
                    adapter.notifyItemChanged(viewHolder.adapterPosition)
                }
            }
            ItemTouchHelper(swipeCallback).attachToRecyclerView(rvPedidos)
            
            rvPedidos.addOnScrollListener(object : RecyclerView.OnScrollListener() {
                override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                    super.onScrollStateChanged(recyclerView, newState)
                    if (newState == RecyclerView.SCROLL_STATE_DRAGGING) {
                        hideKeyboard()
                    }
                }

                override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                    super.onScrolled(recyclerView, dx, dy)
                    if (dy > 0) {
                        val visibleItemCount = layoutManager.childCount
                        val totalItemCount = layoutManager.itemCount
                        val firstVisibleItemPosition = layoutManager.findFirstVisibleItemPosition()
                        
                        if (!isLoading && !isLastPage) {
                            if ((visibleItemCount + firstVisibleItemPosition) >= totalItemCount 
                                && firstVisibleItemPosition >= 0) {
                                loadPedidos(currentStatus, getCurrentSort(), currentPage + 1, reset = false)
                            }
                        }
                    }
                }
            })
            
            Log.d(TAG, "RecyclerView configurado")
        } catch (e: Exception) {
            Log.e(TAG, "setupRecyclerView ERRO", e)
        }
    }

    private fun getCurrentSort(): String =
        if (currentStatus == Constants.STATUS_PRONTO_PARA_SAIR || currentStatus == Constants.STATUS_SAIU_PARA_ENTREGA) "desc" else "asc"

    private fun loadPedidos(status: String, sort: String, page: Int, reset: Boolean) {
        if (isLoading && !reset) return
        if (!reset && isLastPage) return

        isLoading = true
        val requestId = ++loadRequestId
        if (reset) {
            allItems.clear()
            currentPage = 0
            isLastPage = false
            adapter.updateItems(emptyList())
            mostrarLoading(true)
            layoutEmpty.visibility = View.GONE
        }

        val token = sessionManager.getToken()
        if (token.isNullOrEmpty()) {
            isLoading = false
            mostrarLoading(false)
            Log.e(TAG, "Token vazio ao carregar pedidos")
            redirectToLogin()
            return
        }
        
        val loja = sessionManager.getUserStore() ?: Constants.DEFAULT_STORE
        val search = buildString {
            if (currentStatus == Constants.STATUS_PRONTO_PARA_SAIR && buscaRetiradaTexto.isNotBlank()) {
                append(buscaRetiradaTexto)
            } else if (filterSearch.isNotBlank()) {
                append(filterSearch)
            }
            if (filterOrigem.isNotBlank()) {
                if (isNotEmpty()) append(" ")
                append(filterOrigem)
            }
        }.trim().ifBlank { null }
        val skip = currentPage * limit
        
        Log.d(TAG, "loadPedidos: status=$status, sort=$sort, page=$page, skip=$skip, reset=$reset, requestId=$requestId")

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val abaParam = if (currentStatus == Constants.STATUS_PRONTO_PARA_SAIR) filterAbaRetirada else null
                val response = apiService.getPedidosPaged(
                    skip = skip,
                    limit = limit,
                    auth = "Bearer $token",
                    loja = loja,
                    status = status,
                    minDias = filterMinDias,
                    ordem = sort,
                    search = search,
                    aba = abaParam
                )
                
                withContext(Dispatchers.Main) {
                    if (requestId != loadRequestId) return@withContext
                    isLoading = false
                    mostrarLoading(false)
                    
                    if (response.isSuccessful) {
                        val body = response.body()
                        if (body != null && body.status == "200") {
                            val records = body.data.records ?: emptyList()
                            val totalServidor = body.data.total ?: body.data.count ?: 0
                            Log.d(TAG, "Pedidos carregados: ${records.size}, total: $totalServidor, aba: $abaParam")
                            if (currentStatus == Constants.STATUS_PRONTO_PARA_SAIR) {
                                atualizarCountsAbaRetirada(body.data.counts)
                            }
                            updateUI(records, reset)
                            val loadedSoFar = currentPage * limit
                            if (loadedSoFar >= totalServidor) {
                                isLastPage = true
                            }
                        } else {
                            Log.e(TAG, "Resposta vazia ou erro")
                            if (reset) {
                                adapter.updateItems(emptyList())
                                showEmptyState("Nenhum pedido encontrado")
                            }
                        }
                    } else {
                        Log.e(TAG, "Erro HTTP: ${response.code()}")
                        handleError(response.code())
                        if (reset) {
                            adapter.updateItems(emptyList())
                            showEmptyState("Erro ao carregar pedidos")
                        }
                    }
                }
            } catch (e: IOException) {
                Log.e(TAG, "Erro de rede", e)
                withContext(Dispatchers.Main) {
                    if (requestId != loadRequestId) return@withContext
                    isLoading = false
                    mostrarLoading(false)
                    this@MainActivity.toast("Erro de rede: ${e.message}")
                    if (reset) {
                        showEmptyState("Erro de conexão com a internet")
                    }
                }
            } catch (e: HttpException) {
                Log.e(TAG, "HTTP Error", e)
                withContext(Dispatchers.Main) {
                    if (requestId != loadRequestId) return@withContext
                    isLoading = false
                    mostrarLoading(false)
                    handleError(e.code())
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erro", e)
                withContext(Dispatchers.Main) {
                    if (requestId != loadRequestId) return@withContext
                    isLoading = false
                    mostrarLoading(false)
                    this@MainActivity.toast("Erro: ${e.message}")
                    if (reset) {
                        showEmptyState("Erro ao carregar pedidos")
                    }
                }
            }
        }
    }

    private fun updateUI(records: List<Pedido>, reset: Boolean) {
        try {
            if (records.isEmpty()) {
                isLastPage = true
                if (reset) {
                    adapter.updateItems(emptyList())
                    showEmptyState("Nenhum pedido encontrado")
                }
                return
            }
            
            layoutEmpty.visibility = View.GONE
            
            if (reset) {
                allItems.clear()
            }
            allItems.addAll(records)
            currentPage++
            
            adapter.updateItems(getFilteredItems())
            if (reset) rvPedidos.scrollToPosition(0)
            Log.d(TAG, "UI updated: ${allItems.size} pedidos")
        } catch (e: Exception) {
            Log.e(TAG, "updateUI ERRO", e)
        }
    }

    private fun mostrarLoading(mostrar: Boolean) {
        layoutLoading.visibility = if (mostrar) View.VISIBLE else View.GONE
        rvPedidos.visibility = if (mostrar) View.GONE else View.VISIBLE
    }

    private fun showEmptyState(message: String) {
        layoutEmpty.visibility = View.VISIBLE
        tvEmptyTitle.text = "Não há pedidos!"
        atualizarIconeEmptyState()
        rvPedidos.visibility = View.GONE
    }

    private fun atualizarIconeEmptyState() {
        try {
            val mapIcone = mapOf(
                tabNovo to R.drawable.ic_clipboard,
                tabSeparacao to R.drawable.ic_sync,
                tabRetirada to R.drawable.ic_bag,
                tabEntrega to R.drawable.ic_truck,
                tabEstoque to R.drawable.ic_estoque,
                tabHistorico to R.drawable.ic_historico
            )
            val resId = mapIcone[tabSelecionadaAtual] ?: R.drawable.ic_receipt
            imgEmptyIllustration.setImageResource(resId)
            imgEmptyIllustration.setColorFilter(
                ContextCompat.getColor(this, R.color.gray_medium),
                android.graphics.PorterDuff.Mode.SRC_IN
            )
        } catch (e: Exception) {
            Log.e(TAG, "atualizarIconeEmptyState ERRO", e)
        }
    }

    private fun handleError(code: Int) {
        try {
            Log.e(TAG, "handleError: $code")
            when (code) {
                401 -> {
                    this.toastLong("Sessão expirada. Faça login novamente.")
                    SessionExpiredHandler.handleSessionExpired(this)
                }
                403 -> this.toast("Acesso negado.")
                404 -> {
                    showEmptyState("Nenhum pedido encontrado")
                    this.toast("Nenhum pedido encontrado")
                }
                500, 502, 503 -> this.toast("Erro no servidor. Tente novamente.")
                else -> this.toast("Erro: Código $code")
            }
        } catch (e: Exception) {
            Log.e(TAG, "handleError ERRO", e)
        }
    }

    private fun setupSwipeRefresh() {
        swipeRefreshLayout.setOnRefreshListener {
            if (currentStatus == Constants.STATUS_NOVO) {
                loadPedidos(currentStatus, getCurrentSort(), 0, reset = true)
                carregarCounts()
            }
            swipeRefreshLayout.postDelayed({ swipeRefreshLayout.isRefreshing = false }, 2000)
        }
    }

    private fun atualizarTituloAba() {
        val count = when (currentStatus) {
            Constants.STATUS_NOVO -> countNovo
            Constants.STATUS_EM_SEPARACAO -> countSeparacao
            Constants.STATUS_PRONTO_PARA_SAIR -> countPronto
            Constants.STATUS_SAIU_PARA_ENTREGA -> countEntrega
            Constants.STATUS_RETORNAR_ESTOQUE -> countEstoque
            Constants.STATUS_HISTORICO -> countHistorico
            else -> countNovo
        }
        val title = when (currentStatus) {
            Constants.STATUS_NOVO -> if (count == 1) "Novo Pedido" else "Novos Pedidos"
            Constants.STATUS_EM_SEPARACAO -> "Em Separação"
            Constants.STATUS_PRONTO_PARA_SAIR -> "Pronto Para Retirada"
            Constants.STATUS_SAIU_PARA_ENTREGA -> "Saiu Para Entrega"
            Constants.STATUS_RETORNAR_ESTOQUE -> "Retornar para Estoque"
            Constants.STATUS_HISTORICO -> "Em Histórico"
            else -> "Pedidos"
        }
        tvNovosCount.text = if (count > 0) "$count $title" else title
    }

    private fun redirectToLogin() {
        try {
            Log.d(TAG, "redirectToLogin")
            val intent = Intent(this, LoginActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            startActivity(intent)
            finish()
        } catch (e: Exception) {
            Log.e(TAG, "redirectToLogin ERRO", e)
        }
    }

    // ============================================
    // HISTÓRICO
    // ============================================

    private fun setupHistoricoRecyclerView() {
        historicoAdapter = PedidoAdapter(
            pedidos = emptyList(),
            onItemClick = { pedido -> abrirDetalhesPedido(pedido) }
        )
        val layoutManager = LinearLayoutManager(this)
        rvHistorico.layoutManager = layoutManager
        rvHistorico.setHasFixedSize(true)
        rvHistorico.adapter = historicoAdapter

        rvHistorico.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                super.onScrollStateChanged(recyclerView, newState)
                if (newState == RecyclerView.SCROLL_STATE_DRAGGING) {
                    hideKeyboard()
                }
            }

            override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                super.onScrolled(recyclerView, dx, dy)
                if (dy > 0) {
                    val visibleItemCount = layoutManager.childCount
                    val totalItemCount = layoutManager.itemCount
                    val firstVisibleItemPosition = layoutManager.findFirstVisibleItemPosition()
                    if (!historicoIsLoading && !historicoIsLastPage) {
                        if ((visibleItemCount + firstVisibleItemPosition) >= totalItemCount
                            && firstVisibleItemPosition >= 0) {
                            loadHistorico(reset = false)
                        }
                    }
                }
            }
        })
    }

    private fun matchesHistoricoFilter(pedido: Pedido): Boolean {
        return when (historicoSelectedFilter) {
            ModalityFilter.ALL -> true
            ModalityFilter.PEGUE_NA_LOJA -> pedido.tipoEntrega?.uppercase() == "RETIRADA"
            ModalityFilter.DELIVERY -> pedido.tipoEntrega?.uppercase() == "EXTERNA" && (
                    pedido.canalDeVendas?.contains("Magazine", ignoreCase = true) == true ||
                    pedido.canalVendas?.contains("Magazine", ignoreCase = true) == true ||
                    pedido.canalDeVendas?.contains("Americanas", ignoreCase = true) == true ||
                    pedido.canalVendas?.contains("Americanas", ignoreCase = true) == true
            )
            ModalityFilter.IFOOD -> pedido.canalDeVendas?.contains("iFood", ignoreCase = true) == true
                    || pedido.canalVendas?.contains("iFood", ignoreCase = true) == true
            ModalityFilter.CANCELADO -> pedido.status == "CANCELADO"
            ModalityFilter.DEVOLVIDO -> pedido.status == "DEVOLVIDO"
        }
    }

    private fun styleHistoricoFilterButton(button: TextView, isSelected: Boolean, bgResId: Int) {
        button.isSelected = isSelected
        button.setBackgroundResource(bgResId)
        button.setTextColor(if (isSelected) Color.WHITE else Color.parseColor(Colors.GRAY_500))
    }

    private fun updateHistoricoFilterButtons() {
        styleHistoricoFilterButton(btnFiltroTodos, historicoSelectedFilter == ModalityFilter.ALL, R.drawable.bg_filter_todos)
        styleHistoricoFilterButton(btnFiltroPegueLoja2, historicoSelectedFilter == ModalityFilter.PEGUE_NA_LOJA, R.drawable.bg_filter_pegue)
        styleHistoricoFilterButton(btnFiltroDelivery, historicoSelectedFilter == ModalityFilter.DELIVERY, R.drawable.bg_filter_delivery)
        styleHistoricoFilterButton(btnFiltroIfood2, historicoSelectedFilter == ModalityFilter.IFOOD, R.drawable.bg_filter_ifood)
        styleHistoricoFilterButton(btnFiltroCancelado, historicoSelectedFilter == ModalityFilter.CANCELADO, R.drawable.bg_filter_cancelado)
        styleHistoricoFilterButton(btnFiltroDevolvido, historicoSelectedFilter == ModalityFilter.DEVOLVIDO, R.drawable.bg_filter_devolvido)
    }

    private fun onHistoricoFilterSelected(filter: ModalityFilter) {
        if (historicoSelectedFilter == filter) return
        historicoSelectedFilter = filter
        updateHistoricoFilterButtons()
        atualizarContadorHistorico()
        historicoIsLoading = false
        loadHistorico(reset = true)
    }

    private fun refreshHistoricoDisplay() {
        val filtered = historicoAllItems.filter { matchesHistoricoFilter(it) }
        historicoAdapter.updateItems(filtered)
        if (::rvHistorico.isInitialized) rvHistorico.scrollToPosition(0)
        atualizarContadorHistorico()

        if (filtered.isEmpty()) {
            layoutHistoricoEmpty.visibility = View.VISIBLE
            tvHistoricoEmptyMessage.text = if (historicoAllItems.isEmpty()) "Nenhum pedido no histórico" else "Nenhum pedido encontrado para este filtro"
            rvHistorico.visibility = View.GONE
        } else {
            layoutHistoricoEmpty.visibility = View.GONE
            rvHistorico.visibility = View.VISIBLE
        }
    }

    private fun loadHistorico(reset: Boolean) {
        if (historicoIsLoading) return
        if (!reset && historicoIsLastPage) return

        historicoIsLoading = true
        historicoLoadingFilter = historicoSelectedFilter
        if (reset) {
            historicoAllItems.clear()
            historicoCurrentPage = 0
            historicoIsLastPage = false
            historicoTotalPedidos = 0
            historicoAdapter.updateItems(emptyList())
            mostrarHistoricoLoading(true)
            layoutHistoricoEmpty.visibility = View.GONE
        }

        val token = sessionManager.getToken()
        if (token.isNullOrEmpty()) {
            historicoIsLoading = false
            mostrarHistoricoLoading(false)
            redirectToLogin()
            return
        }

        val loja = sessionManager.getUserStore() ?: Constants.DEFAULT_STORE
        val search = if (historicoSearchQuery.isNotEmpty()) historicoSearchQuery else null

        val statusParam = when (historicoSelectedFilter) {
            ModalityFilter.CANCELADO -> "CANCELADO"
            ModalityFilter.DEVOLVIDO -> "DEVOLVIDO"
            else -> Constants.STATUS_HISTORICO
        }

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                var currentPage = historicoCurrentPage
                var stop = false

                while (!stop) {
                    val skip = currentPage * historicoLimit
                    val response = apiService.getPedidosPaged(
                        skip = skip,
                        limit = historicoLimit,
                        auth = "Bearer $token",
                        loja = loja,
                        status = statusParam,
                        minDias = 0,
                        ordem = "desc",
                        search = search
                    )

                    withContext(Dispatchers.Main) {
                        if (historicoLoadingFilter != historicoSelectedFilter) {
                            stop = true
                            return@withContext
                        }

                        if (!response.isSuccessful) {
                            handleHistoricoError(response.code())
                            stop = true
                            return@withContext
                        }

                        try {
                            val body = response.body()
                            if (body == null || body.status != "200") {
                                if (historicoAllItems.isEmpty()) {
                                    showHistoricoEmptyState("Erro ao carregar histórico")
                                }
                                stop = true
                                return@withContext
                            }

                            val records = body.data.records
                            historicoTotalPedidos = body.data.total ?: 0

                            if (records.isNullOrEmpty()) {
                                if (historicoAllItems.isEmpty()) {
                                    showHistoricoEmptyState("Nenhum pedido no histórico")
                                }
                                stop = true
                                return@withContext
                            }

                            updateHistoricoUI(records, currentPage == 0)
                            currentPage++
                            val loadedSoFar = currentPage * historicoLimit
                            if (loadedSoFar >= historicoTotalPedidos) {
                                stop = true
                                historicoIsLastPage = true
                            }
                            historicoCurrentPage = currentPage
                            if (!reset) {
                                stop = true // scroll loading: only one page per call
                            }
                        } catch (e: Exception) {
                            showHistoricoEmptyState("Erro ao processar dados do histórico.")
                            this@MainActivity.toastLong("Erro: ${e.message}")
                            stop = true
                        }
                    }
                }

                withContext(Dispatchers.Main) {
                    historicoIsLoading = false
                    mostrarHistoricoLoading(false)
                }
            } catch (e: IOException) {
                withContext(Dispatchers.Main) {
                    historicoIsLoading = false
                    mostrarHistoricoLoading(false)
                    this@MainActivity.toast("Erro de rede: ${e.message}")
                    if (historicoAllItems.isEmpty()) showHistoricoEmptyState("Erro de conexão")
                }
            } catch (e: HttpException) {
                withContext(Dispatchers.Main) {
                    historicoIsLoading = false
                    mostrarHistoricoLoading(false)
                    handleHistoricoError(e.code())
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    historicoIsLoading = false
                    mostrarHistoricoLoading(false)
                    this@MainActivity.toastLong("Erro: ${e.message}")
                    if (historicoAllItems.isEmpty()) showHistoricoEmptyState("Erro ao carregar histórico")
                }
            }
        }
    }

    private fun carregarCountsHistorico() {
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val token = sessionManager.getToken()
                if (token.isNullOrEmpty()) return@launch
                val loja = sessionManager.getUserStore() ?: Constants.DEFAULT_STORE
                val response = apiService.getCounts(auth = "Bearer $token", loja = loja)
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful) {
                        response.body()?.data?.let { items ->
                            historicoCountsMap.clear()
                            items.forEach { historicoCountsMap[it.status] = it.count }
                            atualizarContadorHistorico()
                        }
                    }
                }
            } catch (_: Exception) {}
        }
    }

    private fun atualizarContadorHistorico() {
        val count = when (historicoSelectedFilter) {
            ModalityFilter.ALL -> {
                (historicoCountsMap["FINALIZADO"] ?: 0) + (historicoCountsMap["CANCELADO"] ?: 0) + (historicoCountsMap["DEVOLVIDO"] ?: 0)
            }
            ModalityFilter.CANCELADO -> historicoCountsMap["CANCELADO"] ?: 0
            ModalityFilter.DEVOLVIDO -> historicoCountsMap["DEVOLVIDO"] ?: 0
            ModalityFilter.PEGUE_NA_LOJA -> historicoAllItems.count { it.tipoEntrega?.uppercase() == "RETIRADA" }
            ModalityFilter.DELIVERY -> historicoAllItems.count {
                it.tipoEntrega?.uppercase() == "EXTERNA" && (
                    it.canalDeVendas?.contains("Magazine", ignoreCase = true) == true ||
                    it.canalVendas?.contains("Magazine", ignoreCase = true) == true ||
                    it.canalDeVendas?.contains("Americanas", ignoreCase = true) == true ||
                    it.canalVendas?.contains("Americanas", ignoreCase = true) == true
                )
            }
            ModalityFilter.IFOOD -> historicoAllItems.count {
                it.canalDeVendas?.contains("iFood", ignoreCase = true) == true ||
                it.canalVendas?.contains("iFood", ignoreCase = true) == true
            }
        }
        tvQtdHistorico.text = if (count > 99) "99+" else count.toString()
    }

    private fun updateHistoricoUI(records: List<Pedido>, reset: Boolean) {
        try {
            if (records.isEmpty()) {
                historicoIsLastPage = true
                if (reset) {
                    historicoAdapter.updateItems(emptyList())
                    showHistoricoEmptyState("Nenhum pedido encontrado")
                }
                return
            }

            layoutHistoricoEmpty.visibility = View.GONE

            if (reset) {
                historicoAllItems.clear()
            }
            historicoAllItems.addAll(records)
            refreshHistoricoDisplay()
        } catch (e: Exception) {
            showHistoricoEmptyState("Erro ao renderizar dados do histórico.")
        }
    }

    private fun mostrarHistoricoLoading(mostrar: Boolean) {
        layoutHistoricoLoading.visibility = if (mostrar) View.VISIBLE else View.GONE
        rvHistorico.visibility = if (mostrar) View.GONE else View.VISIBLE
    }

    private fun showHistoricoEmptyState(message: String) {
        layoutHistoricoEmpty.visibility = View.VISIBLE
        tvHistoricoEmptyMessage.text = message
        rvHistorico.visibility = View.GONE
        atualizarContadorHistorico()
    }

    private fun handleHistoricoError(code: Int) {
        when (code) {
            401 -> {
                this.toastLong("Sessão expirada. Faça login novamente.")
                SessionExpiredHandler.handleSessionExpired(this)
            }
            403 -> this.toast("Acesso negado.")
            404 -> showHistoricoEmptyState("Nenhum pedido no histórico")
            500, 502, 503 -> this.toast("Erro no servidor. Tente novamente.")
            else -> this.toast("Erro: Código $code")
        }
    }
}