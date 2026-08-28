package io.maestro.ui.dialogs

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.maestro.R
import io.maestro.utils.toast
import io.maestro.network.models.Item
import io.maestro.network.models.Pedido
import io.maestro.utils.Colors

class SmartphoneConfirmacaoDialog(
    private val context: Context,
    private val pedido: Pedido,
    private val onConfirm: (Map<String, Int>, Map<String, List<String>>) -> Unit,
    private val onCancel: () -> Unit,
    private val onScanRequested: (() -> Unit)? = null
) {

    private var dialog: Dialog? = null
    private var currentScreen = 1
    private val quantidadesEditadas = mutableMapOf<String, Int>()
    private val imeisEditados = mutableMapOf<String, MutableList<String>>()

    private fun getItemKey(item: Item): String {
        return item.codigoSAP ?: item.codigoEAN ?: item.descricao ?: ""
    }

    fun show() {
        initQuantidadesIniciais()
        showScreen1()
    }

    fun reabrir() {
        showScreen1()
    }

    private fun initQuantidadesIniciais() {
        pedido.itens?.forEach { item ->
            val key = getItemKey(item)
            if (key.isNotEmpty()) {
                quantidadesEditadas[key] = item.quantidade
                imeisEditados[key] = mutableListOf()
            }
        }
    }

    private fun showScreen1() {
        val view = LayoutInflater.from(context).inflate(R.layout.dialog_smartphone_confirmacao_1, null)

        val tvTitulo = view.findViewById<TextView>(R.id.tvTituloPedido)
        val rvItens = view.findViewById<RecyclerView>(R.id.rvItensSmartphone)
        val btnFechar = view.findViewById<Button>(R.id.btnFechar)
        val btnConfirmar = view.findViewById<Button>(R.id.btnConfirmar)
        val fabScannerDialog = view.findViewById<com.google.android.material.floatingactionbutton.FloatingActionButton>(R.id.fabScannerDialogImei)

        fabScannerDialog.setOnClickListener { onScanRequested?.invoke() }

        tvTitulo.text = context.getString(R.string.dialog_confirmacao_titulo, pedido.codigoExterno ?: pedido.numero ?: "")

        rvItens.layoutManager = LinearLayoutManager(context)
        rvItens.setHasFixedSize(true)

        val itensSmartphone = pedido.itens?.filter { it.quantidadeImeis > 0 } ?: emptyList()
        
        if (itensSmartphone.isEmpty()) {
            context.toast(context.getString(R.string.dialog_smartphone_sem_itens))
            onCancel()
            return
        }

        val adapter = SmartphoneItemAdapter(
            items = itensSmartphone
        )
        rvItens.adapter = adapter

        dialog = Dialog(context)
        dialog?.setContentView(view)
        dialog?.setCancelable(false)
        dialog?.window?.setBackgroundDrawableResource(android.R.color.transparent)

        btnFechar.setOnClickListener {
            dialog?.dismiss()
            onCancel()
        }

        btnConfirmar.setOnClickListener {
            if (validarScreen1(itensSmartphone)) {
                dialog?.dismiss()
                showScreen2(itensSmartphone)
            }
        }

        dialog?.show()
        dialog?.window?.setLayout(
            (context.resources.displayMetrics.widthPixels * 0.92).toInt(),
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
        dialog?.window?.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE or
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        )
    }

    private fun validarScreen1(itens: List<Item>): Boolean {
        for (item in itens) {
            val codigo = getItemKey(item)
            val qtd = quantidadesEditadas[codigo] ?: 0

            if (qtd <= 0) {
                context.toast(context.getString(R.string.dialog_quantidade_invalida, item.descricao ?: ""))
                return false
            }

            val totalCampos = qtd * item.quantidadeImeis
            val imeis = (imeisEditados[codigo] ?: mutableListOf()).take(totalCampos)

            if (imeis.size < totalCampos || imeis.any { it.isBlank() }) {
                context.toast(context.getString(R.string.dialog_imei_obrigatorio, item.descricao ?: ""))
                return false
            }

            if (imeis.any { it.length < 15 }) {
                context.toast(context.getString(R.string.dialog_imei_invalido, item.descricao ?: ""))
                return false
            }
        }
        return true
    }

    fun preencherImeiEscaneado(imei: String) {
        val rv = dialog?.findViewById<RecyclerView>(R.id.rvItensSmartphone) ?: return
        val imeiLimpo = imei.trim().replace(Regex("[^0-9]"), "")
        if (imeiLimpo.length != 15) {
            context.toast(context.getString(R.string.dialog_imei_invalido_formato))
            return
        }
        for (i in 0 until rv.childCount) {
            val holder = rv.getChildViewHolder(rv.getChildAt(i)) as? SmartphoneItemAdapter.ViewHolder ?: continue
            if (holder.preencherImeiSeVazio(imeiLimpo)) {
                context.toast(context.getString(R.string.dialog_imei_escaneado_ok))
                return
            }
        }
        context.toast(context.getString(R.string.dialog_imei_sem_campo_livre))
    }

    private fun showScreen2(itens: List<Item>) {
        val view = LayoutInflater.from(context).inflate(R.layout.dialog_smartphone_confirmacao_2, null)

        val btnFechar = view.findViewById<Button>(R.id.btnFechar)
        val btnSim = view.findViewById<Button>(R.id.btnSim)
        val tvFinalQtde = view.findViewById<TextView>(R.id.final_qtde_display)

        var totalItens = 0
        for ((_, qtd) in quantidadesEditadas) {
            totalItens += qtd
        }
        tvFinalQtde.text = totalItens.toString()

        btnFechar.setOnClickListener {
            dialog?.dismiss()
            showScreen1()
        }

        btnSim.setOnClickListener {
            dialog?.dismiss()
            val imeisFinais = imeisEditados.mapValues { (codigo, lista) ->
                val qtd = quantidadesEditadas[codigo] ?: 0
                val item = itens.firstOrNull { getItemKey(it) == codigo }
                val campos = qtd * (item?.quantidadeImeis ?: 0)
                lista.take(campos).toList()
            }
            onConfirm(quantidadesEditadas.toMap(), imeisFinais)
        }

        dialog = Dialog(context)
        dialog?.setContentView(view)
        dialog?.setCancelable(false)
        dialog?.window?.setBackgroundDrawableResource(android.R.color.transparent)
        dialog?.show()
        dialog?.window?.setLayout(
            (context.resources.displayMetrics.widthPixels * 0.92).toInt(),
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
    }

    inner class SmartphoneItemAdapter(
        private val items: List<Item>
    ) : RecyclerView.Adapter<SmartphoneItemAdapter.ViewHolder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_smartphone_quantidade, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            holder.bind(items[position])
        }

        override fun getItemCount(): Int = items.size

        inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            private val cbItem: android.widget.CheckBox = itemView.findViewById(R.id.cbItemSelecionado)
            private val tvQuantidadeOriginal: TextView = itemView.findViewById(R.id.tvQuantidadeOriginal)
            private val tvDescricaoItem: TextView = itemView.findViewById(R.id.tvDescricaoItem)
            private val tvCodigoSap: TextView = itemView.findViewById(R.id.tvCodigoSap)
            private val tvEstoqueBadge: TextView = itemView.findViewById(R.id.tvEstoqueBadge)
            private val etQuantidade: EditText = itemView.findViewById(R.id.etQuantidade)
            private val ibQtdMinus: ImageButton = itemView.findViewById(R.id.ibQtdMinus)
            private val dividerImeis: View? = itemView.findViewById(R.id.dividerImeis)
            private val layoutImeis: LinearLayout = itemView.findViewById(R.id.layoutImeis)
            private val layoutImeiContainer: LinearLayout = itemView.findViewById(R.id.layoutImeiContainer)
            private val tvImeiLabel: TextView = itemView.findViewById(R.id.tvImeiLabel)
            private val etImeisList = mutableListOf<EditText>()

            fun preencherImeiSeVazio(imei: String): Boolean {
                for (etImei in etImeisList) {
                    if (etImei.text.isNullOrBlank()) {
                        etImei.setText(imei)
                        return true
                    }
                }
                return false
            }

            fun atualizarCheckbox(codigo: String, quantidadeOriginal: Int) {
                val alterado = (quantidadesEditadas[codigo] ?: quantidadeOriginal) != quantidadeOriginal
                cbItem.isChecked = true
                cbItem.buttonTintList = android.content.res.ColorStateList.valueOf(
                    if (alterado) Color.parseColor("#E61937")
                    else Color.parseColor("#2E7D32")
                )
                itemView.setBackgroundResource(
                    if (alterado) R.drawable.bg_item_card_smartphone_red
                    else R.drawable.bg_item_card_smartphone
                )
            }

            fun atualizarCamposImei(codigo: String, quantidadeImeisPorAparelho: Int, qtd: Int) {
                if (quantidadeImeisPorAparelho <= 0 || qtd <= 0) {
                    layoutImeis.visibility = View.GONE
                    dividerImeis?.visibility = View.GONE
                    layoutImeiContainer.removeAllViews()
                    etImeisList.clear()
                    return
                }
                layoutImeis.visibility = View.VISIBLE
                dividerImeis?.visibility = View.VISIBLE
                layoutImeiContainer.removeAllViews()
                etImeisList.clear()

                val totalCamposImei = qtd * quantidadeImeisPorAparelho

                tvImeiLabel.text = if (quantidadeImeisPorAparelho == 1) {
                    context.getString(R.string.imei_aparelho)
                } else {
                    context.getString(R.string.imeis_aparelhos)
                }

                for (i in 0 until totalCamposImei) {
                    val lista = imeisEditados.getOrPut(codigo) { mutableListOf() }
                    while (lista.size <= i) lista.add("")

                    val row = LinearLayout(itemView.context).apply {
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        )
                        orientation = LinearLayout.HORIZONTAL
                        gravity = android.view.Gravity.CENTER_VERTICAL
                        setPadding(0, 0, 0, (8 * itemView.context.resources.displayMetrics.density).toInt())
                    }

                    val tvItem = TextView(itemView.context).apply {
                        layoutParams = LinearLayout.LayoutParams(
                            (60 * itemView.context.resources.displayMetrics.density).toInt(),
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        )
                        gravity = android.view.Gravity.END
                        text = context.getString(R.string.item_numero, i + 1)
                        setTextColor(Color.parseColor("#9E9E9E"))
                        textSize = 12f
                        setPadding(0, 0, (8 * itemView.context.resources.displayMetrics.density).toInt(), 0)
                    }

                    val etImei = EditText(itemView.context).apply {
                        layoutParams = LinearLayout.LayoutParams(
                            0,
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                            1f
                        )
                        hint = context.getString(R.string.imei_obrigatorio, i + 1)
                        inputType = android.text.InputType.TYPE_CLASS_NUMBER
                        setBackgroundResource(R.drawable.bg_input_imei_red)
                        setPadding(16, 14, 16, 14)
                        textSize = 14f
                        setTextColor(Color.parseColor(Colors.DARK_TEXT))
                        setHintTextColor(Color.parseColor(Colors.HINT_TEXT))
                        isSingleLine = true
                        isFocusable = true
                        isFocusableInTouchMode = true
                        importantForAutofill = android.view.View.IMPORTANT_FOR_AUTOFILL_NO
                        setFilters(arrayOf(android.text.InputFilter.LengthFilter(15)))

                        if (i < imeisEditados[codigo]?.size ?: 0) {
                            setText(imeisEditados[codigo]!![i])
                        }
                    }

                    etImei.addTextChangedListener(object : android.text.TextWatcher {
                        override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                        override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                        override fun afterTextChanged(s: android.text.Editable?) {
                            val lista = imeisEditados.getOrPut(codigo) { mutableListOf() }
                            while (lista.size <= i) lista.add("")
                            lista[i] = s?.toString() ?: ""
                        }
                    })

                    row.addView(tvItem)
                    row.addView(etImei)
                    layoutImeiContainer.addView(row)
                    etImeisList.add(etImei)
                }
            }

            fun bind(item: Item) {
                val codigo = getItemKey(item)
                val qtdMax = item.quantidade
                val qtdAtual = quantidadesEditadas[codigo] ?: qtdMax
                val imeisAtuais = imeisEditados[codigo] ?: mutableListOf()

                tvQuantidadeOriginal.text = "${item.quantidade}x"
                tvDescricaoItem.text = item.descricao ?: context.getString(R.string.sem_descricao)
                
                val ean = item.codigoEAN ?: ""
                val sap = item.codigoSAP ?: ""
                var codigoStr = ""
                if (ean.isNotEmpty()) codigoStr += "EAN: $ean"
                if (sap.isNotEmpty()) {
                    if (codigoStr.isNotEmpty()) codigoStr += " / "
                    codigoStr += "SAP: $sap"
                }
                tvCodigoSap.text = codigoStr

                etQuantidade.setText(qtdAtual.toString())
                quantidadesEditadas[codigo] = qtdAtual

                atualizarCheckbox(codigo, qtdMax)

                val estoque = item.estoque
                if (estoque != null) {
                    tvEstoqueBadge.text = context.getString(R.string.estoque_estimado, estoque.toString())
                    tvEstoqueBadge.visibility = View.VISIBLE
                } else {
                    tvEstoqueBadge.visibility = View.GONE
                }

                atualizarCamposImei(codigo, item.quantidadeImeis, qtdAtual)

                ibQtdMinus.setOnClickListener {
                    val atual = etQuantidade.text.toString().toIntOrNull() ?: 0
                    if (atual > 1) {
                        val novaQtd = atual - 1
                        etQuantidade.setText(novaQtd.toString())
                        quantidadesEditadas[codigo] = novaQtd
                        atualizarCheckbox(codigo, qtdMax)
                        atualizarCamposImei(codigo, item.quantidadeImeis, novaQtd)
                    }
                }

                etQuantidade.addTextChangedListener(object : android.text.TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                    override fun afterTextChanged(s: android.text.Editable?) {
                        val texto = s?.toString() ?: ""
                        val novaQtd = texto.toIntOrNull() ?: 0
                        val key = getItemKey(item)
                        if (novaQtd > qtdMax) {
                            etQuantidade.setText(qtdMax.toString())
                            etQuantidade.setSelection(qtdMax.toString().length)
                            quantidadesEditadas[key] = qtdMax
                        } else {
                            quantidadesEditadas[key] = novaQtd
                        }
                        atualizarCheckbox(key, qtdMax)
                        atualizarCamposImei(key, item.quantidadeImeis, quantidadesEditadas[key] ?: 0)
                    }
                })

                etQuantidade.setOnClickListener {
                    etQuantidade.requestFocus()
                }
            }
        }
    }
}