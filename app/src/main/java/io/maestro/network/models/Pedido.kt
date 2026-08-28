package io.maestro.network.models

import com.google.gson.annotations.SerializedName
import java.io.Serializable

data class Pedido(
    @SerializedName("_id") val id: String = "",
    @SerializedName("numero") val numero: String = "",
    @SerializedName("codigoExterno") val codigoExterno: String = "",
    @SerializedName("loja") val loja: String = "",
    @SerializedName("status") val status: String = "",
    @SerializedName("origem") val origem: String? = null,
    @SerializedName("tipoEntrega") val tipoEntrega: String? = null,
    @SerializedName("dataInclusao") val dataInclusao: String = "",
    @SerializedName("dataAlteracao") val dataAlteracao: String? = null,
    @SerializedName("cliente") val cliente: Cliente? = null,
    @SerializedName("itens") val itens: List<Item>? = null,
    
    // ========== CAMPOS DE VALOR CORRIGIDOS ==========
    @SerializedName("valorTotal") val valorTotal: Double = 0.0,
    @SerializedName("valorSubtotal") val valorSubtotal: Double = 0.0,
    @SerializedName("valorDesconto") val valorDesconto: Double = 0.0,
    @SerializedName("valorEntrega") val valorEntrega: Double = 0.0,
    // ================================================
    
    @SerializedName("pagamentoStatus") val pagamentoStatus: String? = null,
    @SerializedName("pago") val pago: Boolean = false,
    @SerializedName("dhEntregaEstimada") val dhEntregaEstimada: String? = null,
    @SerializedName("deliveryToken") val deliveryToken: DeliveryToken? = null,
    @SerializedName("timelines") val timelines: List<Timeline>? = null,
    @SerializedName("events") val events: List<Event>? = null,
    @SerializedName("historico") val historico: List<Historico>? = null,
    @SerializedName("canalDeVendas") val canalDeVendas: String? = null,
    @SerializedName("searchtext") val searchtext: String? = null,
    @SerializedName("dataCriacao") val dataCriacao: String? = null,
    @SerializedName("dataVisualizacao") val dataVisualizacao: String? = null,
    @SerializedName("tempoConfirmacao") val tempoConfirmacao: Long? = null,
    @SerializedName("canalVendas") val canalVendas: String? = null,
    @SerializedName("erro") val erro: String? = null,
    @SerializedName("configuracaoErp") val configuracaoErp: ConfiguracaoErp? = null,
    @SerializedName("entregas") val entregas: List<Entrega>? = null,
    @SerializedName("recebedor") val recebedor: Recebedor? = null,
    @SerializedName("notaFiscal") val notaFiscal: NotaFiscal? = null,
    @SerializedName("notaFiscalDevolucao") val notaFiscalDevolucao: Any? = null,
    @SerializedName("statusForIntegration") val statusForIntegration: String? = null,
    @SerializedName("arl") val arl: Arl? = null,
    @SerializedName("motivo") val motivo: List<MotivoCancelamento>? = null,
    @SerializedName("dataFinalizacao") val dataFinalizacao: String? = null,
    @SerializedName("horariosLoja") val horariosLoja: List<HorarioLoja>? = null,
    @SerializedName("itemHash") val itemHash: String? = null,
    @SerializedName("confirmacaoEdicao") val confirmacaoEdicao: String? = null,
    @SerializedName("__v") val versao: Int? = null,
    @SerializedName("pagamentos") val pagamentos: List<Any>? = null,
    @SerializedName("pendencia") val pendencia: Any? = null,
    @SerializedName("cnpjOrigem") val cnpjOrigem: String? = null,
    @SerializedName("transportadora") val transportadora: String? = null,
    @SerializedName("erpOrigem") val erpOrigem: String? = null
) : Serializable

data class ConfiguracaoErp(
    @SerializedName("canalVendas") val canalVendas: String? = null,
    @SerializedName("usaTokenPrecode") val usaTokenPrecode: Boolean? = null,
    @SerializedName("notaFiscalNaConfirmacaoEstoque") val notaFiscalNaConfirmacaoEstoque: Boolean? = null,
    @SerializedName("canalVendasMarketplaceOut") val canalVendasMarketplaceOut: Boolean? = null,
    @SerializedName("imprimirNotaFiscal") val imprimirNotaFiscal: Boolean? = null,
    @SerializedName("imprimirEtiqueta") val imprimirEtiqueta: Boolean? = null
) : Serializable

data class Entrega(
    @SerializedName("codigo") val codigo: String? = null,
    @SerializedName("codigoOrigem") val codigoOrigem: String? = null
) : Serializable

