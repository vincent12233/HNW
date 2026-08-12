class MarketHistoryPoint {
  const MarketHistoryPoint({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  factory MarketHistoryPoint.fromJson(Map<String, dynamic> json) {
    return MarketHistoryPoint(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      open: _double(json['open']),
      high: _double(json['high']),
      low: _double(json['low']),
      close: _double(json['close']),
      volume: _int(json['volume']),
    );
  }
}

class MarketHistorySeries {
  const MarketHistorySeries({
    required this.symbol,
    required this.interval,
    required this.data,
  });

  final String symbol;
  final String interval;
  final List<MarketHistoryPoint> data;

  factory MarketHistorySeries.fromJson(Map<String, dynamic> json) {
    final rows = json['data'];
    return MarketHistorySeries(
      symbol: json['symbol']?.toString() ?? '',
      interval: json['interval']?.toString() ?? '1d',
      data: rows is List
          ? rows
              .whereType<Map>()
              .map((row) => MarketHistoryPoint.fromJson(
                    Map<String, dynamic>.from(row),
                  ))
              .where((point) => point.close > 0)
              .toList()
          : <MarketHistoryPoint>[],
    );
  }
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
