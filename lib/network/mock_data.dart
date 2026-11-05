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

  static Map<String, dynamic> dashboard() => {
        'status': 200,
        'data': [
          {'_id': 'FINALIZADO', 'count': 827},
          {'_id': 'PRONTO_PARA_SAIR', 'count': 2},
          {'_id': 'DEVOLVIDO', 'count': 97},
          {'_id': 'CANCELADO', 'count': 79},
        ],
        'dashboard': {
          'header': {
            'date': 'Quarta-feira, 4 de novembro',
            'updatedAt': '22:20',
            'searchPlaceholder': 'Busque por pedido',
          },
          'summaryCards': [
            {
              'id': 'onTime',
              'value': '95,1%',
              'description': 'dos pedidos confirmados no prazo.',
              'goal': 'META 90%',
              'status': 'success',
              'color': '#65AF84',
            },
            {
              'id': 'confirmationTime',
              'value': '0h 38min e 37seg',
              'description': 'é o tempo médio de confirmação dos pedidos.',
              'goal': 'META 1 HORA',
              'status': 'success',
              'color': '#65AF84',
            },
            {
              'id': 'refusalRate',
              'value': '0,60%',
              'description': 'é a taxa de recusa por item.',
              'goal': 'META 3,5%',
              'status': 'success',
              'color': '#65AF84',
            },
          ],
          'ordersInProgress': {
            'title': 'Pedidos em andamento',
            'total': 2,
            'items': [
              {
                'label': 'Novos pedidos',
                'value': 0,
                'color': 'green',
                'percentage': '0,00%',
              },
              {
                'label': 'Em separação',
                'value': 0,
                'color': 'cyan',
                'percentage': '0,00%',
              },
              {
                'label': 'Pronto para retirada',
                'value': 2,
                'color': 'yellow',
                'percentage': '100,00%',
              },
              {
                'label': 'Saiu para entrega',
                'value': 0,
                'color': 'magenta',
                'percentage': '0,00%',
              },
              {
                'label': 'Retornar para estoque',
                'value': 0,
                'color': 'red',
                'percentage': '0,00%',
              },
            ],
          },
          'statusCards': [
            {
              'title': 'Em separação',
              'value': '0,00%',
              'status': 'info',
              'code': 'EM_SEPARACAO',
            },
            {
              'title': 'Retornar p/ estoque',
              'value': '0,00%',
              'status': 'error',
              'code': 'RETORNAR_PARA_ESTOQUE',
            },
          ],
          'tables': {
            'expiring': _tabelaDashboard(
              '0 pedidos perto do vencimento. Confirme antes do prazo final.',
              'blue',
              'Pedidos que estão próximos de vencer precisam ser confirmados a tempo.',
              'Todos os pedidos estão dentro do vencimento',
              'Nenhum pedido aguardando confirmação.',
              ['N° Pedido', 'Vence em', 'Cliente', 'Entrega'],
            ),
            'overdue': _tabelaDashboard(
              '0 pedidos fora do prazo de confirmação.',
              'red',
              'Pedidos que passaram do prazo de confirmação precisam de atenção.',
              'Todas as confirmações estão dentro do prazo',
              'Nenhum pedido aguardando confirmação.',
              ['N° Pedido', 'Aguardando', 'Cliente', 'Entrega'],
            ),
            'withdrawal': _tabelaDashboard(
              '0 pedidos sem retirada aguardando análise.',
              'yellow',
              'Pedidos a mais de 3 dias sem retirada, aguardando confirmação de coleta ou cancelamento.',
              'Todas as retiradas estão dentro do prazo',
              'Nenhum pedido aguardando coleta ou cancelamento por ausência de retirada.',
              [
                'N° Pedido',
                'Aguardando',
                'Cliente',
                'Canal de venda',
                'Entrega',
              ],
            ),
          },
        },
      };

  static Map<String, dynamic> _tabelaDashboard(
    String title,
    String variant,
    String infoText,
    String emptyTitle,
    String emptyDescription,
    List<String> columns,
  ) =>
      {
        'title': title,
        'variant': variant,
        'infoText': infoText,
        'emptyTitle': emptyTitle,
        'emptyDescription': emptyDescription,
        'columns': columns,
        'rows': [],
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
