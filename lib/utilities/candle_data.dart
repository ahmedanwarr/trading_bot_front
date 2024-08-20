class CandleData {
  final int time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  CandleData(
      {required this.time,
      required this.open,
      required this.high,
      required this.low,
      required this.close,
      required this.volume});

  factory CandleData.fromJson(Map<String, dynamic> json) {
    return CandleData(
      time: json['time'],
      open: double.parse(json['open']),
      high: double.parse(json['high']),
      low: double.parse(json['low']),
      close: double.parse(json['close']),
      volume: double.parse(json['volume']),
    );
  }
}
