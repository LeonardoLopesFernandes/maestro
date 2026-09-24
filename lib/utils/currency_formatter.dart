import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatador = NumberFormat("#,##0.00", "pt_BR");
  static final NumberFormat _formatadorSemDecimal =
      NumberFormat("#,##0", "pt_BR");

  /// Ex: 110602.47 -> "110.602,47"
  static String formatarMoeda(double valor) => _formatador.format(valor);

  /// Ex: 110602.47 -> "R$ 110.602,47"
  static String formatarMoedaComSimbolo(double valor) =>
      "R\$ ${_formatador.format(valor)}";

  /// Ex: 110602.47 -> "110.602"
  static String formatarNumero(double valor) =>
      _formatadorSemDecimal.format(valor);

  /// Ex: 14.99 -> "14,99%"
  static String formatarPorcentagem(double valor) =>
      "${_formatador.format(valor)}%";

  /// Ex: 14.9 -> "14,90"
  static String formatarDecimal(double valor) => _formatador.format(valor);

  /// Ex: 198 -> "198", 1000 -> "1.000"
  static String formatarInteiro(int valor) =>
      _formatadorSemDecimal.format(valor);

  /// Ex: 1000000 -> "1.000.000"
  static String formatarLong(int valor) =>
      _formatadorSemDecimal.format(valor);

  /// Alias conveniente: R$ 110.602,47
  static String format(double valor) => formatarMoedaComSimbolo(valor);
}
