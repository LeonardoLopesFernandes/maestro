package io.maestro.ui

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.TextView
import android.app.AlertDialog
import android.view.LayoutInflater
import android.widget.Button
import android.widget.EditText
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatEditText
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.maestro.R
import io.maestro.adapters.PedidoAdapter
import io.maestro.utils.Colors
import io.maestro.network.ApiClient
import io.maestro.network.SessionManager
import io.maestro.network.models.Pedido
import io.maestro.utils.toast
import io.maestro.utils.toastLong
import io.maestro.utils.Constants
import io.maestro.utils.LogHelper
import io.maestro.utils.RecaptchaManager
import io.maestro.utils.SessionExpiredHandler
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import android.graphics.Color
import retrofit2.HttpException
import java.io.IOException

class HistoricoActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "HistoricoActivity"
    }

    private enum class ModalityFilter {
        ALL, PEGUE_NA_LOJA, DELIVERY, IFOOD, CANCELADO, DEVOLVIDO
    }

    private lateinit var sessionManager: SessionManager
    private lateinit var apiService: io.maestro.network.ApiService
    private lateinit var adapter: PedidoAdapter
    
    private lateinit var tvTitle: TextView
    private lateinit var tvTotal: TextView
    private lateinit var tvSubtitle: TextView
    private lateinit var etBuscarHistorico: AppCompatEditText
    private lateinit var btnLimparBusca: ImageButton
    private lateinit var rvHistorico: RecyclerView
    private lateinit var layoutLoading: View
    private lateinit var layoutEmpty: View
    private lateinit var tvEmptyMessage: TextView
    private lateinit var btnFiltroTodos: TextView
    private lateinit var btnFiltroPegueLoja: TextView
    private lateinit var btnFiltroDelivery: TextView
    private lateinit var btnFiltroIfood: TextView
    private lateinit var btnFiltroCancelado: TextView
    private lateinit var btnFiltroDevolvido: TextView

    private val allItems = mutableListOf<Pedido>()
    private var currentPage = 0
    private var isLoading = false
    private var isLastPage = false
    private var searchQuery = ""
    private val limit = 20
    private var selectedFilter = ModalityFilter.ALL
    private var totalPedidos = 0
    private val countsMap = mutableMapOf<String, Int>()
    private var loadingFilter: ModalityFilter? = null

    private val searchHandler = Handler(Looper.getMainLooper())
    private val searchRunnable = Runnable { loadHistorico(reset = true) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_historico)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
            window.statusBarColor = ContextCompat.getColor(this, R.color.cinza)
        }

        sessionManager = SessionManager(this)
        
        if (!sessionManager.isLoggedIn()) {
            redirectToLogin()
            return
        }

        apiService = ApiClient.getInstance(this).getApiService()

        initViews()
        setupListeners()
        setupRecyclerView()
        lifecycleScope.launch {
            while (isActive) {
                adapter.tick()
                delay(1000)
            }
        }
        loadHistorico(reset = true)
        fetchCounts()
    }

    private fun initViews() {
        tvTitle = findViewById(R.id.tvTitle)
        tvTotal = findViewById(R.id.tvTotal)
        tvSubtitle = findViewById(R.id.tvSubtitle)
        etBuscarHistorico = findViewById(R.id.etBuscarHistorico)
        btnLimparBusca = findViewById(R.id.btnLimparBusca)
        rvHistorico = findViewById(R.id.rvHistorico)
        layoutLoading = findViewById(R.id.layoutLoading)
        layoutEmpty = findViewById(R.id.layoutEmpty)
        tvEmptyMessage = findViewById(R.id.tvEmptyMessage)
        btnFiltroTodos = findViewById(R.id.btnFiltroTodos)
        btnFiltroPegueLoja = findViewById(R.id.btnFiltroPegueLoja)
        btnFiltroDelivery = findViewById(R.id.btnFiltroDelivery)
        btnFiltroIfood = findViewById(R.id.btnFiltroIfood)
        btnFiltroCancelado = findViewById(R.id.btnFiltroCancelado)
        btnFiltroDevolvido = findViewById(R.id.btnFiltroDevolvido)
    }

    private fun setupListeners() {
        etBuscarHistorico.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                searchQuery = s.toString()
                btnLimparBusca.visibility = if (searchQuery.isNotEmpty()) View.VISIBLE else View.GONE
                searchHandler.removeCallbacks(searchRunnable)
                searchHandler.postDelayed(searchRunnable, 400)
            }
        })

        btnLimparBusca.setOnClickListener {
            etBuscarHistorico.text?.clear()
            searchQuery = ""
            btnLimparBusca.visibility = View.GONE
            loadHistorico(reset = true)
        }

        btnFiltroTodos.setOnClickListener { onFilterSelected(ModalityFilter.ALL) }
        btnFiltroPegueLoja.setOnClickListener { onFilterSelected(ModalityFilter.PEGUE_NA_LOJA) }
        btnFiltroDelivery.setOnClickListener { onFilterSelected(ModalityFilter.DELIVERY) }
        btnFiltroIfood.setOnClickListener { onFilterSelected(ModalityFilter.IFOOD) }
        btnFiltroCancelado.setOnClickListener { onFilterSelected(ModalityFilter.CANCELADO) }
        btnFiltroDevolvido.setOnClickListener { onFilterSelected(ModalityFilter.DEVOLVIDO) }

        updateFilterButtons()
    }

    private fun setupRecyclerView() {
        adapter = PedidoAdapter(
            pedidos = emptyList(),
            onItemClick = { pedido ->
                try {
                    val intent = Intent(this, DetalhesPedidoActivity::class.java)
                    intent.putExtra("PEDIDO_ID", pedido.id)
                    intent.putExtra("PEDIDO", pedido as java.io.Serializable)
                    intent.putExtra("COR_ABA", R.color.btn_historico)
                    startActivity(intent)
                } catch (e: Exception) {
                    this.toast("Erro ao abrir detalhes")
                    LogHelper.e("HistoricoActivity: Erro ao abrir detalhes", e)
                }
            }
        )
        
        val layoutManager = LinearLayoutManager(this)
        rvHistorico.layoutManager = layoutManager
        rvHistorico.setHasFixedSize(true)
        rvHistorico.adapter = adapter
        
        rvHistorico.addOnScrollListener(object : RecyclerView.OnScrollListener() {
            override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                super.onScrolled(recyclerView, dx, dy)
                if (dy > 0) {
                    val visibleItemCount = layoutManager.childCount
                    val totalItemCount = layoutManager.itemCount
                    val firstVisibleItemPosition = layoutManager.findFirstVisibleItemPosition()
                    
                    if (!isLoading && !isLastPage) {
                        if ((visibleItemCount + firstVisibleItemPosition) >= totalItemCount 
                            && firstVisibleItemPosition >= 0) {
                            loadHistorico(reset = false)
                        }
                    }
                }
            }
        })
    }

