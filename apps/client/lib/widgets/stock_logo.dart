import 'package:flutter/material.dart';

class StockLogo extends StatelessWidget {
  const StockLogo({
    super.key,
    required this.symbol,
    this.size = 42,
  });

  final String symbol;
  final double size;

  static const Map<String, _LogoStyle> _styles = {
    'RELIANCE': _LogoStyle(Color(0xFF123B8A), 'R'),
    'TCS': _LogoStyle(Color(0xFF0A6FB7), 'T'),
    'HDFCBANK': _LogoStyle(Color(0xFF174EA6), 'H'),
    'INFY': _LogoStyle(Color(0xFF2563EB), 'I'),
    'ICICIBANK': _LogoStyle(Color(0xFFE85D04), 'I'),
    'ITC': _LogoStyle(Color(0xFF1D4ED8), 'ITC'),
    'HINDUNILVR': _LogoStyle(Color(0xFF0EA5E9), 'H'),
    'NESTLEIND': _LogoStyle(Color(0xFF9D174D), 'N'),
    'TATACAP': _LogoStyle(Color(0xFF1D4ED8), 'T'),
    'NSDL': _LogoStyle(Color(0xFF475569), 'N'),
  };

  @override
  Widget build(BuildContext context) {
    final normalizedSymbol = symbol.trim().toUpperCase();
    final style = _styles[normalizedSymbol] ?? _fallbackStyle(normalizedSymbol);
    final fontSize = size <= 34 ? 12.0 : 14.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        width: size - 8,
        height: size - 8,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.color,
          shape: BoxShape.circle,
        ),
        child: Text(
          style.label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  static _LogoStyle _fallbackStyle(String symbol) {
    const palette = [
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFFDC2626),
      Color(0xFF7C3AED),
      Color(0xFFEA580C),
      Color(0xFF0891B2),
    ];

    final seed = symbol.codeUnits.fold<int>(0, (total, code) => total + code);
    final label = symbol.isEmpty
        ? '?'
        : symbol.length <= 3
            ? symbol
            : symbol.substring(0, 1);

    return _LogoStyle(palette[seed % palette.length], label);
  }
}

class _LogoStyle {
  const _LogoStyle(this.color, this.label);

  final Color color;
  final String label;
}
