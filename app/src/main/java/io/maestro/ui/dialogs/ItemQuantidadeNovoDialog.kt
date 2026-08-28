package io.maestro.ui.dialogs

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import io.maestro.R
import io.maestro.network.models.Item
import io.maestro.network.models.Pedido
import io.maestro.utils.Colors

class ItemQuantidadeNovoDialog(
    private val context: Context,
    private val pedido: Pedido,
    private val onConfirm: (Map<String, Int>) -> Unit,
    private val onRecusar: (Map<String, Int>) -> Unit
) {

    private lateinit var dialog: Dialog
    private lateinit var btnConfirmar: Button
    private lateinit var cbNenhumItem: CheckBox
    private val quantidades = mutableMapOf<String, Int>()
    private val selecionados = mutableMapOf<String, Boolean>()
    private val itemViews = mutableListOf<View>()
    private var nenhumItemMarcado = false
    private var construido = false

    fun show() {
        if (!construido) {
            construir()
            construido = true
        }
        dialog.show()
        dialog.window?.setLayout(
            (context.resources.displayMetrics.widthPixels * 0.92).toInt(),
            WindowManager.LayoutParams.WRAP_CONTENT
        )
    }

    fun reabrir() {
        show()
    }

    private fun construir() {
        val view = LayoutInflater.from(context).inflate(R.layout.dialog_item_quantidade_novo, null)

        btnConfirmar = view.findViewById(R.id.btnConfirmar)
        val btnCancelar = view.findViewById<Button>(R.id.btnCancelar)
        val tvTitulo = view.findViewById<TextView>(R.id.tvTituloConfirmacao)
        cbNenhumItem = view.findViewById(R.id.cbNenhumItem)
        val layoutNenhumItem = view.findViewById<LinearLayout>(R.id.layoutNenhumItem)
        val itensContainer = view.findViewById<LinearLayout>(R.id.layoutItensContainer)

        tvTitulo.text = "${context.getString(R.string.dialog_confirmacao_titulo, pedido.codigoExterno ?: "")}."

        val items = pedido.itens ?: emptyList()

        val atualizarBotao: () -> Unit = {
            val algumSelecionado = selecionados.any { it.value }
            val habilitado = algumSelecionado || nenhumItemMarcado
            val temAlteracao = items.any { item ->
                val codigo = item.codigoSAP ?: ""
                (quantidades[codigo] ?: item.quantidade) != item.quantidade
            }
            btnConfirmar.isEnabled = habilitado
            btnConfirmar.backgroundTintList = null
            btnConfirmar.setTextColor(
                if (habilitado) ContextCompat.getColor(context, R.color.white)
                else ContextCompat.getColor(context, R.color.gray)
            )
            btnConfirmar.background = when {
                !habilitado -> ContextCompat.getDrawable(context, R.drawable.bg_btn_disabled)
                temAlteracao -> ContextCompat.getDrawable(context, R.drawable.bg_btn_confirm_red)
                else -> ContextCompat.getDrawable(context, R.drawable.bg_btn_confirm_enabled)
            }
        }

        // Inflar views dos itens
        for (item in items) {
            val codigo = item.codigoSAP ?: ""
            val quantidadeOriginal = item.quantidade
            quantidades[codigo] = quantidadeOriginal
            selecionados[codigo] = false

            val itemView = LayoutInflater.from(context)
                .inflate(R.layout.item_quantidade_novo, itensContainer, false)

            val cbItem = itemView.findViewById<CheckBox>(R.id.cbItemSelecionado)
            val tvDescricao = itemView.findViewById<TextView>(R.id.tvDescricaoItem)
            val tvCodigo = itemView.findViewById<TextView>(R.id.tvCodigo)
            val tvEstoqueBadge = itemView.findViewById<TextView>(R.id.tvEstoqueBadge)
            val tvQuantidadeOriginal = itemView.findViewById<TextView>(R.id.tvQuantidadeOriginal)
            val etQuantidade = itemView.findViewById<EditText>(R.id.etQuantidade)
            val divider = itemView.findViewById<View>(R.id.divider)

            fun atualizarFundoItem() {
                val selecionado = selecionados[codigo] == true
                val alterado = quantidades[codigo] != quantidadeOriginal
                val corFundo = when {
                    !selecionado -> Color.parseColor(Colors.GRAY_100)
                    alterado -> Color.parseColor(Colors.RED_LIGHT)
                    else -> Color.parseColor(Colors.GREEN_600)
                }
                val bg = GradientDrawable().apply {
                    cornerRadii = floatArrayOf(8f, 8f, 8f, 8f, 8f, 8f, 8f, 8f)
                    setColor(corFundo)
                }
                itemView.background = bg
                itemView.setPadding(8, 8, 8, 8)
                val qtdeLabel = itemView.findViewById<TextView>(R.id.tvQtdeLabel)
                if (qtdeLabel != null) {
                    qtdeLabel.background = GradientDrawable().apply {
                        setColor(corFundo)
                    }
                }
                cbItem.buttonTintList = android.content.res.ColorStateList.valueOf(
                    if (alterado) Color.parseColor("#E61937")
                    else Color.parseColor("#2E7D32")
                )
            }

            // Esconder divider do último item
            divider.visibility = if (item == items.last()) View.GONE else View.VISIBLE

            tvDescricao.text = (item.descricao ?: context.getString(R.string.produto_sem_descricao)).uppercase()
            tvCodigo.text = context.getString(R.string.codigo_ean_sap, item.codigoEAN ?: "---", item.codigoSAP ?: "---")
            tvQuantidadeOriginal.text = "${quantidadeOriginal}x"
            etQuantidade.setText(quantidadeOriginal.toString())

            val estoque = item.estoque
            if (estoque != null) {
                tvEstoqueBadge.text = context.getString(R.string.estoque_estimado, estoque.toString())
                tvEstoqueBadge.visibility = View.VISIBLE
            } else {
                tvEstoqueBadge.visibility = View.GONE
            }

            atualizarFundoItem()

            itemView.setOnClickListener {
                cbItem.isChecked = !cbItem.isChecked
            }

            cbItem.setOnCheckedChangeListener { _, isChecked ->
                selecionados[codigo] = isChecked
                atualizarFundoItem()
                atualizarBotao()
            }

            var updating = false
            etQuantidade.addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                override fun afterTextChanged(s: Editable?) {
                    if (updating) return
                    val texto = s?.toString() ?: ""
                    val novaQtd = texto.toIntOrNull()
                    if (novaQtd != null && novaQtd >= 0) {
                        if (novaQtd > quantidadeOriginal) {
                            updating = true
                            etQuantidade.setText(quantidadeOriginal.toString())
                            etQuantidade.setSelection(etQuantidade.text.length)
                            updating = false
                        } else {
                            quantidades[codigo] = novaQtd
                            atualizarFundoItem()
                            atualizarBotao()
                        }
                    }
                }
            })

            etQuantidade.setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) {
                    val texto = etQuantidade.text.toString()
                    val novaQtd = texto.toIntOrNull()
                    if (novaQtd == null || novaQtd < 0) {
                        etQuantidade.setText(quantidades[codigo].toString())
                    } else if (novaQtd > quantidadeOriginal) {
                        etQuantidade.setText(quantidadeOriginal.toString())
                    }
                } else {
                    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showSoftInput(etQuantidade, InputMethodManager.SHOW_IMPLICIT)
                }
                atualizarBotao()
            }

            etQuantidade.setOnClickListener {
                etQuantidade.requestFocus()
                val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                imm.showSoftInput(etQuantidade, InputMethodManager.SHOW_IMPLICIT)
            }

            itensContainer.addView(itemView)
            itemViews.add(itemView)
        }

        atualizarBotao()

        cbNenhumItem.setOnCheckedChangeListener { _, isChecked ->
            nenhumItemMarcado = isChecked
            if (isChecked) {
                for (itemView in itemViews) {
                    val cb = itemView.findViewById<CheckBox>(R.id.cbItemSelecionado)
                    cb.isChecked = false
                }
            }
            atualizarBotao()
        }

        layoutNenhumItem.setOnClickListener {
            cbNenhumItem.isChecked = !cbNenhumItem.isChecked
        }

        btnCancelar.setOnClickListener {
            dialog.dismiss()
        }

        btnConfirmar.setOnClickListener {
            if (!btnConfirmar.isEnabled) return@setOnClickListener
            dialog.dismiss()

            if (nenhumItemMarcado) {
                val quantidadesZeradas = pedido.itens?.associate {
                    (it.codigoSAP ?: "") to 0
                } ?: emptyMap()
                onRecusar(quantidadesZeradas)
            } else {
                val result = mutableMapOf<String, Int>()
                for ((codigo, selecionado) in selecionados) {
                    if (selecionado) {
                        result[codigo] = quantidades[codigo] ?: 0
                    }
                }
                onConfirm(result)
            }
        }

        dialog = Dialog(context)
        dialog.setContentView(view)
        dialog.setCancelable(true)
        dialog.window?.setBackgroundDrawableResource(android.R.color.transparent)
        dialog.window?.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE or
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN
        )
    }
}
