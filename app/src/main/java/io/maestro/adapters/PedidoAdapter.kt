package io.maestro.adapters

import android.content.res.ColorStateList
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.RecyclerView
import io.maestro.R
import io.maestro.network.models.HorarioLoja
import io.maestro.network.models.Pedido
import io.maestro.network.SessionManager
import java.text.SimpleDateFormat
import java.util.*

class PedidoAdapter(
    private var pedidos: List<Pedido>,
    private val listenerAcao: OnPedidoAcaoListener? = null,
    private val onItemClick: (Pedido) -> Unit,
    private val onBadgeDevolvidoClick: ((Pedido) -> Unit)? = null,
    private val onBadgeCancelClick: ((Pedido) -> Unit)? = null
) : RecyclerView.Adapter<PedidoAdapter.ViewHolder>() {

    private val attachedViewHolders = mutableSetOf<ViewHolder>()

    interface OnPedidoAcaoListener {
        fun onExecutarAcao(pedido: Pedido, acao: String, posicao: Int)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_pedido, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val pedido = pedidos[position]
        val ctx = holder.itemView.context

        holder.tvNumero.text = pedido.codigoExterno
        holder.tvCliente.text = pedido.cliente?.nome ?: "Cliente não informado"
        holder.layoutDuracao.visibility = View.GONE
        holder.removerAtualizacaoTempo()

        // Estilizar tvBadgeNovo como badge arredondado conforme o status
        val status = pedido.status?.uppercase()?.trim()
        val dateFormat = DATE_FORMAT
        val inputFormat = INPUT_FORMAT
        when (status) {
            "NOVO_PEDIDO", "NOVO" -> {
                holder.tvBadgeNovo.background = ContextCompat.getDrawable(ctx, R.drawable.bg_badge_green)
                holder.tvBadgeNovo.setTextColor(ContextCompat.getColor(ctx, R.color.white))
                holder.tvBadgeNovo.text = "NOVO"
                holder.tvBadgeNovo.visibility = View.VISIBLE
            }
            "EM_SEPARACAO", "SEPARACAO" -> {
                holder.tvBadgeNovo.background = ContextCompat.getDrawable(ctx, R.drawable.bg_badge_orange)
                holder.tvBadgeNovo.setTextColor(ContextCompat.getColor(ctx, R.color.white))
                holder.tvBadgeNovo.text = "Separação"
                holder.tvBadgeNovo.visibility = View.VISIBLE
            }
            "PRONTO_PARA_SAIR", "PRONTO" -> {
                holder.tvBadgeNovo.background = ContextCompat.getDrawable(ctx, R.drawable.bg_badge_orange)
                holder.tvBadgeNovo.setTextColor(ContextCompat.getColor(ctx, R.color.white))
                holder.tvBadgeNovo.text = "Pronto para Retirada"
                holder.tvBadgeNovo.visibility = View.VISIBLE
            }
            "SAIU_PARA_ENTREGA" -> {
                holder.tvBadgeNovo.background = ContextCompat.getDrawable(ctx, R.drawable.bg_badge_purple)
                holder.tvBadgeNovo.setTextColor(ContextCompat.getColor(ctx, R.color.white))
                holder.tvBadgeNovo.text = "Saiu Para Entrega"
                holder.tvBadgeNovo.visibility = View.VISIBLE
            }
            "FINALIZADO", "ENTREGUE" -> {
                holder.tvBadgeNovo.background = ContextCompat.getDrawable(ctx, R.drawable.bg_badge_green)
                holder.tvBadgeNovo.setTextColor(ContextCompat.getColor(ctx, R.color.white))
                holder.tvBadgeNovo.text = "Entregue"
                holder.tvBadgeNovo.visibility = View.VISIBLE
                holder.tvBadgeNovo.setOnClickListener(null)
            }
            "CANCELADO" -> {
                holder.tvBadgeNovo.background = ContextCompat.getDrawable(ctx, R.drawable.bg_badge_red)
                holder.tvBadgeNovo.setTextColor(ContextCompat.getColor(ctx, R.color.white))
                holder.tvBadgeNovo.text = "Cancelado"
                holder.tvBadgeNovo.visibility = View.VISIBLE
                holder.tvBadgeNovo.setOnClickListener(null)
            }
            "DEVOLVIDO" -> {
                holder.tvBadgeNovo.background = ContextCompat.getDrawable(ctx, R.drawable.bg_badge_red)
                holder.tvBadgeNovo.setTextColor(ContextCompat.getColor(ctx, R.color.white))
                holder.tvBadgeNovo.text = "Devolvido"
                holder.tvBadgeNovo.visibility = View.VISIBLE
                holder.tvBadgeNovo.setOnClickListener(null)
            }
            "RETORNAR_PARA_ESTOQUE" -> {
                holder.tvBadgeNovo.background = ContextCompat.getDrawable(ctx, R.drawable.bg_badge_red)
                holder.tvBadgeNovo.setTextColor(ContextCompat.getColor(ctx, R.color.white))
                holder.tvBadgeNovo.text = "RETORNAR AO ESTOQUE"
                holder.tvBadgeNovo.visibility = View.VISIBLE
            }
            else -> {
                holder.tvBadgeNovo.background = null
                holder.tvBadgeNovo.setTextColor(ContextCompat.getColor(ctx, R.color.black_text))
                holder.tvBadgeNovo.text = formatStatusVisivel(pedido.status)
                holder.tvBadgeNovo.visibility = View.VISIBLE
            }
        }

        holder.ivEdit.visibility = View.GONE

        val editado = pedidoFoiEditado(ctx, pedido)
        if (editado && status in listOf("PRONTO_PARA_SAIR", "PRONTO")) {
            holder.ivEdit.visibility = View.VISIBLE
            holder.ivEdit.setColorFilter(ContextCompat.getColor(ctx, R.color.blue_primary))
        }

        // Contador de tempo real para NOVO_PEDIDO e EM_SEPARACAO
        if (status in listOf("NOVO_PEDIDO", "NOVO", "EM_SEPARACAO", "SEPARACAO")) {
            val tempoConfirmacao = pedido.tempoConfirmacao
            if (tempoConfirmacao != null) {
                holder.atualizarTempo(kotlin.math.abs(tempoConfirmacao))
            } else {
                val dataInclusao = pedido.dataInclusao
                if (dataInclusao.isNotEmpty()) {
                    try {
                        val dataCriacao = inputFormat.parse(dataInclusao)
                        if (dataCriacao != null) {
                            holder.atualizarTempoFallback(dataCriacao.time, pedido.horariosLoja)
                        }
                    } catch (_: Exception) { }
                }
            }
        } else {
            holder.removerAtualizacaoTempo()
            holder.layoutDuracao.visibility = View.GONE
        }

        // Exibição das TAGS (Badge)
        if (!pedido.canalDeVendas.isNullOrEmpty()) {
            val canal = pedido.canalDeVendas
            holder.tvCanalTag.text = when {
                canal.equals("EXTERNA", ignoreCase = true) -> "Delivery"
                canal.equals("Americanas Externa", ignoreCase = true) -> "Americanas Delivery"
                else -> canal
            }
            holder.tvCanalTag.background = if (canal.contains("Magazine", ignoreCase = true))
                ContextCompat.getDrawable(ctx, R.drawable.bg_badge_blue)
            else
                ContextCompat.getDrawable(ctx, R.drawable.bg_badge_red)
            holder.tvCanalTag.visibility = View.VISIBLE
        } else {
            holder.tvCanalTag.visibility = View.GONE
        }

        if (!pedido.tipoEntrega.isNullOrEmpty()) {
            holder.tvEntregaTag.text = when (pedido.tipoEntrega.uppercase()) {
                "RETIRADA" -> "Pegue na Loja Hoje"
                "EXTERNA" -> "Delivery"
                else -> pedido.tipoEntrega
            }
            holder.tvEntregaTag.visibility = View.VISIBLE
        } else {
            holder.tvEntregaTag.visibility = View.GONE
        }

        holder.tvData.text = formatDate(pedido.dataInclusao)

        val valorBruto = pedido.valorTotal
        holder.tvValor.text = "R$ " + String.format("%.2f", valorBruto).replace(".", ",")

        holder.itemView.setOnClickListener { onItemClick(pedido) }

        if (listenerAcao == null) {
            holder.btnAcao.visibility = View.GONE
            return
        }

        when (pedido.status?.uppercase()?.trim()) {
            "NOVO_PEDIDO", "INCLUIDO", "VISUALIZADO", "NOVO" -> {
                holder.btnAcao.visibility = View.VISIBLE
                holder.btnAcao.text = "Em Separação"
                holder.btnAcao.backgroundTintList = ColorStateList.valueOf(ContextCompat.getColor(ctx, R.color.btn_novo))
                holder.btnAcao.setOnClickListener { listenerAcao.onExecutarAcao(pedido, "SEPARAR", position) }
            }
            "EM_SEPARACAO", "SEPARACAO" -> {
                holder.btnAcao.visibility = View.VISIBLE
                holder.btnAcao.text = "Confirmar Separação"
                holder.btnAcao.backgroundTintList = ColorStateList.valueOf(ContextCompat.getColor(ctx, R.color.verde))
                holder.btnAcao.setOnClickListener { listenerAcao.onExecutarAcao(pedido, "CONFIRMAR", position) }
            }
            "PRONTO_PARA_SAIR", "PRONTO" -> {
                holder.btnAcao.visibility = View.VISIBLE
                holder.btnAcao.text = "Retirar Pedido"
                holder.btnAcao.backgroundTintList = ColorStateList.valueOf(ContextCompat.getColor(ctx, R.color.btn_pronto))
                holder.btnAcao.setOnClickListener { listenerAcao.onExecutarAcao(pedido, "RETIRAR", position) }
            }
            else -> holder.btnAcao.visibility = View.GONE
        }
    }

    override fun getItemCount(): Int = pedidos.size

    fun getItem(position: Int): Pedido = pedidos[position]

    fun updateItems(newPedidos: List<Pedido>) {
        this.pedidos = newPedidos
        notifyDataSetChanged()
    }

    private fun pedidoFoiEditado(ctx: android.content.Context, pedido: Pedido): Boolean {
        val session = SessionManager(ctx)
        return session.isPedidoEditado(pedido.numero)
    }

    private fun formatStatusVisivel(status: String?): String {
        return when (status?.uppercase()?.trim()) {
            "NOVO_PEDIDO", "NOVO" -> "NOVO"
            "EM_SEPARACAO", "SEPARACAO" -> "📦 SEPARAÇÃO"
            "PRONTO_PARA_SAIR", "PRONTO" -> "Pronto para Retirada"
            "SAIU_PARA_ENTREGA" -> "Saiu Para Entrega"
            "FINALIZADO", "ENTREGUE" -> "Entregue"
            "CANCELADO" -> "❌ CANCELADO"
            "DEVOLVIDO" -> "🔄 DEVOLVIDO"
            "RETORNAR_PARA_ESTOQUE" -> "RETORNAR AO ESTOQUE"
            "PREVISTO" -> "📅 PREVISTO"
            "EDITADO" -> "✏️ EDITADO"
            else -> status ?: "-"
        }
    }

    private fun formatDate(dataInclusao: String?): String {
        if (dataInclusao.isNullOrEmpty()) return "--/--/---- --:--"
        return try {
            val date = INPUT_FORMAT.parse(dataInclusao)
            date?.let { DATE_FORMAT.format(it) } ?: dataInclusao
        } catch (e: Exception) { dataInclusao }
    }

    class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val tvNumero: TextView = itemView.findViewById(R.id.tvNumero)
        val ivEdit: ImageView = itemView.findViewById(R.id.ivEdit)
        val tvBadgeNovo: TextView = itemView.findViewById(R.id.tvBadgeNovo)
        val tvCliente: TextView = itemView.findViewById(R.id.tvCliente)
        val tvCanalTag: TextView = itemView.findViewById(R.id.tvCanalTag)
        val tvEntregaTag: TextView = itemView.findViewById(R.id.tvEntregaTag)
        val tvData: TextView = itemView.findViewById(R.id.tvData)
        val tvValor: TextView = itemView.findViewById(R.id.tvValor)
        val tvTempoConfirmacao: TextView = itemView.findViewById(R.id.tvTempoConfirmacao)
        val layoutDuracao: LinearLayout = itemView.findViewById(R.id.layoutDuracao)
        val viewBarraProgresso: View = itemView.findViewById(R.id.viewBarraProgresso)
        val btnAcao: Button = itemView.findViewById(R.id.btnAcaoPedido)

        private var hasTimer = false
        private var momentoReferencia: Long = 0L
        private var tempoConfirmacaoMs: Long = 0L
        private var tempoCriacaoMs: Long = 0L
        private var horariosLoja: List<HorarioLoja>? = null
        private var isFallback = false

        private fun atualizarBarraProgresso(totalMin: Int) {
            val porcentagem = ((totalMin.toFloat() / 30f) * 100f).coerceAtMost(100f)
            val params = viewBarraProgresso.layoutParams
            params.width = ((layoutDuracao.width * porcentagem / 100f).toInt()).coerceAtLeast(0)
            viewBarraProgresso.layoutParams = params

            val fillColor = if (totalMin <= 30) 0xFF28A745.toInt() else 0xFFDC3545.toInt()
            val drawable = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setCornerRadius(4f * viewBarraProgresso.resources.displayMetrics.density)
                setColor(fillColor)
            }
            viewBarraProgresso.background = drawable
        }

        fun atualizarTempo(tempoConfirmacaoMs: Long) {
            hasTimer = true
            this.momentoReferencia = System.currentTimeMillis()
            this.tempoConfirmacaoMs = tempoConfirmacaoMs
            this.isFallback = false
            atualizarDisplayTempo()
        }

        fun atualizarTempoFallback(tempoCriacaoMs: Long, horariosLoja: List<HorarioLoja>?) {
            hasTimer = true
            this.momentoReferencia = System.currentTimeMillis()
            this.tempoCriacaoMs = tempoCriacaoMs
            this.horariosLoja = horariosLoja
            this.isFallback = true
            atualizarDisplayTempo()
        }

        fun removerAtualizacaoTempo() {
            hasTimer = false
            layoutDuracao.visibility = View.GONE
        }

        fun atualizarDisplayTempo() {
            if (!hasTimer) return

            if (isFallback) {
                val agora = System.currentTimeMillis()
                val calendar = Calendar.getInstance().apply { timeInMillis = agora }
                val diaSemana = calendar.get(Calendar.DAY_OF_WEEK)
                val inicioHoje = agora - (agora % 86400000L)

                val diaSemanaMap = mapOf(
                    Calendar.MONDAY to "segunda-feira",
                    Calendar.TUESDAY to "terça-feira",
                    Calendar.WEDNESDAY to "quarta-feira",
                    Calendar.THURSDAY to "quinta-feira",
                    Calendar.FRIDAY to "sexta-feira",
                    Calendar.SATURDAY to "sábado",
                    Calendar.SUNDAY to "domingo"
                )

                val horaAbre = if (diaSemana == Calendar.SUNDAY) 14 else 10
                val horaFecha = if (diaSemana == Calendar.SUNDAY) 19 else 22
                val aberturaHoje = inicioHoje + horaAbre * 3600000L
                val fechamentoHoje = inicioHoje + horaFecha * 3600000L
                val dentroHorario = agora >= aberturaHoje && agora < fechamentoHoje

                if (dentroHorario) {
                    val diff = calcularTempoComLoja(tempoCriacaoMs, horariosLoja)
                    val totalMin = (diff / 60000).toInt()
                    val texto = if (totalMin >= 60) "${totalMin / 60}h ${totalMin % 60}min" else "${totalMin}min"
                    tvTempoConfirmacao.text = "Duração: $texto"
                    layoutDuracao.visibility = View.VISIBLE
                    atualizarBarraProgresso(totalMin)
                } else {
                    layoutDuracao.visibility = View.GONE
                }
            } else {
                val decorrido = tempoConfirmacaoMs + (System.currentTimeMillis() - momentoReferencia)
                val totalMin = (kotlin.math.abs(decorrido) / 60000).toInt()
                val texto = if (totalMin >= 60) "${totalMin / 60}h ${totalMin % 60}min" else "${totalMin}min"
                tvTempoConfirmacao.text = "Duração: $texto"
                layoutDuracao.visibility = View.VISIBLE
                atualizarBarraProgresso(totalMin)
            }
        }
    }

    override fun onViewAttachedToWindow(holder: ViewHolder) {
        super.onViewAttachedToWindow(holder)
        attachedViewHolders.add(holder)
    }

    override fun onViewDetachedFromWindow(holder: ViewHolder) {
        super.onViewDetachedFromWindow(holder)
        attachedViewHolders.remove(holder)
    }

    fun tick() {
        attachedViewHolders.forEach { it.atualizarDisplayTempo() }
    }

    companion object {
        private val DATE_FORMAT = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale("pt", "BR"))
        private val INPUT_FORMAT = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }
    }
}