private fun matchesFilter(pedido: Pedido): Boolean {
        return when (selectedFilter) {
            ModalityFilter.ALL -> true
            ModalityFilter.PEGUE_NA_LOJA -> pedido.origem == "PEGUE_NA_LOJA_HOJE"
            ModalityFilter.DELIVERY -> pedido.origem != "PEGUE_NA_LOJA_HOJE" && pedido.origem != null
            ModalityFilter.IFOOD -> pedido.canalDeVendas?.contains("iFood", ignoreCase = true) == true
                    || pedido.canalVendas?.contains("iFood", ignoreCase = true) == true
            ModalityFilter.CANCELADO -> pedido.status == "CANCELADO"
            ModalityFilter.DEVOLVIDO -> pedido.status == "DEVOLVIDO"
        }
    }

private fun styleFilterButton(button: TextView, isSelected: Boolean, bgResId: Int) {
        button.isSelected = isSelected
        button.setBackgroundResource(bgResId)
        button.setTextColor(if (isSelected) Color.WHITE else Color.parseColor(Colors.GRAY_500))
    }

    private fun updateFilterButtons() {
        styleFilterButton(btnFiltroTodos, selectedFilter == ModalityFilter.ALL, R.drawable.bg_filter_todos)
        styleFilterButton(btnFiltroPegueLoja, selectedFilter == ModalityFilter.PEGUE_NA_LOJA, R.drawable.bg_filter_pegue)
        styleFilterButton(btnFiltroDelivery, selectedFilter == ModalityFilter.DELIVERY, R.drawable.bg_filter_delivery)
        styleFilterButton(btnFiltroIfood, selectedFilter == ModalityFilter.IFOOD, R.drawable.bg_filter_ifood)
        styleFilterButton(btnFiltroCancelado, selectedFilter == ModalityFilter.CANCELADO, R.drawable.bg_filter_cancelado)
        styleFilterButton(btnFiltroDevolvido, selectedFilter == ModalityFilter.DEVOLVIDO, R.drawable.bg_filter_devolvido)
    }

    private fun onFilterSelected(filter: ModalityFilter) {
        if (selectedFilter == filter) return
        selectedFilter = filter
        updateFilterButtons()
        atualizarContador()
        isLoading = false
        loadHistorico(reset = true)
    }

    private fun refreshDisplay() {
        val filtered = allItems.filter { matchesFilter(it) }
        adapter.updateItems(filtered)
        atualizarContador()

        if (filtered.isEmpty()) {
            layoutEmpty.visibility = View.VISIBLE
            tvEmptyMessage.text = if (allItems.isEmpty()) "Nenhum pedido no histórico" else "Nenhum pedido encontrado para este filtro"
            rvHistorico.visibility = View.GONE
        } else {
            layoutEmpty.visibility = View.GONE
            rvHistorico.visibility = View.VISIBLE
        }
    }

