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

  bool get isValid =>
      date.millisecondsSinceEpoch > 0 &&
      open > 0 &&
      high > 0 &&
      low > 0 &&
      close > 0 &&
      high >= open &&
      high >= close &&
      low <= open &&
      low <= close;

  factory MarketHistoryPoint.fromJson(Map<String, dynamic> json) {
    return MarketHistoryPoint(
      date:
          DateTime.tryParse(json['date']?.toString() ?? '') ??
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
    required this.exchange,
    required this.range,
    required this.timezone,
    this.delayed = false,
    this.events = const <MarketHistoryEvent>[],
  });

  final String symbol;
  final String interval;
  final List<MarketHistoryPoint> data;
  final String exchange;
  final String range;
  final String timezone;
  final bool delayed;
  final List<MarketHistoryEvent> events;

  factory MarketHistorySeries.fromJson(
    Map<String, dynamic> json, {
    bool delayed = false,
  }) {
    final rows = json['data'];
    return MarketHistorySeries(
      symbol: json['symbol']?.toString() ?? '',
      interval: json['interval']?.toString() ?? '1d',
      exchange: json['exchange']?.toString() ?? 'NSE',
      range: json['range']?.toString() ?? '1D',
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
      delayed: delayed,
      events: json['events'] is List
          ? (json['events'] as List)
                .whereType<Map>()
                .map(
                  (row) => MarketHistoryEvent.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .where((event) => event.isValid)
                .toList()
          : const <MarketHistoryEvent>[],
      data: rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => MarketHistoryPoint.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .where((point) => point.isValid)
                .toList()
          : <MarketHistoryPoint>[],
    );
  }
}

class MarketHistoryEvent {
  const MarketHistoryEvent({
    required this.date,
    required this.type,
    required this.value,
    required this.label,
  });

  final DateTime date;
  final String type;
  final double value;
  final String label;

  bool get isValid =>
      date.millisecondsSinceEpoch > 0 &&
      (type == 'DIVIDEND' || type == 'SPLIT') &&
      value > 0;

  factory MarketHistoryEvent.fromJson(Map<String, dynamic> json) {
    return MarketHistoryEvent(
      date:
          DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      type: json['type']?.toString().toUpperCase() ?? '',
      value: _double(json['value']),
      label: json['label']?.toString() ?? '',
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
