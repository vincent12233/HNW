part of 'market_page.dart';

extension _MarketHomeDataLifecycle on _MarketHomePageState {
  Future<void> _loadHomeOpsContent() async {
    final results = await Future.wait<dynamic>([
      AnnouncementsService.instance.list(),
      FeaturedInstrumentsService.instance.homeFeatured(),
    ]);
    if (!mounted) return;
    final announcements = results[0] as List<AnnouncementItem>;
    final featured = results[1] as List<StockQuote>;
    _updateState(() {
      _homeAnnouncement = pickTopAnnouncement(announcements);
      _homeFeatured
        ..clear()
        ..addAll(featured);
    });
    if (!_optionalUpdatePrompted) {
      _optionalUpdatePrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(maybeShowOptionalUpdateDialog(context));
      });
    }
  }

  Future<void> _loadAppContent({bool force = false}) async {
    final content = await AppContentService.instance.load(force: force);
    if (!mounted) return;
    _updateState(() => _appContent = content);
  }

  Future<void> _loadHomeIndexHistory() async {
    const instruments = <(String, String, String)>[
      ('NIFTY 50', 'NIFTY50', 'NSE'),
      ('SENSEX', 'SENSEX', 'BSE'),
      ('BANK NIFTY', 'BANKNIFTY', 'NSE'),
      ('INDIA VIX', 'INDIAVIX', 'NSE'),
    ];
    final results = await Future.wait(
      instruments.map((instrument) async {
        try {
          final history = await marketDataService.fetchHistory(
            symbol: instrument.$2,
            exchange: instrument.$3,
            range: '1D',
          );
          return (
            instrument.$1,
            history.data.map((point) => point.close).toList(),
          );
        } catch (_) {
          return (instrument.$1, <double>[]);
        }
      }),
    );
    if (!mounted) return;
    _updateState(() {
      for (final result in results) {
        if (result.$2.length >= 2) indexHistory[result.$1] = result.$2;
      }
    });
  }

  void _handleMarketConnection(bool connected) {
    if (!mounted || marketConnected == connected) return;
    _updateState(() => marketConnected = connected);
  }

  Future<void> _refreshMarketSession() async {
    final status = await marketDataService.fetchMarketSession();
    if (!mounted) return;
    final openTime = status?['openTime']?.toString();
    final closeTime = status?['closeTime']?.toString();
    _updateState(() {
      marketOpen = status?['isOpen'] is bool ? status!['isOpen'] as bool : null;
      if (openTime?.isNotEmpty == true && closeTime?.isNotEmpty == true) {
        marketHours = '$openTime - $closeTime IST';
      }
    });
  }

  Future<void> _refreshAccountSnapshot() async {
    final active = _accountRefreshInFlight;
    if (active != null) return active;
    final refresh = _performAccountRefresh();
    _accountRefreshInFlight = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_accountRefreshInFlight, refresh)) {
        _accountRefreshInFlight = null;
      }
    }
  }

  Future<void> _performAccountRefresh() async {
    if (!mounted) return;
    final previousState = _accountSnapshotState;
    _updateState(() {
      _accountSnapshotState = AsyncDataState.loading(
        data: previousState.data,
        updatedAt: previousState.updatedAt,
      );
    });
    try {
      final snapshot = await tradingService.fetchAccountSnapshot(
        allowCached: false,
      );
      if (!mounted) return;
      if (snapshot == null) throw StateError('Account snapshot unavailable');
      _updateState(() {
        _accountSnapshotState = AsyncDataState.success(snapshot);
        _applyAccountSnapshot(snapshot);
      });
    } catch (error) {
      if (!mounted) return;
      _updateState(() {
        final previousSnapshot = _accountSnapshotState.data;
        _accountSnapshotState = previousSnapshot == null
            ? AsyncDataState.error(clientErrorMessage(error))
            : AsyncDataState.stale(
                previousSnapshot,
                updatedAt: _accountSnapshotState.updatedAt ?? DateTime.now(),
                message: clientErrorMessage(error),
              );
      });
    }
  }

  Future<void> _refreshMarketData() async {
    final active = _marketRefreshInFlight;
    if (active != null) return active;
    final refresh = _performMarketRefresh();
    _marketRefreshInFlight = refresh;
    try {
      await refresh;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: AppText('Unable to refresh market data')),
          );
      }
    } finally {
      if (identical(_marketRefreshInFlight, refresh)) {
        _marketRefreshInFlight = null;
      }
    }
  }

  Future<void> _performMarketRefresh() async {
    unawaited(_loadAppContent(force: true));
    final results = await Future.wait<dynamic>([
      marketDataService.fetchSnapshot(),
      marketDataService.fetchIndexSnapshot(),
      marketDataService.fetchMarketSession(),
      marketDataService.fetchInstitutionalOffers(),
      marketDataService.fetchMarketNews(),
      marketDataService.fetchCompanyShowcase(),
      _loadHomeIndexHistory(),
    ]);
    if (!mounted) return;
    final refreshedStocks = results[0] as List<StockQuote>;
    final indices = results[1] as List<Map<String, dynamic>>;
    final session = results[2] as Map<String, dynamic>?;
    final refreshedInstitutional = results[3] as List<InstitutionalStock>;
    final refreshedNews = results[4] as List<MarketNewsItem>;
    final refreshedCompanies = results[5] as List<CompanyShowcase>;
    _updateState(() {
      if (refreshedStocks.isNotEmpty) {
        stocks
          ..clear()
          ..addAll(refreshedStocks);
      }
      companyShowcases
        ..clear()
        ..addAll(refreshedCompanies);
      for (final item in indices) {
        final symbol = item['symbol']?.toString().trim().toUpperCase();
        final price = double.tryParse(item['price']?.toString() ?? '');
        final change = double.tryParse(item['change']?.toString() ?? '') ?? 0;
        if (price == null) continue;
        if (symbol != null && symbol.isNotEmpty) {
          indexQuotes[symbol] = (price, change);
        }
        if (symbol == 'NIFTY50') {
          nifty50Price = price;
          nifty50Change = change;
        } else if (symbol == 'SENSEX') {
          sensexPrice = price;
          sensexChange = change;
        } else if (symbol == 'BANKNIFTY') {
          bankNiftyPrice = price;
          bankNiftyChange = change;
        }
      }
      marketOpen = session?['isOpen'] is bool
          ? session!['isOpen'] as bool
          : null;
      if (session != null) {
        final openTime = session['openTime']?.toString();
        final closeTime = session['closeTime']?.toString();
        if (openTime?.isNotEmpty == true && closeTime?.isNotEmpty == true) {
          marketHours = '$openTime - $closeTime IST';
        }
      }
      institutionalStocks
        ..clear()
        ..addAll(refreshedInstitutional);
      if (refreshedNews.isNotEmpty) {
        marketNews
          ..clear()
          ..addAll(refreshedNews);
      }
    });
  }

  Future<void> _loadDashboardSection(Future<void> Function() load) async {
    try {
      await load();
    } catch (_) {
      // Each endpoint loads independently, preserving other confirmed data.
    } finally {
      if (mounted) _updateState(() {});
    }
  }

  Future<void> _loadAppData() async {
    try {
      final session = await AuthService().restoreSession();
      if (!mounted) return;
      _updateState(() {
        accountName = session?.fullName.isNotEmpty == true
            ? session!.fullName
            : 'Client';
        accountPhone = session?.phone ?? '';
        accountNumber = session?.accountNumber ?? '';
      });
    } catch (_) {
      // Authentication recovery is handled by the session-expiry flow.
    }
    if (!mounted) return;
    await Future.wait<void>([
      _refreshAccountSnapshot(),
      _loadDashboardSection(() async {
        if (accountPhone.isNotEmpty) {
          kycStatus = await AuthService().fetchKycStatus();
        }
      }),
      _loadDashboardSection(() async {
        final remote = await marketDataService.fetchSnapshot();
        if (remote.isNotEmpty) {
          stocks
            ..clear()
            ..addAll(remote);
        }
      }),
      _loadDashboardSection(() async {
        final indices = await marketDataService.fetchIndexSnapshot();
        for (final item in indices) {
          final symbol = item['symbol']?.toString().trim().toUpperCase() ?? '';
          final price = double.tryParse(item['price']?.toString() ?? '');
          final change = double.tryParse(item['change']?.toString() ?? '') ?? 0;
          if (symbol.isEmpty || price == null) continue;
          indexQuotes[symbol] = (price, change);
          if (symbol == 'NIFTY50') {
            nifty50Price = price;
            nifty50Change = change;
          } else if (symbol == 'SENSEX') {
            sensexPrice = price;
            sensexChange = change;
          } else if (symbol == 'BANKNIFTY') {
            bankNiftyPrice = price;
            bankNiftyChange = change;
          }
        }
      }),
      _loadDashboardSection(_refreshMarketSession),
      _loadDashboardSection(() async {
        final remote = await tradingService.fetchOrders();
        orders
          ..clear()
          ..addAll(remote);
      }),
      _loadDashboardSection(() async {
        final remote = await marketDataService.fetchInstitutionalOffers();
        institutionalStocks
          ..clear()
          ..addAll(remote);
      }),
      _loadDashboardSection(() async {
        final remote = await AuthService().fetchWithdrawals();
        withdrawalRequests
          ..clear()
          ..addAll(remote);
      }),
      _loadDashboardSection(() async {
        try {
          final remote = await ipoService.fetchOpenIpos();
          ipos
            ..clear()
            ..addAll(remote);
          _iposFailed = false;
        } catch (_) {
          _iposFailed = true;
          rethrow;
        }
      }),
      _loadDashboardSection(() async {
        try {
          final remote = await ipoService.fetchMyApplications();
          ipoApplications
            ..clear()
            ..addAll(remote);
          _ipoApplicationsFailed = false;
        } catch (_) {
          _ipoApplicationsFailed = true;
          rethrow;
        }
      }),
      _loadDashboardSection(() async {
        final profile = await ClientAccountService().profile();
        _profileData = profile;
        final avatar = profile['avatarData'];
        profileAvatarBytes = avatar is String && avatar.isNotEmpty
            ? base64Decode(avatar)
            : null;
        accountName = profile['fullName']?.toString() ?? accountName;
        accountPhone = profile['phone']?.toString() ?? accountPhone;
        accountNumber =
            profile['account']?['accountNumber']?.toString() ?? accountNumber;
      }),
      _loadDashboardSection(() async {
        final settings = await ClientAccountService().preferences();
        await AppLanguage.instance.select(
          settings['language']?.toString() ?? 'en',
        );
        await _loadAppContent(force: true);
        await AppearanceSettings.instance.select(
          settings['theme']?.toString() ?? 'light',
        );
      }),
      _loadDashboardSection(_refreshUnreadNotificationCount),
      _loadDashboardSection(() async {
        final remote = await marketDataService.fetchMarketNews();
        if (remote.isNotEmpty) {
          marketNews
            ..clear()
            ..addAll(remote);
        }
      }),
    ]);
    if (!mounted) return;
    _updateState(() => isLoading = false);
    unawaited(_loadPortfolioHistory(_portfolioPeriod));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && selectedIndex == 0) _showPendingIpoAllocationIfNeeded();
    });
  }
}
