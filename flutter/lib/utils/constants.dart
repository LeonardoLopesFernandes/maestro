class Constants {
  static const String defaultStore = "L291";

  // URLs
  static const String baseUrl = "https://maestro-backend.americanas.io/";
  static const String webBaseUrl = "https://maestro.americanas.io/";
  static const String loginUrl = "https://maestro.americanas.io/unauthorized";

  // Microsoft OAuth — fluxo SAML2 via sl-authorization (mesmo padrão da minhaloja).
  static const String tenant = "e316d1ac-42c8-4d30-817c-12c7a71f8ab2";
  static const String clientId = "16021f31-43f8-4f7a-8af4-5e47efe7db8a";
  static const String redirectUri =
      "https://apimobile.brasilrisk.com.br/Validar/SamlResponseConsumer";
  static const String msLoginUrl =
      "https://sl-authorization.americanas.io/maestro";

  static const String recaptchaSiteKey =
      "6LcGCN4aAAAAACBn8w45pz5foZB7yf7RO_bZUJl6";

  // Cabeçalhos padrão
  static const String maestroVersion = "v2";

  // Som de novo pedido (mesmo do web app)
  static const String orderAlertSoundUrl =
      "https://maestro.americanas.io/static/media/order_alert.91ea9a1ce8aba530269b.wav";

  // Status dos pedidos (aba -> status)
  static const String statusNovoPedido = "NOVO_PEDIDO";
  static const String statusPrevisto = "PREVISTO";
  static const String statusEmSeparacao = "EM_SEPARACAO,EDITADO";
  static const String statusProntoParaSair = "PRONTO_PARA_SAIR";
  static const String statusSaiuParaEntrega = "SAIU_PARA_ENTREGA";
  static const String statusRetornarEstoque = "RETORNAR_PARA_ESTOQUE";
  static const String statusFinalizado = "FINALIZADO,CANCELADO,DEVOLVIDO";

  // Cores (iguais ao Colors.kt)
  static const int RED_600 = 0xFFDC2626;
  static const int RED_500 = 0xFFE31837;
  static const int RED_100 = 0xFFFEE2E2;
  static const int RED_50 = 0xFFFEF2F2;
  static const int GREEN_500 = 0xFF12CD0C;
  static const int GREEN_100 = 0xFFDCFCE7;
  static const int BLUE_500 = 0xFF00CBFE;
  static const int BLUE_100 = 0xFFE0F7FE;
  static const int ORANGE_500 = 0xFFFFAA02;
  static const int ORANGE_100 = 0xFFFFF1D6;
  static const int GRAY_400 = 0xFF9E9E9E;
  static const int GRAY_300 = 0xFFD1D5DB;
  static const int GRAY_200 = 0xFFE5E7EB;
  static const int GRAY_100 = 0xFFF3F4F6;
  static const int DARK_TEXT = 0xFF0F172A;
  static const int MEDIUM_TEXT = 0xFF374151;
  static const int WHITE = 0xFFFFFFFF;
}
