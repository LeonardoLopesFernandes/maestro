package io.maestro.adapters

import android.content.Context
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.CheckBox
import android.widget.CompoundButton
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import io.maestro.R
import io.maestro.network.models.Item

class ItemQuantidadeNovoAdapter(
    private val items: List<Item>,
    private val onQuantidadeChanged: (String, Int) -> Unit,
    private val onImeisChanged: (String, List<String>) -> Unit,
    private val onSelectionChanged: () -> Unit
) : RecyclerView.Adapter<ItemQuantidadeNovoAdapter.ViewHolder>() {

    private val quantidades = items.associate { (it.codigoSAP ?: "") to it.quantidade }.toMutableMap()
    private val imeis = items.associate { (it.codigoSAP ?: "") to mutableListOf<String>() }.toMutableMap()
    private val selecionados = items.associate { (it.codigoSAP ?: "") to false }.toMutableMap()

    private fun identificarMarca(descricao: String): String {
        val desc = descricao.uppercase()
        return when {
            desc.contains("SAMSUNG") -> "SAMSUNG"
            desc.contains("MOTOROLA") -> "MOTOROLA"
            else -> "OUTRO"
        }
    }

    private fun getQuantidadeImeis(descricao: String): Int {
        val marca = identificarMarca(descricao)
        return when (marca) {
            "SAMSUNG" -> 1
            "MOTOROLA" -> 2
            else -> 0
        }
    }

    fun getQuantidades(): Map<String, Int> {
        val result = mutableMapOf<String, Int>()
        for ((codigo, selecionado) in selecionados) {
            if (selecionado) {
                result[codigo] = quantidades[codigo] ?: 0
            }
        }
        return result
    }

    fun getImeis(): Map<String, List<String>> = imeis

    fun algumItemSelecionado(): Boolean = selecionados.any { it.value }

    fun limparSelecao() {
        for (key in selecionados.keys) {
            selecionados[key] = false
        }
        notifyDataSetChanged()
    }

    inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val cbItem: CheckBox = itemView.findViewById(R.id.cbItemSelecionado)
        val tvDescricao: TextView = itemView.findViewById(R.id.tvDescricaoItem)
        val tvCodigo: TextView = itemView.findViewById(R.id.tvCodigo)
        val tvEstoqueBadge: TextView = itemView.findViewById(R.id.tvEstoqueBadge)
        val tvQuantidadeOriginal: TextView = itemView.findViewById(R.id.tvQuantidadeOriginal)
        val etQuantidade: EditText = itemView.findViewById(R.id.etQuantidade)
        val layoutImeis: LinearLayout = itemView.findViewById(R.id.layoutImeis)
        val tvImeiLabel: TextView = itemView.findViewById(R.id.tvImeiLabel)
        val etImei1: EditText = itemView.findViewById(R.id.etImei1)
        val etImei2: EditText = itemView.findViewById(R.id.etImei2)
        val divider: View = itemView.findViewById(R.id.divider)

        private var cbCheckedListener: CompoundButton.OnCheckedChangeListener? = null
        private var imei1Watcher: TextWatcher? = null
        private var imei2Watcher: TextWatcher? = null

        fun bind(item: Item) {
            // Hide divider on last item
            divider.visibility = if (adapterPosition == itemCount - 1) View.GONE else View.VISIBLE
            val codigo = item.codigoSAP ?: ""
            val qtdAtual = quantidades[codigo] ?: item.quantidade
            val qtdImeis = getQuantidadeImeis(item.descricao ?: "")

            cbItem.isChecked = selecionados[codigo] ?: false
            tvDescricao.text = (item.descricao ?: "Produto sem descrição").uppercase()
            tvCodigo.text = "EAN: ${item.codigoEAN ?: "---"} / SAP: ${item.codigoSAP ?: "---"}"
            tvQuantidadeOriginal.text = "${item.quantidade}x"
            etQuantidade.setText(qtdAtual.toString())

            val estoque = item.estoque
            if (estoque != null) {
                tvEstoqueBadge.text = "Estoque estimado: $estoque"
                tvEstoqueBadge.visibility = View.VISIBLE
            } else {
                tvEstoqueBadge.visibility = View.GONE
            }

            if (qtdImeis > 0) {
                layoutImeis.visibility = View.VISIBLE
                tvImeiLabel.text = if (qtdImeis == 1) "IMEI do Item:" else "IMEIs do Item:"
                etImei1.visibility = View.VISIBLE
                if (qtdImeis >= 2) {
                    etImei2.visibility = View.VISIBLE
                } else {
                    etImei2.visibility = View.GONE
                }
            } else {
                layoutImeis.visibility = View.GONE
                etImei1.visibility = View.GONE
                etImei2.visibility = View.GONE
            }

            // Remove listeners antigos antes de adicionar novos
            cbCheckedListener?.let { cbItem.setOnCheckedChangeListener(null) }
            imei1Watcher?.let { etImei1.removeTextChangedListener(it) }
            imei2Watcher?.let { etImei2.removeTextChangedListener(it) }

            cbCheckedListener = CompoundButton.OnCheckedChangeListener { _, isChecked ->
                selecionados[codigo] = isChecked
                onSelectionChanged()
            }
            cbItem.setOnCheckedChangeListener(cbCheckedListener)

            etQuantidade.setOnFocusChangeListener { _, hasFocus ->
                if (!hasFocus) {
                    val texto = etQuantidade.text.toString()
                    val novaQtd = texto.toIntOrNull()
                    if (novaQtd != null && novaQtd >= 0) {
                        quantidades[codigo] = novaQtd
                        onQuantidadeChanged(codigo, novaQtd)
                    } else {
                        etQuantidade.setText(quantidades[codigo].toString())
                    }
                } else {
                    val imm = itemView.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showSoftInput(etQuantidade, InputMethodManager.SHOW_IMPLICIT)
                }
            }

            etQuantidade.setOnClickListener {
                etQuantidade.requestFocus()
                val imm = itemView.context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                imm.showSoftInput(etQuantidade, InputMethodManager.SHOW_IMPLICIT)
            }

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
                }
            }
            etImei1.addTextChangedListener(imei1Watcher)

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
                }
            }
            etImei2.addTextChangedListener(imei2Watcher)
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_quantidade_novo, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size
}
