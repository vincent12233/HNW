import 'package:flutter/material.dart';

class StockLogo extends StatelessWidget {
  const StockLogo({
    super.key,
    required this.symbol,
    this.size = 42,
    this.logoUrl,
  });

  final String symbol;
  final double size;
  final String? logoUrl;

  static const Map<String, String> _logoUrls = {
    'RELIANCE': 'https://logo.clearbit.com/ril.com',
    'TCS': 'https://logo.clearbit.com/tcs.com',
    'HDFCBANK': 'https://logo.clearbit.com/hdfcbank.com',
    'INFY': 'https://logo.clearbit.com/infosys.com',
    'ICICIBANK': 'https://logo.clearbit.com/icicibank.com',
    'ITC': 'https://logo.clearbit.com/itcportal.com',
    'HINDUNILVR': 'https://logo.clearbit.com/hul.co.in',
    'NESTLEIND': 'https://logo.clearbit.com/nestle.in',
    'SBIN': 'https://logo.clearbit.com/sbi.co.in',
    'BHARTIARTL': 'https://logo.clearbit.com/airtel.in',
    'LT': 'https://logo.clearbit.com/larsentoubro.com',
    'AXISBANK': 'https://logo.clearbit.com/axisbank.com',
    'KOTAKBANK': 'https://logo.clearbit.com/kotak.com',
    'MARUTI': 'https://logo.clearbit.com/marutisuzuki.com',
    'TITAN': 'https://logo.clearbit.com/titancompany.in',
    'BAJFINANCE': 'https://logo.clearbit.com/bajajfinserv.in',
    'SUNPHARMA': 'https://logo.clearbit.com/sunpharma.com',
    'TATACAP': 'https://logo.clearbit.com/tatacapital.com',
    'NSDL': 'https://logo.clearbit.com/nsdl.co.in',
  };

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
    final resolvedLogoUrl = logoUrl?.trim().isNotEmpty == true
        ? logoUrl!.trim()
        : _logoUrls[normalizedSymbol];

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
            ? _FallbackLogo(style: style, size: size)
            : Image.network(
                resolvedLogoUrl,
                width: size - 6,
                height: size - 6,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _FallbackLogo(style: style, size: size);
                },
                errorBuilder: (_, _, _) =>
                    _FallbackLogo(style: style, size: size),
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
  const _FallbackLogo({required this.style, required this.size});

  final _LogoStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size - 8,
      height: size - 8,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
      child: Icon(style.icon, color: Colors.white, size: size * 0.48),
    );
  }
}
