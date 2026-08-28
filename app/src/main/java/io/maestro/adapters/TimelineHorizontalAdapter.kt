package io.maestro.adapters

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import io.maestro.R
import io.maestro.network.models.Timeline
import java.text.SimpleDateFormat
import java.util.*

class TimelineHorizontalAdapter(
    private var items: List<Timeline>
) : RecyclerView.Adapter<TimelineHorizontalAdapter.ViewHolder>() {

    private val dateFormat = SimpleDateFormat("dd/MM HH:mm", Locale("pt", "BR"))

    inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val tvNome: TextView = itemView.findViewById(R.id.tvTimelineNome)
        val tvData: TextView = itemView.findViewById(R.id.tvTimelineData)
        
        fun bind(timeline: Timeline) {
            tvNome.text = timeline.nome ?: "Evento"
            tvData.text = formatDate(timeline.data ?: "")
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_timeline_horizontal, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(items[position])
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
}