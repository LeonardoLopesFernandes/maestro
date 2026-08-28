/// Dados de exemplo usados no Modo Demonstração (preview sem credenciais).
/// Retornam maps no mesmo formato que o backend Maestro entrega, para que
/// o ApiService/Pedido.fromJson processe normalmente.
class MockData {
  static Map<String, dynamic> count() => {
        'NOVO_PEDIDO': 3,
        'PREVISTO': 1,
        'EM_SEPARACAO': 4,
        'PRONTO_PARA_SAIR': 2,
        'SAIU_PARA_ENTREGA': 2,
        'RETORNAR_PARA_ESTOQUE': 1,
        'FINALIZADO': 18,
      };

  static List<Map<String, dynamic>> pedidos() {
    final statuses = [
      'NOVO_PEDIDO',
      'EM_SEPARACAO,EDITADO',
      'PRONTO_PARA_SAIR',
      'SAIU_PARA_ENTREGA',
      'RETORNAR_PARA_ESTOQUE',
      'FINALIZADO,CANCELADO,DEVOLVIDO',
    ];
    final List<Map<String, dynamic>> lista = [];
    for (int i = 0; i < 12; i++) {
      lista.add(_pedido(i, statuses[i % statuses.length]));
    }
    return lista;
  }

  static Map<String, dynamic> pedidoById(String id) {
    final idx = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return _pedido(idx, 'NOVO_PEDIDO');
  }

  static Map<String, dynamic> _pedido(int i, String status) {
    final numero = '${1000 + i}';
    return {
      '_id': 'ped_$i',
      'numero': numero,
      'codigoExterno': 'EXT-$numero',
      'loja': 'L291',
      'status': status,
      'tipoEntrega': i % 2 == 0 ? 'RETIRADA' : 'EXTERNA',
      'canalDeVendas': i % 3 == 0 ? 'Americanas' : 'Ifood',
      'dataInclusao': '2026-08-28T12:00:00.000Z',
      'valorSubtotal': 199.90 + i * 10,
      'valorDesconto': 10.0,
      'valorEntrega': i % 2 == 0 ? 0.0 : 15.90,
      'valorTotal': 209.90 + i * 10,
      'pagamentoStatus': 'PAGO',
      'pago': true,
      'notaFiscal': i == 1
          ? {'chave': '35260812345678901234567890123456789012345678'}
          : null,
      'cliente': {
        'nome': 'Cliente Exemplo $i',
        'cpf': '12345678901',
        'email': 'cliente$i@exemplo.com',
        'telefone': '(21) 99876-543$i',
        'endereco': 'Rua das Flores',
        'numero': '$i',
        'bairro': 'Centro',
        'city': 'Rio de Janeiro',
        'uf': 'RJ',
        'cep': '20040002',
      },
      'itens': [
        {
          'codigoEAN': '78900000000$i',
          'codigoSAP': 'SAP$i',
          'descricao': 'Smartphone Galaxy A$i 128GB',
          'quantidade': 1,
          'quantidadeTotal': 1,
          'valorUnitario': 199.90 + i * 10,
          'valorTotal': 199.90 + i * 10,
          'estoque': 5,
          'quantidadeImeis': i == 0 ? 1 : 0,
          'imeis': i == 0 ? [['990000111$i']] : [],
        },
        {
          'codigoEAN': '78911111111$i',
          'codigoSAP': 'SAP2$i',
          'descricao': 'Capa Protetora',
          'quantidade': 2,
          'quantidadeTotal': 2,
          'valorUnitario': 29.90,
          'valorTotal': 59.80,
          'estoque': 20,
          'quantidadeImeis': 0,
          'imeis': [],
        },
      ],
      'deliveryToken': i % 2 == 0
          ? {
              'tokenRetirada': 'tok_ret_$i',
              'tokenInsucesso': 'tok_ins_$i',
              'tokenCliente': 'tok_cli_$i',
            }
          : null,
      'timelines': [
        {'nome': 'NOVO_PEDIDO', 'data': '2026-08-28T10:00:00.000Z'},
        {'nome': 'EM_SEPARACAO', 'data': '2026-08-28T11:30:00.000Z'},
      ],
      'historico': [
        {'usuario': 'sistema', 'status': status, 'data': '2026-08-28T11:30:00.000Z'}
      ],
      'motivo': status.contains('CANCELADO')
          ? [
              {'texto': 'Cancelado por falta de estoque'}
            ]
          : [],
    };
  }

  static Map<String, dynamic> priceTagSummary() => {
        'total': 7,
        'pendentes': 3,
        'impressas': 4,
      };

  static Map<String, dynamic> priceTags() => {
        'data': [
          {
            '_id': 'tag1',
            'titulo': 'Smartphone Galaxy A54',
            'descricao': '128GB Preto',
            'preco': 199.90,
          },
          {
            '_id': 'tag2',
            'titulo': 'Capa Protetora',
            'descricao': 'Transparente',
            'preco': 29.90,
          },
        ]
      };
}
