package io.maestro.adapters

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import io.maestro.R
import io.maestro.network.models.Timeline
import io.maestro.utils.Colors
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.abs

class TimelineAdapter(
    private var items: List<Timeline>
) : RecyclerView.Adapter<TimelineAdapter.ViewHolder>() {

    private val dateFormat = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault())

    inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val tvNome: TextView = itemView.findViewById(R.id.tvTimelineNome)
        val tvData: TextView = itemView.findViewById(R.id.tvTimelineData)
        val tvDuracao: TextView = itemView.findViewById(R.id.tvTimelineDuracao)

        fun bind(timeline: Timeline, durationText: String?, isAtrasado: Boolean) {
            tvNome.text = timeline.nome ?: "Evento"
            tvData.text = formatDate(timeline.data ?: "")
            if (durationText != null) {
                tvDuracao.text = durationText
                tvDuracao.visibility = View.VISIBLE
                tvDuracao.setTextColor(
                    if (isAtrasado) android.graphics.Color.parseColor(Colors.RED_600)
                    else android.graphics.Color.parseColor(Colors.BLUE_600)
                )
            } else {
                tvDuracao.visibility = View.GONE
            }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_timeline, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val durationText: String?
        val isAtrasado: Boolean
        if (position > 0) {
            val prevDate = parseDate(items[position - 1].data)
            val currDate = parseDate(items[position].data)
            if (prevDate != null && currDate != null) {
                val diffMs = abs(currDate.time - prevDate.time)
                durationText = formatarDuracao(diffMs)
                isAtrasado = diffMs > 30 * 60 * 1000L
            } else {
                durationText = null
                isAtrasado = false
            }
        } else {
            durationText = null
            isAtrasado = false
        }
        holder.bind(items[position], durationText, isAtrasado)
    }

    override fun getItemCount(): Int = items.size

    fun updateItems(newItems: List<Timeline>) {
        items = newItems
        notifyDataSetChanged()
    }

    private fun formatDate(dateString: String): String {
        return try {
            if (dateString.isEmpty()) return ""
            val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).apply {
                timeZone = java.util.TimeZone.getTimeZone("UTC")
            }
            val date = inputFormat.parse(dateString)
            date?.let { dateFormat.format(it) } ?: dateString
        } catch (e: Exception) {
            dateString
        }
    }

    private fun parseDate(dateString: String?): Date? {
        if (dateString.isNullOrEmpty()) return null
        return try {
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault()).apply {
                timeZone = java.util.TimeZone.getTimeZone("UTC")
            }.parse(dateString)
        } catch (e: Exception) {
            null
        }
    }

    private fun formatarDuracao(diffMs: Long): String {
        val totalMin = kotlin.math.abs(diffMs).coerceAtLeast(60000L) / 60000
        val dias = totalMin / (24 * 60)
        val horas = (totalMin % (24 * 60)) / 60
        val minutos = totalMin % 60
        return buildString {
            if (dias > 0) append("${dias}d ")
            if (horas > 0 || dias > 0) append("${horas}h ")
            append("${minutos}min")
        }
    }
}