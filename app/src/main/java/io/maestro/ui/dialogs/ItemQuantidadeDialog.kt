package io.maestro.ui.dialogs

import android.content.Context
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.CheckBox
import android.widget.CompoundButton
import android.widget.EditText
import android.widget.TextView
import android.util.Log
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.maestro.R
import io.maestro.network.models.Item
import io.maestro.network.models.Pedido

class ItemQuantidadeDialog(
    private val context: Context,
    private val pedido: Pedido,
    private val onConfirm: (Map<String, Int>, Map<String, List<String>>) -> Unit,
    private val onCancel: () -> Unit
) {

    private lateinit var dialog: AlertDialog
    private lateinit var adapter: ItemQuantidadeAdapter
    private var quantidadesEditadas = mutableMapOf<String, Int>()
    private var imeisEditados = mutableMapOf<String, List<String>>()
    private var nenhumItemMarcado = false

    fun show() {
        Log.d("ItemQuantidadeDialog", "Abrindo dialog para pedido: ${pedido.codigoExterno}")
        val builder = AlertDialog.Builder(context)
        val view = LayoutInflater.from(context).inflate(R.layout.dialog_item_quantidade, null)

        val rvItens = view.findViewById<RecyclerView>(R.id.rvItensQuantidade)
        val btnCancelar = view.findViewById<Button>(R.id.btnCancelar)
        val btnConfirmar = view.findViewById<Button>(R.id.btnConfirmar)
        val tvTitulo = view.findViewById<TextView>(R.id.tvTituloConfirmacao)
        val cbNenhumItem = view.findViewById<CheckBox>(R.id.cbNenhumItem)
        val tvStep2 = view.findViewById<TextView>(R.id.tvStep2)

        tvTitulo.text = context.getString(R.string.dialog_confirmacao_titulo, pedido.codigoExterno ?: "")
        tvStep2.background = ContextCompat.getDrawable(context, R.drawable.bg_badge_gray)

        pedido.itens?.forEach { item ->
            quantidadesEditadas[item.codigoSAP ?: ""] = item.quantidade
        }

        val items = pedido.itens ?: emptyList()
        adapter = ItemQuantidadeAdapter(
            items = items,
            onQuantidadeChanged = { codigoSap, novaQuantidade ->
                quantidadesEditadas[codigoSap] = novaQuantidade
            },
            onImeisChanged = { codigoSap, imeisList ->
                imeisEditados[codigoSap] = imeisList
            }
        )

        rvItens.layoutManager = LinearLayoutManager(context)
        rvItens.adapter = adapter

        fun atualizarBotaoConfirmar() {
            val itensSelecionados = adapter.algumItemSelecionado()
            val imeisOk = if (itensSelecionados) {
                adapter.imeisValidos()
            } else true
            val habilitado = (itensSelecionados || nenhumItemMarcado) && imeisOk
            btnConfirmar.isEnabled = habilitado
            btnConfirmar.alpha = if (habilitado) 1f else 0.5f
            btnConfirmar.background = if (habilitado) {
                ContextCompat.getDrawable(context, R.drawable.bg_badge_green)
            } else {
                ContextCompat.getDrawable(context, R.drawable.bg_badge_gray)
            }
        }

        cbNenhumItem.setOnCheckedChangeListener { _, isChecked ->
            nenhumItemMarcado = isChecked
            adapter.desmarcarTodos()
            atualizarBotaoConfirmar()
        }

        adapter.onSelecaoChanged = { atualizarBotaoConfirmar() }

        btnCancelar.setOnClickListener {
            dialog.dismiss()
            onCancel()
        }

        btnConfirmar.setOnClickListener {
            if (!btnConfirmar.isEnabled) return@setOnClickListener
            dialog.dismiss()
            
            // Verificar se algum item foi selecionado ou se "nenhum item" está marcado
            if (nenhumItemMarcado) {
                // Se "nenhum item" está marcado, confirmar com quantidades zeradas
                val quantidadesZeradas = pedido.itens?.associate { 
                    (it.codigoSAP ?: "") to 0 
                } ?: emptyMap()
                onConfirm(quantidadesZeradas, emptyMap())
                return@setOnClickListener
            }
            
            AlertDialog.Builder(context)
                .setTitle(context.getString(R.string.confirmar_pedido))
                .setMessage(context.getString(R.string.confirmar_pedido_mensagem))
                .setPositiveButton(context.getString(R.string.confirmar)) { _, _ ->
                    onConfirm(quantidadesEditadas, imeisEditados)
                }
                .setNegativeButton(context.getString(R.string.cancelar)) { _, _ ->
                    onCancel()
                }
                .show()
        }

        builder.setView(view)
        builder.setCancelable(true)

        dialog = builder.create()
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)

        // Configuração para o teclado
        dialog.window?.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE or
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        )

        dialog.setOnShowListener {
            view.postDelayed({
                val primeiroEditText = encontrarPrimeiroEditText(rvItens)
                primeiroEditText?.let { editText ->
                    editText.requestFocus()
                    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)
                    Log.d("ItemQuantidadeDialog", "✅ Teclado forçado")
                }
            }, 500)
        }

        dialog.show()
        dialog.window?.setLayout(
            (context.resources.displayMetrics.widthPixels * 0.92).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    // Função para encontrar o primeiro EditText
    private fun encontrarPrimeiroEditText(recyclerView: RecyclerView): EditText? {
        val layoutManager = recyclerView.layoutManager as? LinearLayoutManager ?: return null
        val firstVisiblePosition = layoutManager.findFirstVisibleItemPosition()

        if (firstVisiblePosition != RecyclerView.NO_POSITION) {
            val viewHolder = recyclerView.findViewHolderForAdapterPosition(firstVisiblePosition)
            if (viewHolder != null) {
                val itemView = viewHolder.itemView
                val editText = itemView.findViewById<EditText>(R.id.etQuantidade)
                if (editText != null) {
                    return editText
                }
            }
        }
        return null
    }

    // ============================================
    // ADAPTER INTERNO
    // ============================================

    private inner class ItemQuantidadeAdapter(
        private val items: List<Item>,
        private val onQuantidadeChanged: (String, Int) -> Unit,
        private val onImeisChanged: (String, List<String>) -> Unit
    ) : RecyclerView.Adapter<ItemQuantidadeAdapter.ViewHolder>() {

        private val quantidades: MutableMap<String, Int> =
            items.associate { (it.codigoSAP ?: "") to it.quantidade }.toMutableMap()
        private val imeis: MutableMap<String, List<String>> =
            items.associate { (it.codigoSAP ?: "") to (it.imeis?.flatten() ?: emptyList()) }.toMutableMap()
        private val selecionados: MutableSet<String> = mutableSetOf()
        var onSelecaoChanged: (() -> Unit)? = null

        fun algumItemSelecionado(): Boolean = selecionados.isNotEmpty()

        fun imeisValidos(): Boolean {
            return items.all { item ->
                val codigo = item.codigoSAP ?: ""
                if (!selecionados.contains(codigo) || item.quantidadeImeis == 0) return@all true
                val imeisList = imeis[codigo] ?: emptyList()
                val needed = item.quantidadeImeis
                // Verifica se tem IMEIs suficientes e se não estão vazios
                imeisList.size >= needed && imeisList.take(needed).all { it.isNotBlank() && it.length >= 14 }
            }
        }

        fun desmarcarTodos() {
            selecionados.clear()
            notifyDataSetChanged()
            onSelecaoChanged?.invoke()
        }

        inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            val cbSelecionado: CheckBox = itemView.findViewById(R.id.cbItemSelecionado)
            val tvQuantidadeOriginal: TextView = itemView.findViewById(R.id.tvQuantidadeOriginal)
            val tvDescricao: TextView = itemView.findViewById(R.id.tvDescricaoItem)
            val tvCodigoSap: TextView = itemView.findViewById(R.id.tvCodigoSap)
            val tvEstoqueBadge: TextView = itemView.findViewById(R.id.tvEstoqueBadge)
            val etQuantidade: EditText = itemView.findViewById(R.id.etQuantidade)
            val tvStatusDisponivel: TextView = itemView.findViewById(R.id.tvStatusDisponivel)
            val layoutImeis: View = itemView.findViewById(R.id.layoutImeis)
            val tvImeiLabel: TextView = itemView.findViewById(R.id.tvImeiLabel)
            val etImei1: EditText = itemView.findViewById(R.id.etImei1)
            val etImei2: EditText = itemView.findViewById(R.id.etImei2)

            private var cbCheckedListener: CompoundButton.OnCheckedChangeListener? = null
            private var qtdWatcher: TextWatcher? = null
            private var imei1Watcher: TextWatcher? = null
            private var imei2Watcher: TextWatcher? = null

            fun bind(item: Item) {
                val codigo = item.codigoSAP ?: ""
                val qtdAtual = quantidades[codigo] ?: item.quantidade
                val precisaImei = item.quantidadeImeis > 0
                val itemSelecionado = selecionados.contains(codigo)

                cbSelecionado.isChecked = itemSelecionado
                tvQuantidadeOriginal.text = "${item.quantidade}x"
                tvDescricao.text = item.descricao ?: context.getString(R.string.sem_descricao)
                tvCodigoSap.text = context.getString(R.string.codigo_ean_sap, item.codigoEAN ?: "---", item.codigoSAP ?: "---")
                etQuantidade.setText(qtdAtual.toString())

                val estoque = item.estoque
                if (estoque != null) {
                    tvEstoqueBadge.text = context.getString(R.string.estoque_estimado, estoque.toString())
                    tvEstoqueBadge.visibility = View.VISIBLE
                } else {
                    tvEstoqueBadge.visibility = View.GONE
                }

                tvStatusDisponivel.text = context.getString(R.string.disponivel)
                tvStatusDisponivel.setTextColor(ContextCompat.getColor(context, R.color.verde))

                // ✅ CORREÇÃO: Mostrar IMEI apenas se o item for selecionado E precisar de IMEI
                val imeisAtuais = imeis[codigo] ?: listOf("", "")
                
                if (precisaImei && itemSelecionado) {
                    layoutImeis.visibility = View.VISIBLE
                    tvImeiLabel.visibility = View.VISIBLE
                    etImei1.visibility = View.VISIBLE
                    etImei1.setText(imeisAtuais.getOrElse(0) { "" })
                    
                    if (item.quantidadeImeis >= 2) {
                        etImei2.visibility = View.VISIBLE
                        etImei2.setText(imeisAtuais.getOrElse(1) { "" })
                    } else {
                        etImei2.visibility = View.GONE
                        etImei2.setText("")
                    }
                } else {
                    layoutImeis.visibility = View.GONE
                    tvImeiLabel.visibility = View.GONE
                    etImei1.visibility = View.GONE
                    etImei2.visibility = View.GONE
                }

                // Remove listeners antigos antes de adicionar novos
                cbCheckedListener?.let { cbSelecionado.setOnCheckedChangeListener(null) }
                qtdWatcher?.let { etQuantidade.removeTextChangedListener(it) }
                imei1Watcher?.let { etImei1.removeTextChangedListener(it) }
                imei2Watcher?.let { etImei2.removeTextChangedListener(it) }

                // ✅ Quando o checkbox for marcado/desmarcado, atualizar visibilidade do IMEI
                cbCheckedListener = CompoundButton.OnCheckedChangeListener { _, isChecked ->
                    if (isChecked) {
                        selecionados.add(codigo)
                        // Se precisar de IMEI, mostrar os campos
                        if (precisaImei) {
                            layoutImeis.visibility = View.VISIBLE
                            tvImeiLabel.visibility = View.VISIBLE
                            etImei1.visibility = View.VISIBLE
                            if (item.quantidadeImeis >= 2) {
                                etImei2.visibility = View.VISIBLE
                            }
                            // Forçar foco no primeiro campo de IMEI
                            etImei1.postDelayed({
                                etImei1.requestFocus()
                                val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                                imm.showSoftInput(etImei1, InputMethodManager.SHOW_IMPLICIT)
                            }, 300)
                        }
                    } else {
                        selecionados.remove(codigo)
                        // Esconder IMEI
                        layoutImeis.visibility = View.GONE
                        tvImeiLabel.visibility = View.GONE
                        etImei1.visibility = View.GONE
                        etImei2.visibility = View.GONE
                        // Limpar IMEIs
                        etImei1.setText("")
                        etImei2.setText("")
                        imeis[codigo] = emptyList()
                        onImeisChanged(codigo, emptyList())
                    }
                    onSelecaoChanged?.invoke()
                }
                cbSelecionado.setOnCheckedChangeListener(cbCheckedListener)

                // ✅ FORÇAR TECLADO AO CLICAR NO EditText de quantidade
                etQuantidade.setOnClickListener {
                    etQuantidade.requestFocus()
                    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showSoftInput(etQuantidade, InputMethodManager.SHOW_IMPLICIT)
                }

                // ✅ FORÇAR TECLADO AO GANHAR FOCO
                etQuantidade.setOnFocusChangeListener { _, hasFocus ->
                    if (hasFocus) {
                        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                        imm.showSoftInput(etQuantidade, InputMethodManager.SHOW_IMPLICIT)
                    }
                }

                qtdWatcher = object : TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                    override fun afterTextChanged(s: android.text.Editable?) {
                        val texto = s?.toString() ?: ""
                        val novaQtd = texto.toIntOrNull()
                        if (novaQtd != null && novaQtd >= 0) {
                            quantidades[codigo] = novaQtd
                            onQuantidadeChanged(codigo, novaQtd)
                        }
                    }
                }
                etQuantidade.addTextChangedListener(qtdWatcher)

                // ✅ TextWatcher para IMEI 1
                imei1Watcher = object : TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                    override fun afterTextChanged(s: android.text.Editable?) {
                        val imei1 = etImei1.text.toString()
                        val imei2 = etImei2.text.toString()
                        val lista = mutableListOf<String>()
                        if (imei1.isNotBlank()) lista.add(imei1)
                        if (imei2.isNotBlank()) lista.add(imei2)
                        imeis[codigo] = lista
                        onImeisChanged(codigo, lista)
                        onSelecaoChanged?.invoke()
                    }
                }
                etImei1.addTextChangedListener(imei1Watcher)

                // ✅ TextWatcher para IMEI 2
                imei2Watcher = object : TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                    override fun afterTextChanged(s: android.text.Editable?) {
                        val imei1 = etImei1.text.toString()
                        val imei2 = etImei2.text.toString()
                        val lista = mutableListOf<String>()
                        if (imei1.isNotBlank()) lista.add(imei1)
                        if (imei2.isNotBlank()) lista.add(imei2)
                        imeis[codigo] = lista
                        onImeisChanged(codigo, lista)
                        onSelecaoChanged?.invoke()
                    }
                }
                etImei2.addTextChangedListener(imei2Watcher)

                // ✅ FORÇAR TECLADO NOS CAMPOS DE IMEI
                etImei1.setOnClickListener {
                    etImei1.requestFocus()
                    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showSoftInput(etImei1, InputMethodManager.SHOW_IMPLICIT)
                }

                etImei2.setOnClickListener {
                    etImei2.requestFocus()
                    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showSoftInput(etImei2, InputMethodManager.SHOW_IMPLICIT)
                }
            }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_quantidade_dialog, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(items[position])
        }

        override fun getItemCount(): Int = items.size
    }
}