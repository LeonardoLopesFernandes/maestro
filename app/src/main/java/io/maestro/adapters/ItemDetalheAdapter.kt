package io.maestro.adapters

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import io.maestro.R
import io.maestro.network.models.Item

class ItemDetalheAdapter(
    private var items: List<Item>,
    private val pedidoStatus: String? = null
) : RecyclerView.Adapter<ItemDetalheAdapter.ViewHolder>() {

    inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val tvQuantidade: TextView = itemView.findViewById(R.id.tvQuantidade)
        val tvDescricao: TextView = itemView.findViewById(R.id.tvDescricao)
        val tvCodigo: TextView = itemView.findViewById(R.id.tvCodigo)
        val tvValorTotal: TextView = itemView.findViewById(R.id.tvValorTotal)
        val tvValorUnitario: TextView = itemView.findViewById(R.id.tvValorUnitario)
        val tvImeis: TextView = itemView.findViewById(R.id.tvImeis)
        val tvImeisLabel: TextView = itemView.findViewById(R.id.tvImeisLabel)
        val layoutImeis: View = itemView.findViewById(R.id.layoutImeis)
        val tvEstoqueBadge: TextView = itemView.findViewById(R.id.tvEstoqueBadge)
        val layoutEstoqueBadge: View = itemView.findViewById(R.id.layoutEstoqueBadge)
        val divider: View = itemView.findViewById(R.id.dividerItem)

        fun bind(item: Item, isLast: Boolean) {
            val qtd = item.quantidadeTotal ?: item.quantidade
            tvQuantidade.text = "${qtd}x"
            tvDescricao.text = item.descricao ?: "Produto sem descrição"

            val ean = item.codigoEAN ?: "---"
            val sap = item.codigoSAP ?: "---"
            tvCodigo.text = "EAN: $ean / SAP: $sap"

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
            val status = pedidoStatus?.uppercase()?.trim()
            if (estoque != null && status in listOf("NOVO_PEDIDO", "NOVO", "EM_SEPARACAO", "SEPARACAO", "PRONTO_PARA_SAIR", "PRONTO")) {
                tvEstoqueBadge.text = "Estoque estimado: $estoque"
                layoutEstoqueBadge.visibility = View.VISIBLE
            } else {
                layoutEstoqueBadge.visibility = View.GONE
            }

            divider.visibility = if (isLast) View.GONE else View.VISIBLE

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
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_detalhe_item, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(items[position], position == itemCount - 1)
    }

    override fun getItemCount(): Int = items.size

    fun updateItems(newItems: List<Item>) {
        items = newItems
        notifyDataSetChanged()
    }
}