private fun loadHistorico(reset: Boolean) {
        if (isLoading) return
        if (!reset && isLastPage) return
        
        isLoading = true
        loadingFilter = selectedFilter
        if (reset) {
            allItems.clear()
            currentPage = 0
            isLastPage = false
            totalPedidos = 0
            adapter.updateItems(emptyList())
            mostrarLoading(true)
            layoutEmpty.visibility = View.GONE
        }
        
        val token = sessionManager.getToken()
        if (token.isNullOrEmpty()) {
            isLoading = false
            mostrarLoading(false)
            redirectToLogin()
            return
        }
        
        val loja = sessionManager.getUserStore() ?: Constants.DEFAULT_STORE
        val search = if (searchQuery.isNotEmpty()) searchQuery else null
        val skip = currentPage * limit
        
        // Sempre carregar todas as páginas para contagem correta
        val statusParam = when (selectedFilter) {
            ModalityFilter.CANCELADO -> "CANCELADO"
            ModalityFilter.DEVOLVIDO -> "DEVOLVIDO"
            else -> Constants.STATUS_HISTORICO
        }
        
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                Log.d(TAG, "=== CARREGANDO HISTÓRICO página ${currentPage} (filtro: $selectedFilter) ===")
                
                val response = apiService.getPedidosPaged(
                    skip = skip,
                    limit = limit,
                    auth = "Bearer $token",
                    loja = loja,
                    status = statusParam,
                    minDias = 0,
                    ordem = "desc",
                    search = search
                )
                
                withContext(Dispatchers.Main) {
                    isLoading = false
                    mostrarLoading(false)
                    
                    if (response.isSuccessful) {
                        try {
                            val body = response.body()
                            Log.d(TAG, "Status resposta: ${body?.status}")
                            
                            if (body != null && body.status == "200") {
                                // Se o filtro mudou durante o carregamento, descartar resposta
                                if (loadingFilter != selectedFilter) {
                                    Log.d(TAG, "Filtro mudou durante carregamento, descartando resposta")
                                    isLoading = false
                                    return@withContext
                                }
                                val records = body.data.records
                                val totalServidor = body.data.total ?: 0
                                totalPedidos = totalServidor
                                Log.d(TAG, "Registros recebidos: ${records?.size ?: 0}, total no servidor: $totalServidor, status enviado: $statusParam")
                                
                                if (records.isNullOrEmpty()) {
                                    showEmptyState("Nenhum pedido no histórico")
                                } else {
                                    updateUI(records, reset)
                                    currentPage++
                                    val loadedSoFar = currentPage * limit
                                    if (loadedSoFar < totalServidor) {
                                        loadHistorico(reset = false)
                                    } else {
                                        isLastPage = true
                                    }
                                }
                            } else {
                                showEmptyState("Erro ao carregar histórico")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Erro ao processar resposta", e)
                            showEmptyState("Erro ao processar dados do histórico.")
                            this@HistoricoActivity.toastLong("Erro: ${e.message}")
                        }
                    } else {
                        Log.e(TAG, "Erro HTTP ${response.code()}")
                        handleError(response.code())
                    }
                }
            } catch (e: IOException) {
                Log.e(TAG, "Erro de rede", e)
                withContext(Dispatchers.Main) {
                    isLoading = false
                    mostrarLoading(false)
                    this@HistoricoActivity.toast("Erro de rede: ${e.message}")
                    showEmptyState("Erro de conexão")
                }
            } catch (e: HttpException) {
                Log.e(TAG, "HTTP Error", e)
                withContext(Dispatchers.Main) {
                    isLoading = false
                    mostrarLoading(false)
                    handleError(e.code())
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erro", e)
                withContext(Dispatchers.Main) {
                    isLoading = false
                    mostrarLoading(false)
                    this@HistoricoActivity.toastLong("Erro: ${e.message}")
                    showEmptyState("Erro ao carregar histórico")
                }
            }
        }
    }

    private fun fetchCounts() {
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val token = sessionManager.getToken()
                if (token.isNullOrEmpty()) return@launch
                val loja = sessionManager.getUserStore() ?: Constants.DEFAULT_STORE
                val response = apiService.getCounts(auth = "Bearer $token", loja = loja)
                withContext(Dispatchers.Main) {
                    if (response.isSuccessful) {
                        response.body()?.data?.let { items ->
                            countsMap.clear()
                            items.forEach { countsMap[it.status] = it.count }
                            atualizarContador()
                        }
                    }
                }
            } catch (_: Exception) {}
        }
    }

    private fun atualizarContador() {
        val count = when (selectedFilter) {
            ModalityFilter.ALL -> {
                (countsMap["FINALIZADO"] ?: 0) + (countsMap["CANCELADO"] ?: 0) + (countsMap["DEVOLVIDO"] ?: 0)
            }
            ModalityFilter.CANCELADO -> countsMap["CANCELADO"] ?: 0
            ModalityFilter.DEVOLVIDO -> countsMap["DEVOLVIDO"] ?: 0
            ModalityFilter.PEGUE_NA_LOJA -> allItems.count { it.origem == "PEGUE_NA_LOJA_HOJE" }
            ModalityFilter.DELIVERY -> allItems.count { it.origem != null && it.origem != "PEGUE_NA_LOJA_HOJE" && it.origem != "iFood" }
            ModalityFilter.IFOOD -> allItems.count {
                it.canalDeVendas?.contains("iFood", ignoreCase = true) == true ||
                it.canalVendas?.contains("iFood", ignoreCase = true) == true
            }
        }
        tvTotal.text = "$count pedidos no histórico"
    }

    private fun updateUI(records: List<Pedido>, reset: Boolean) {
        try {
            if (records.isEmpty()) {
                isLastPage = true
                if (reset) {
                    adapter.updateItems(emptyList())
                    showEmptyState("Nenhum pedido encontrado")
                    tvTotal.text = "0 pedidos"
                }
                return
            }
            
            layoutEmpty.visibility = View.GONE
            
            if (reset) {
                allItems.clear()
            }
            allItems.addAll(records)
            refreshDisplay()
            Log.d(TAG, "UI atualizada: ${allItems.size} pedidos")
        } catch (e: Exception) {
            Log.e(TAG, "updateUI ERRO", e)
            showEmptyState("Erro ao renderizar dados do histórico.")
        }
    }

    private fun mostrarLoading(mostrar: Boolean) {
        layoutLoading.visibility = if (mostrar) View.VISIBLE else View.GONE
        rvHistorico.visibility = if (mostrar) View.GONE else View.VISIBLE
    }

    private fun showEmptyState(message: String) {
        layoutEmpty.visibility = View.VISIBLE
        tvEmptyMessage.text = message
        rvHistorico.visibility = View.GONE
        atualizarContador()
    }

    private fun handleError(code: Int) {
        when (code) {
            401 -> {
                this.toastLong("Sessão expirada. Faça login novamente.")
                SessionExpiredHandler.handleSessionExpired(this)
            }
            403 -> this.toast("Acesso negado.")
            404 -> showEmptyState("Nenhum pedido no histórico")
            500, 502, 503 -> this.toast("Erro no servidor. Tente novamente.")
            else -> this.toast("Erro: Código $code")
        }
    }

    private fun redirectToLogin() {
        val intent = Intent(this, LoginActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
        finish()
    }

}