private fun calcularTempoComLoja(tempoCriacaoMs: Long, horariosLoja: List<io.maestro.network.models.HorarioLoja>?): Long {
    val agora = System.currentTimeMillis()
    if (tempoCriacaoMs >= agora) return 60000L

    val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    val inputFormat = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())
    val calendar = Calendar.getInstance()

    var total = 0L
    var currentDayStart = tempoCriacaoMs - (tempoCriacaoMs % 86400000L)

    while (currentDayStart < agora) {
        calendar.timeInMillis = currentDayStart
        val diaSemana = calendar.get(Calendar.DAY_OF_WEEK)
        val dataStr = dateFormat.format(Date(currentDayStart))
        val horarioDia = horariosLoja?.find { it.data?.startsWith(dataStr) == true }

        val aberturaMs: Long
        val fechamentoMs: Long
        if (horarioDia != null && horarioDia.abertura != null && horarioDia.fechamento != null) {
            aberturaMs = try {
                inputFormat.parse(horarioDia.abertura)?.time ?: (currentDayStart + 3600000L)
            } catch (_: Exception) { currentDayStart + 3600000L }
            fechamentoMs = try {
                inputFormat.parse(horarioDia.fechamento)?.time ?: (currentDayStart + 86400000L)
            } catch (_: Exception) { currentDayStart + 86400000L }
        } else {
            val horaAbre = if (diaSemana == Calendar.SUNDAY) 14 else 10
            val horaFecha = if (diaSemana == Calendar.SUNDAY) 19 else 22
            aberturaMs = currentDayStart + horaAbre * 3600000L
            fechamentoMs = currentDayStart + horaFecha * 3600000L
        }

        val diaEnd = currentDayStart + 86400000L
        val inicioContagem = maxOf(tempoCriacaoMs, aberturaMs)
        val fimContagem = minOf(agora, fechamentoMs, diaEnd)

        if (inicioContagem < fimContagem) {
            total += fimContagem - inicioContagem
        }
        currentDayStart = diaEnd
    }
    return total.coerceAtLeast(60000L)
}

private fun Int.dpToPx(context: android.content.Context): Int {
    return (this * context.resources.displayMetrics.density).toInt()
}
