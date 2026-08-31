import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _prefsName = "MaestroPrefs";
  static const String _keyBearerToken = "BEARER_TOKEN";
  static const String _keyTokenExpiry = "TOKEN_EXPIRY";
  static const String _keyUserEmail = "USER_EMAIL";
  static const String _keyUserName = "USER_NAME";
  static const String _keyUserStore = "USER_STORE";
  static const String _keyRememberLogin = "REMEMBER_LOGIN";
  static const String _keyMsPassword = "MS_PASSWORD";
  static const String _keyDemo = "DEMO_MODE";
  static const String _keyDeliveryTokenPrefix = "DELIVERY_TOKEN_";
  static const int _tokenExpiryDays = 14;

  final SharedPreferences _prefs;

  SessionManager(this._prefs);

  static Future<SessionManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SessionManager(prefs);
  }

  void saveToken(String token, {int? expiryEpochSeconds}) {
    _prefs.setString(_keyBearerToken, token);
    final expiry = (expiryEpochSeconds != null
            ? expiryEpochSeconds * 1000
            : DateTime.now()
                .add(const Duration(days: _tokenExpiryDays))
                .millisecondsSinceEpoch)
        .clamp(DateTime.now().millisecondsSinceEpoch,
            DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch);
    _prefs.setInt(_keyTokenExpiry, expiry);
    _prefs.setBool(_keyRememberLogin, true);
  }

  String? getToken() {
    final token = _prefs.getString(_keyBearerToken);
    if (token == null || token.isEmpty) return null;
    if (isTokenExpired()) {
      clearToken();
      return null;
    }
    return token;
  }

  bool isLoggedIn() {
    final remember = _prefs.getBool(_keyRememberLogin) ?? false;
    final token = getToken();
    return remember && token != null && token.isNotEmpty;
  }

  bool isTokenExpired() {
    final expiry = _prefs.getInt(_keyTokenExpiry) ?? 0;
    if (expiry == 0) return false;
    return DateTime.now().millisecondsSinceEpoch > expiry;
  }

  void clearToken() {
    _prefs.remove(_keyBearerToken);
    _prefs.remove(_keyTokenExpiry);
    _prefs.setBool(_keyRememberLogin, false);
  }

  void saveUserInfo(String email, String name, String store) {
    _prefs.setString(_keyUserEmail, email);
    _prefs.setString(_keyUserName, name);
    _prefs.setString(_keyUserStore, store);
  }

  String? getUserEmail() => _prefs.getString(_keyUserEmail);
  String? getUserName() => _prefs.getString(_keyUserName);
  String? getUserStore() => _prefs.getString(_keyUserStore) ?? "L291";

  void saveCredentials(String email, String password) {
    _prefs.setString(_keyUserEmail, email);
    _prefs.setString(_keyMsPassword, password);
  }

  String? getSavedPassword() => _prefs.getString(_keyMsPassword);

  bool hasSavedCredentials() {
    final email = getUserEmail();
    final senha = getSavedPassword();
    return email != null &&
        email.isNotEmpty &&
        senha != null &&
        senha.isNotEmpty;
  }

  void clearCredentials() => _prefs.remove(_keyMsPassword);

  void clearAll() => _prefs.clear();

  // ---------- Modo Demonstração (preview sem credenciais) ----------
  void enableDemo() {
    _prefs.setBool(_keyDemo, true);
    saveToken("demo-token");
  }

  void disableDemo() => _prefs.setBool(_keyDemo, false);

  bool isDemo() => _prefs.getBool(_keyDemo) ?? false;

  // ---------- Token de retirada (entregador) persistido por pedido ----------
  // Espelha o saveDeliveryToken/getDeliveryToken do Kotlin: o token digitado/
  // validado na retirada é salvo para ser exibido depois (ex.: histórico ENTREGUE).
  void saveDeliveryToken(String numero, String token) {
    _prefs.setString("$_keyDeliveryTokenPrefix$numero", token);
  }

  String? getDeliveryToken(String numero) =>
      _prefs.getString("$_keyDeliveryTokenPrefix$numero");

  // ---------- Flag de pedido editado ----------
  // Espelha saveEditFlag/isPedidoEditado do Kotlin: quando o operador edita
  // quantidades de itens na separação, a flag é salva para exibir o lápis
  // azul no card do pedido na aba PRONTO PARA RETIRADA.
  static const String _keyEditFlagPrefix = "PEDIDO_EDITADO_";
  static const String _keyItensPrefix = "PEDIDO_ITENS_";

  void saveEditFlag(String numero) {
    _prefs.setBool("$_keyEditFlagPrefix${numero.trim()}", true);
  }

  bool isPedidoEditado(String numero) {
    return _prefs.getBool("$_keyEditFlagPrefix${numero.trim()}") ?? false;
  }

  void savePedidoItens(String numero, String itensJson) {
    _prefs.setString("$_keyItensPrefix${numero.trim()}", itensJson);
  }

  String? getPedidoItens(String numero) {
    return _prefs.getString("$_keyItensPrefix${numero.trim()}");
  }

  /// Verifica se o pedido foi editado (flag OU itens salvos)
  bool pedidoFoiEditado(String numero) {
    if (isPedidoEditado(numero)) return true;
    if (getPedidoItens(numero) != null) return true;
    return false;
  }

  // ---------- Última contagem de pedidos (polling em background) ----------
  static const String _keyLastPolling = "LAST_POLLING_COUNT";

  int getLastPollingCount() => _prefs.getInt(_keyLastPolling) ?? 0;

  void saveLastPollingCount(int v) => _prefs.setInt(_keyLastPolling, v);
}
