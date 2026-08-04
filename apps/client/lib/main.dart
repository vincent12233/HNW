import 'package:flutter/material.dart';

void main() {
  runApp(const IndiaTradingApp());
}

class IndiaTradingApp extends StatelessWidget {
  const IndiaTradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'India Trading',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF143D8D),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;

  void login() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const MarketHomePage(),
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFF143D8D),
                  child: Icon(
                    Icons.candlestick_chart,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'India Trading',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to your investment account',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixText: '+91 ',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: login,
                    child: const Text(
                      'Sign In',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('Create New Account'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sandbox environment • Test data only',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MarketHomePage extends StatefulWidget {
  const MarketHomePage({super.key});

  @override
  State<MarketHomePage> createState() => _MarketHomePageState();
}

class _MarketHomePageState extends State<MarketHomePage> {
  int selectedIndex = 0;

  final List<StockQuote> stocks = const [
    StockQuote('RELIANCE', 'Reliance Industries', 2984.40, 1.28),
    StockQuote('TCS', 'Tata Consultancy', 4217.75, -0.42),
    StockQuote('HDFCBANK', 'HDFC Bank', 1765.10, 0.86),
    StockQuote('INFY', 'Infosys', 1928.60, 2.14),
    StockQuote('ICICIBANK', 'ICICI Bank', 1284.30, -0.31),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF143D8D),
        foregroundColor: Colors.white,
        title: const Text(
          'India Trading',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: selectedIndex == 0
          ? _marketBody()
          : _placeholderPage(selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Markets',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            label: 'Watchlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  Widget _marketBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.science_outlined, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sandbox mode: prices and orders are for testing only.',
                  style: TextStyle(color: Color(0xFF8A4B00)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Market Indices',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 700
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: const IndexCard(
                    name: 'NIFTY 50',
                    value: '24,864.25',
                    change: '+132.40 (0.54%)',
                    positive: true,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: const IndexCard(
                    name: 'SENSEX',
                    value: '81,224.75',
                    change: '-118.30 (0.15%)',
                    positive: false,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Popular Stocks',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View all'),
            ),
          ],
        ),
        Card(
          color: Colors.white,
          child: Column(
            children: stocks.map((stock) {
              final positive = stock.change >= 0;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE8EEFA),
                  child: Text(
                    stock.symbol.substring(0, 1),
                    style: const TextStyle(
                      color: Color(0xFF143D8D),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  stock.symbol,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(stock.name),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${stock.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${positive ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: positive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                onTap: () {},
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _placeholderPage(int index) {
    const titles = [
      'Markets',
      'Watchlist',
      'Orders',
      'Portfolio',
      'Account',
    ];

    return Center(
      child: Text(
        '${titles[index]} module coming next',
        style: const TextStyle(
          fontSize: 20,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class IndexCard extends StatelessWidget {
  final String name;
  final String value;
  final String change;
  final bool positive;

  const IndexCard({
    super.key,
    required this.name,
    required this.value,
    required this.change,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final color = positive ? Colors.green : Colors.red;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              change,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StockQuote {
  final String symbol;
  final String name;
  final double price;
  final double change;

  const StockQuote(
    this.symbol,
    this.name,
    this.price,
    this.change,
  );
}