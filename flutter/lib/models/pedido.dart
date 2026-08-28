class Pedido {
  final String id;
  final String numero;
  final String codigoExterno;
  final String loja;
  final String status;
  final String? origem;
  final String? tipoEntrega;
  final String dataInclusao;
  final String? dataAlteracao;
  final Cliente? cliente;
  final Recebedor? recebedor;
  final List<Item> itens;
  final double valorTotal;
  final double valorSubtotal;
  final double valorDesconto;
  final double valorEntrega;
  final String? pagamentoStatus;
  final bool pago;
  final String? dhEntregaEstimada;
  final DeliveryToken? deliveryToken;
  final List<Timeline> timelines;
  final List<Historico> historico;
  final String? canalDeVendas;
  final String? searchtext;
  final String? notaFiscalChave;
  final String? transportadora;
  final int? tempoConfirmacao;
  final List<MotivoCancelamento>? motivo;

  Pedido({
    this.id = "",
    this.numero = "",
    this.codigoExterno = "",
    this.loja = "",
    this.status = "",
    this.origem,
    this.tipoEntrega,
    this.dataInclusao = "",
    this.dataAlteracao,
    this.cliente,
    this.recebedor,
    this.itens = const [],
    this.valorTotal = 0.0,
    this.valorSubtotal = 0.0,
    this.valorDesconto = 0.0,
    this.valorEntrega = 0.0,
    this.pagamentoStatus,
    this.pago = false,
    this.dhEntregaEstimada,
    this.deliveryToken,
    this.timelines = const [],
    this.historico = const [],
      this.canalDeVendas,
      this.searchtext,
      this.notaFiscalChave,
      this.transportadora,
      this.tempoConfirmacao,
      this.motivo,
    });

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      id: json['_id'] ?? "",
      numero: json['numero'] ?? "",
      codigoExterno: json['codigoExterno'] ?? "",
      loja: json['loja'] ?? "",
      status: json['status'] ?? "",
      origem: json['origem'],
      tipoEntrega: json['tipoEntrega'],
      dataInclusao: json['dataInclusao'] ?? "",
      dataAlteracao: json['dataAlteracao'],
      cliente: json['cliente'] != null ? Cliente.fromJson(json['cliente']) : null,
      recebedor: json['recebedor'] != null
          ? Recebedor.fromJson(json['recebedor'])
          : null,
      itens: (json['itens'] as List?)
              ?.map((e) => Item.fromJson(e))
              .toList() ??
          [],
      valorTotal: _toDouble(json['valorTotal']),
      valorSubtotal: _toDouble(json['valorSubtotal']),
      valorDesconto: _toDouble(json['valorDesconto']),
      valorEntrega: _toDouble(json['valorEntrega']),
      pagamentoStatus: json['pagamentoStatus'],
      pago: json['pago'] ?? false,
      dhEntregaEstimada: json['dhEntregaEstimada'],
      deliveryToken: json['deliveryToken'] != null
          ? DeliveryToken.fromJson(json['deliveryToken'])
          : null,
      timelines: (json['timelines'] as List?)
              ?.map((e) => Timeline.fromJson(e))
              .toList() ??
          [],
      historico: (json['historico'] as List?)
              ?.map((e) => Historico.fromJson(e))
              .toList() ??
          [],
      canalDeVendas: json['canalDeVendas'] ?? json['canalVendas'],
      searchtext: json['searchtext'],
      notaFiscalChave: json['notaFiscal']?['chave'],
      transportadora: json['transportadora'],
      tempoConfirmacao: _toInt(json['tempoConfirmacao']),
      motivo: (json['motivo'] as List?)
              ?.map((e) => MotivoCancelamento.fromJson(e))
              .toList(),
    );
  }

  String get titulo {
    if (numero.isNotEmpty) return numero;
    if (codigoExterno.isNotEmpty) return codigoExterno;
    return id;
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

class Cliente {
  final String? nome;
  final String? cpf;
  final String? cnpj;
  final String? email;
  final String? telefone;
  final String? endereco;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? cidade;
  final String? uf;
  final String? cep;

  Cliente({
    this.nome,
    this.cpf,
    this.cnpj,
    this.email,
    this.telefone,
    this.endereco,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.uf,
    this.cep,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        nome: json['nome'],
        cpf: json['cpf'],
        cnpj: json['cnpj'],
        email: json['email'],
        telefone: json['telefone'],
        endereco: json['endereco'],
        numero: json['numero'],
        complemento: json['complemento'],
        bairro: json['bairro'],
        cidade: json['city'] ?? json['cidade'],
        uf: json['uf'],
        cep: json['cep'],
      );
}

class Recebedor {
  final String? nome;
  final String? documento;

  Recebedor({this.nome, this.documento});

  factory Recebedor.fromJson(Map<String, dynamic> json) => Recebedor(
        nome: json['nome'],
        documento: json['documento'],
      );
}

class MotivoCancelamento {
  final String? texto;

  MotivoCancelamento({this.texto});

  factory MotivoCancelamento.fromJson(Map<String, dynamic> json) =>
      MotivoCancelamento(texto: json['texto']);
}

class Item {
  final String? codigoEAN;
  final List<String> eans;
  final String? codigoSAP;
  final String? descricao;
  final int quantidade;
  final double valorUnitario;
  final double valorTotal;
  final int? estoque;
  final double? precoVenda;
  final int quantidadeImeis;
  final List<List<String>> imeis;

  Item({
    this.codigoEAN,
    this.eans = const [],
    this.codigoSAP,
    this.descricao,
    this.quantidade = 0,
    this.valorUnitario = 0.0,
    this.valorTotal = 0.0,
    this.estoque,
    this.precoVenda,
    this.quantidadeImeis = 0,
    this.imeis = const [],
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        codigoEAN: json['codigoEAN'],
        eans:
            (json['eans'] as List?)?.map((e) => e.toString()).toList() ?? [],
        codigoSAP: json['codigoSAP'],
        descricao: json['descricao'],
        quantidade: json['quantidade'] ?? 0,
        valorUnitario: _toDouble(json['valorUnitario']),
        valorTotal: _toDouble(json['valorTotal']),
        estoque: json['estoque'],
        precoVenda: _toDouble(json['precoVenda']),
        quantidadeImeis: json['quantidadeImeis'] ?? 0,
        imeis: (json['imeis'] as List?)
                ?.map((l) =>
                    (l as List).map((e) => e.toString()).toList())
                .toList() ??
            [],
      );
}

class DeliveryToken {
  final String? tokenRetirada;
  final String? tokenInsucesso;
  final String? tokenCliente;

  DeliveryToken({this.tokenRetirada, this.tokenInsucesso, this.tokenCliente});

  factory DeliveryToken.fromJson(Map<String, dynamic> json) => DeliveryToken(
        tokenRetirada: json['tokenRetirada'],
        tokenInsucesso: json['tokenInsucesso'],
        tokenCliente: json['tokenCliente'],
      );
}

class Timeline {
  final String? nome;
  final String? data;

  Timeline({this.nome, this.data});

  factory Timeline.fromJson(Map<String, dynamic> json) =>
      Timeline(nome: json['nome'], data: json['data']);
}

class Historico {
  final String? usuario;
  final String? status;
  final String? data;

  Historico({this.usuario, this.status, this.data});

  factory Historico.fromJson(Map<String, dynamic> json) => Historico(
        usuario: json['usuario'],
        status: json['status'],
        data: json['data'],
      );
}

class CountResponse {
  final int novoPedido;
  final int previsto;
  final int emSeparacao;
  final int prontoParaSair;
  final int saiuParaEntrega;
  final int retornarEstoque;
  final int finalizado;

  CountResponse({
    this.novoPedido = 0,
    this.previsto = 0,
    this.emSeparacao = 0,
    this.prontoParaSair = 0,
    this.saiuParaEntrega = 0,
    this.retornarEstoque = 0,
    this.finalizado = 0,
  });

  factory CountResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, int> map = {};
    final data = json['data'];
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          final key = item['_id'] ?? item['status'];
          if (key is String && key.isNotEmpty) {
            map[key] = _toInt(item['count']);
          }
        }
      }
    }
    return CountResponse(
      novoPedido: map['NOVO_PEDIDO'] ?? 0,
      previsto: map['PREVISTO'] ?? 0,
      emSeparacao: map['EM_SEPARACAO'] ?? 0,
      prontoParaSair: map['PRONTO_PARA_SAIR'] ?? 0,
      saiuParaEntrega: map['SAIU_PARA_ENTREGA'] ?? 0,
      retornarEstoque: map['RETORNAR_PARA_ESTOQUE'] ?? 0,
      finalizado: map['FINALIZADO'] ?? 0,
    );
  }
}

class PedidoResponse {
  final List<Pedido> pedidos;
  final int total;
  final bool completo;

  PedidoResponse({this.pedidos = const [], this.total = 0, this.completo = false});

  factory PedidoResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<dynamic> records;
    int total;
    int? limit;
    if (data is Map) {
      records = (data['records'] is List) ? data['records'] : [];
      total = _toInt(data['total'] ?? data['count']);
      limit = _toInt(data['limit']);
    } else if (data is List) {
      records = data;
      total = data.length;
    } else {
      records = [];
      total = 0;
    }
    return PedidoResponse(
      pedidos: records.map((e) => Pedido.fromJson(e)).toList(),
      total: total,
      completo: limit != null && records.length < limit,
    );
  }
}