data class Recebedor(
    @SerializedName("nome") val nome: String? = null,
    @SerializedName("documento") val documento: String? = null
) : Serializable

data class NotaFiscal(
    @SerializedName("chave") val chave: String? = null,
    @SerializedName("tipo") val tipo: String? = null,
    @SerializedName("numero") val numero: String? = null,
    @SerializedName("serie") val serie: String? = null,
    @SerializedName("cnpjEmissao") val cnpjEmissao: String? = null,
    @SerializedName("dataEmissao") val dataEmissao: String? = null,
    @SerializedName("cpfDestino") val cpfDestino: String? = null,
    @SerializedName("valorTotal") val valorTotal: Double? = null,
    @SerializedName("emitida") val emitida: Boolean? = null,
    @SerializedName("nfe") val nfe: String? = null
) : Serializable

data class Arl(
    @SerializedName("envio") val envio: Boolean? = null,
    @SerializedName("dataEnvio") val dataEnvio: String? = null
) : Serializable

data class HorarioLoja(
    @SerializedName("data") val data: String? = null,
    @SerializedName("abertura") val abertura: String? = null,
    @SerializedName("fechamento") val fechamento: String? = null
) : Serializable

data class Cliente(
    @SerializedName("nome") val nome: String? = null,
    @SerializedName("customerId") val customerId: String? = null,
    @SerializedName("cpf") val cpf: String? = null,
    @SerializedName("cnpj") val cnpj: String? = null,
    @SerializedName("email") val email: String? = null,
    @SerializedName("telefone") val telefone: String? = null,
    @SerializedName("endereco") val endereco: String? = null,
    @SerializedName("numero") val numero: String? = null,
    @SerializedName("complemento") val complemento: String? = null,
    @SerializedName("bairro") val bairro: String? = null,
    @SerializedName("cidade") val city: String? = null,
    @SerializedName("uf") val uf: String? = null,
    @SerializedName("cep") val cep: String? = null
) : Serializable

data class Item(
    @SerializedName("codigoEAN") val codigoEAN: String? = null,
    @SerializedName("eans") val eans: List<String>? = null,
    @SerializedName("codigoSAP") val codigoSAP: String? = null,
    @SerializedName("descricao") val descricao: String? = null,
    @SerializedName("quantidade") val quantidade: Int = 0,
    @SerializedName("quantidadeTotal") val quantidadeTotal: Int? = null,
    @SerializedName("valorUnitario") val valorUnitario: Double = 0.0,
    @SerializedName("valorTotal") val valorTotal: Double = 0.0,
    @SerializedName("estoque") val estoque: Int? = null,
    @SerializedName("estoqueInicial") val estoqueInicial: Int? = null,
    @SerializedName("precoVenda") val precoVenda: Double? = null,
    @SerializedName("peso") val peso: Double? = null,
    @SerializedName("quantidadeImeis") val quantidadeImeis: Int = 0,
    @SerializedName("imeis") val imeis: List<List<String>>? = null
) : Serializable

data class DeliveryToken(
    @SerializedName("tokenRetirada") val tokenRetirada: String? = null,
    @SerializedName("tokenInsucesso") val tokenInsucesso: String? = null,
    @SerializedName("tokenCliente") val tokenCliente: String? = null
) : Serializable

data class Timeline(
    @SerializedName("nome") val nome: String? = null,
    @SerializedName("data") val data: String? = null
) : Serializable

data class Event(
    @SerializedName("eventName") val eventName: String? = null,
    @SerializedName("tipo") val tipo: String? = null,
    @SerializedName("status") val status: String? = null,
    @SerializedName("dataCriacao") val dataCriacao: String? = null,
    @SerializedName("usuario") val usuario: String? = null,
    @SerializedName("mensagem") val mensagem: String? = null,
    @SerializedName("data") val data: EventData? = null
) : Serializable

data class EventData(
    @SerializedName("status") val status: String? = null,
    @SerializedName("historico") val historico: List<Historico>? = null,
    @SerializedName("timelines") val timelines: List<Timeline>? = null
) : Serializable

data class Historico(
    @SerializedName("usuario") val usuario: String? = null,
    @SerializedName("status") val status: String? = null,
    @SerializedName("data") val data: String? = null
) : Serializable

// ✅ MANTENHA APENAS ESTA DECLARAÇÃO (com ocorrencia)
data class MotivoCancelamento(
    @SerializedName("texto") val texto: String? = null,
    @SerializedName("tipo") val tipo: String? = null,
    @SerializedName("ocorrencia") val ocorrencia: String? = null,
    @SerializedName("_id") val id: String? = null
) : Serializable