import 'package:flutter/material.dart';

class StockLogo extends StatelessWidget {
  const StockLogo({
    super.key,
    required this.symbol,
    this.size = 42,
    this.logoUrl,
    this.onLoadFailed,
  });

  final String symbol;
  final double size;
  final String? logoUrl;
  final VoidCallback? onLoadFailed;

  static const Map<String, _LogoStyle> _styles = {
    'RELIANCE': _LogoStyle(Color(0xFF123B8A), Icons.energy_savings_leaf),
    'TCS': _LogoStyle(Color(0xFF0A6FB7), Icons.hub_outlined),
    'HDFCBANK': _LogoStyle(Color(0xFF174EA6), Icons.account_balance),
    'INFY': _LogoStyle(Color(0xFF2563EB), Icons.memory),
    'ICICIBANK': _LogoStyle(Color(0xFFE85D04), Icons.account_balance_wallet),
    'ITC': _LogoStyle(Color(0xFF1D4ED8), Icons.apartment),
    'HINDUNILVR': _LogoStyle(Color(0xFF0EA5E9), Icons.water_drop),
    'NESTLEIND': _LogoStyle(Color(0xFF9D174D), Icons.local_cafe),
    'SBIN': _LogoStyle(Color(0xFF2563EB), Icons.account_balance),
    'BHARTIARTL': _LogoStyle(Color(0xFFDC2626), Icons.network_cell),
    'LT': _LogoStyle(Color(0xFF1E40AF), Icons.engineering),
    'AXISBANK': _LogoStyle(Color(0xFF9F1239), Icons.account_balance),
    'KOTAKBANK': _LogoStyle(Color(0xFF1D4ED8), Icons.account_balance),
    'MARUTI': _LogoStyle(Color(0xFF2563EB), Icons.directions_car),
    'TITAN': _LogoStyle(Color(0xFF7C2D12), Icons.watch),
    'BAJFINANCE': _LogoStyle(Color(0xFF0369A1), Icons.payments),
    'SUNPHARMA': _LogoStyle(Color(0xFFEA580C), Icons.medication),
    'TATACAP': _LogoStyle(Color(0xFF1D4ED8), Icons.business),
    'NSDL': _LogoStyle(Color(0xFF475569), Icons.security),
  };

  @override
  Widget build(BuildContext context) {
    final normalizedSymbol = symbol.trim().toUpperCase();
    final style = _styles[normalizedSymbol] ?? _fallbackStyle(normalizedSymbol);
    final letters = normalizedSymbol.replaceAll(RegExp('[^A-Z0-9]'), '');
    final monogram = _styles.containsKey(normalizedSymbol)
        ? null
        : letters.isEmpty
        ? '?'
        : letters.substring(0, letters.length > 2 ? 2 : letters.length);
    final resolvedLogoUrl = logoUrl?.trim().isNotEmpty == true
        ? logoUrl!.trim()
        : null;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: ClipOval(
        child: resolvedLogoUrl == null
            ? _FallbackLogo(style: style, size: size, monogram: monogram)
            : Image.network(
                resolvedLogoUrl,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                width: size - 6,
                height: size - 6,
                fit: BoxFit.contain,
                semanticLabel: '$normalizedSymbol logo',
                filterQuality: FilterQuality.medium,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _FallbackLogo(
                    style: style,
                    size: size,
                    monogram: monogram,
                  );
                },
                errorBuilder: (_, _, _) {
                  if (onLoadFailed != null) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => onLoadFailed!(),
                    );
                    return const SizedBox.shrink();
                  }
                  return _FallbackLogo(
                    style: style,
                    size: size,
                    monogram: monogram,
                  );
                },
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
    return _LogoStyle(palette[seed % palette.length], Icons.show_chart);
  }
}

class _LogoStyle {
  const _LogoStyle(this.color, this.icon);

  final Color color;
  final IconData icon;
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.style, required this.size, this.monogram});
  final String? monogram;

  final _LogoStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size - 8,
      height: size - 8,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
      child: monogram == null
          ? Icon(style.icon, color: Colors.white, size: size * 0.48)
          : Padding(
              padding: const EdgeInsets.all(3),
              child: FittedBox(
                child: Text(
                  monogram!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
    );
  }
}
