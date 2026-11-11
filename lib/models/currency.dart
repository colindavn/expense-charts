/// A currency the user can type amounts in.
/// [rate] is how many units of this currency make 1 unit of the preferred currency.
class Currency {
  final String code;
  final String symbol;
  final double rate;

  const Currency({required this.code, required this.symbol, required this.rate});

  factory Currency.fromMap(Map<String, dynamic> map) => Currency(
        code: map['code'] as String,
        symbol: map['symbol'] as String,
        rate: (map['rate'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {'code': code, 'symbol': symbol, 'rate': rate};

  Currency copyWith({String? symbol, double? rate}) =>
      Currency(code: code, symbol: symbol ?? this.symbol, rate: rate ?? this.rate);

  static const defaults = [
    Currency(code: 'EUR', symbol: '€', rate: 1),
    Currency(code: 'JPY', symbol: '¥', rate: 164),
  ];
}
