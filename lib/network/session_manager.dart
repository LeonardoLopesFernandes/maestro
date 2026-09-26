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
  static const String _keyProfilePhoto = "PROFILE_PHOTO";
  static const String _keyDeliveryTokenPrefix = "DELIVERY_TOKEN_";
  static const int _tokenExpiryDays = 14;

  final SharedPreferences _prefs;

  SessionManager(this._prefs);

  static Future<SessionManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SessionManager(prefs);
  }

  Future<void> saveToken(String token, {int? expiryEpochSeconds}) async {
    await _prefs.setString(_keyBearerToken, token);
    final expiry = (expiryEpochSeconds != null
            ? expiryEpochSeconds * 1000
            : DateTime.now()
                .add(const Duration(days: _tokenExpiryDays))
                .millisecondsSinceEpoch)
        .clamp(DateTime.now().millisecondsSinceEpoch,
            DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch);
    await _prefs.setInt(_keyTokenExpiry, expiry);
    await _prefs.setBool(_keyRememberLogin, true);
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

  void saveProfilePhoto(String path) => _prefs.setString(_keyProfilePhoto, path);

  String? getProfilePhoto() => _prefs.getString(_keyProfilePhoto);

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
  void saveDeliveryToken(String numero, String token) {
    _prefs.setString("$_keyDeliveryTokenPrefix$numero", token);
  }

  String? getDeliveryToken(String numero) =>
      _prefs.getString("$_keyDeliveryTokenPrefix$numero");

  // ---------- Flag de pedido editado ----------
  // Salva com TODOS os IDs possíveis (id, numero, codigoExterno) para
  // garantir match entre list API e detail API.
  static const String _keyEditFlagPrefix = "PEDIDO_EDITADO_";
  static const String _keyItensPrefix = "PEDIDO_ITENS_";
  static const String _keyEditedIds = "EDITED_IDS_SET";

  List<String> _idsForPedido(String id, String numero, String codigoExterno) {
    final ids = <String>{};
    if (id.isNotEmpty) ids.add(id);
    if (numero.isNotEmpty) ids.add(numero);
    if (codigoExterno.isNotEmpty) ids.add(codigoExterno);
    return ids.toList();
  }

  void _addToEditedSet(List<String> allIds) {
    final existing = getEditedIds();
    var changed = false;
    for (final id in allIds) {
      if (id.isNotEmpty && !existing.contains(id)) {
        existing.add(id);
        changed = true;
      }
    }
    if (changed) {
      _prefs.setString(_keyEditedIds, existing.join(','));
    }
  }

  Set<String> getEditedIds() {
    final raw = _prefs.getString(_keyEditedIds) ?? '';
    if (raw.isEmpty) return {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  void saveEditFlag(String id, {String numero = '', String codigoExterno = ''}) {
    final allIds = _idsForPedido(id, numero, codigoExterno);
    if (allIds.isEmpty) return;
    _addToEditedSet(allIds);
    for (final key in allIds) {
      _prefs.setBool("$_keyEditFlagPrefix${key.trim()}", true);
    }
  }

  void savePedidoItens(String id, String itensJson,
      {String numero = '', String codigoExterno = ''}) {
    final allIds = _idsForPedido(id, numero, codigoExterno);
    if (allIds.isEmpty) return;
    _addToEditedSet(allIds);
    for (final key in allIds) {
      _prefs.setString("$_keyItensPrefix${key.trim()}", itensJson);
    }
  }

  String? getPedidoItens(String id) {
    if (id.isEmpty) return null;
    return _prefs.getString("$_keyItensPrefix${id.trim()}");
  }

  bool isPedidoEditado(String id) {
    if (id.isEmpty) return false;
    if (getEditedIds().contains(id)) return true;
    return _prefs.getBool("$_keyEditFlagPrefix${id.trim()}") ?? false;
  }

  /// Verifica se o pedido foi editado — checa por qualquer um dos IDs
  /// (id, numero, codigoExterno) no Set, nas flags individuais, ou nos itens.
  bool pedidoFoiEditado(String id, {String numero = '', String codigoExterno = ''}) {
    final allIds = _idsForPedido(id, numero, codigoExterno);
    final editedIds = getEditedIds();
    for (final key in allIds) {
      if (editedIds.contains(key)) return true;
      if (key.isNotEmpty && (_prefs.getBool("$_keyEditFlagPrefix${key.trim()}") ?? false)) return true;
      if (key.isNotEmpty && _prefs.getString("$_keyItensPrefix${key.trim()}") != null) return true;
    }
    return false;
  }

  // ---------- Última contagem de pedidos (polling em background) ----------
  static const String _keyLastPolling = "LAST_POLLING_COUNT";

  int getLastPollingCount() => _prefs.getInt(_keyLastPolling) ?? -1;

  void saveLastPollingCount(int v) => _prefs.setInt(_keyLastPolling, v);
}
