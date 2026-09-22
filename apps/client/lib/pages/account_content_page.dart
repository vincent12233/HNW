import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../services/app_content_service.dart';
import '../services/insight_articles_service.dart';
import '../services/insight_list_result.dart';
import '../theme/app_colors.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_page_scaffold.dart';

class WealthInsightsPage extends StatefulWidget {
  const WealthInsightsPage({super.key});

  @override
  State<WealthInsightsPage> createState() => _WealthInsightsPageState();
}

class _WealthInsightsPageState extends State<WealthInsightsPage> {
  AppContentBundle _content = AppContentBundle.empty;
  List<InsightArticle> _structured = const [];
  bool _structuredApiOk = false;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    AppContentService.instance.addListener(_onContentChanged);
    _load();
  }

  void _onContentChanged() {
    if (mounted) setState(() => _content = AppContentService.instance.current);
  }

  @override
  void dispose() {
    AppContentService.instance.removeListener(_onContentChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final structured = await InsightArticlesService.instance.listResult();
    final content = await AppContentService.instance.load();
    if (!mounted) return;
    setState(() {
      _structuredApiOk = structured.ok;
      _structured = structured.articles;
      _content = content;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final introTitle = _content.text(
      'insights',
      'intro.title',
      fallback: 'Knowledge for informed investment decisions',
    );
    final introBody = _content.text(
      'insights',
      'intro.body',
      fallback:
          'Explore essential investment concepts, portfolio strategies, market perspectives and wealth-management principles designed to help investors make more informed financial decisions.',
    );

    // SUCCESS [] must NOT fall back to legacy KV — Admin unpublished everything.
    final useStructured = _structuredApiOk;
    final kvArticles = _content.insightArticles();
    final useKv = !useStructured && kvArticles.isNotEmpty;
    final useLocal = !useStructured && !useKv;
    final fallbackArticles = wealthInsightArticles;
    final count = useStructured
        ? _structured.length
        : useKv
        ? kvArticles.length
        : useLocal
        ? fallbackArticles.length
        : 0;

    return AppPageScaffold(
      appBar: AppBar(
        title: const AppText('Wealth Insights'),
        actions: [
          IconButton(
            tooltip: tr('Refresh'),
            onPressed: _loading || _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingView(message: 'Loading insights')
          : count == 0
          ? (useStructured
                ? AppEmptyState(
                    icon: Icons.article_outlined,
                    title: 'No published insights yet.',
                    onRetry: _refresh,
                  )
                : AppErrorView(
                    title: 'Insights are temporarily unavailable.',
                    onRetry: _refresh,
                  ))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        introTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppText(
                        introBody,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                for (var index = 0; index < count; index++)
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: AppText(
                      useStructured
                          ? (_structured[index].title.trim().isNotEmpty
                                ? _structured[index].title
                                : 'Article ${index + 1}')
                          : useKv
                          ? (kvArticles[index].title?.trim().isNotEmpty == true
                                ? kvArticles[index].title!
                                : 'Article ${index + 1}')
                          : fallbackArticles[index].$1,
                    ),
                    subtitle:
                        useStructured &&
                            (_structured[index].summary?.trim().isNotEmpty ==
                                true)
                        ? AppText(
                            _structured[index].summary!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WealthInsightArticlePage(
                          index: index,
                          structured: useStructured ? _structured[index] : null,
                          article: useKv ? kvArticles[index] : null,
                        ),
                      ),
                    ),
                  ),
              ],
              ),
            ),
    );
  }
}

class WealthInsightArticlePage extends StatelessWidget {
  const WealthInsightArticlePage({
    super.key,
    required this.index,
    this.structured,
    this.article,
  });

  final int index;
  final InsightArticle? structured;
  final AppContentBlock? article;

  @override
  Widget build(BuildContext context) {
    final fallback =
        wealthInsightArticles[index.clamp(0, wealthInsightArticles.length - 1)];
    final hindi = Localizations.localeOf(context).languageCode == 'hi';
    final title = structured?.title.trim().isNotEmpty == true
        ? structured!.title
        : article?.title?.trim().isNotEmpty == true
        ? article!.title!
        : fallback.$1;
    final body = structured?.body.trim().isNotEmpty == true
        ? structured!.body
        : article?.body.trim().isNotEmpty == true
        ? article!.body
        : (hindi ? fallback.$3 : fallback.$2);
    return AppPageScaffold(
      appBar: AppBar(title: AppText(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SelectableText(
              body,
              style: const TextStyle(fontSize: 16, height: 1.7),
            ),
          ),
        ),
      ),
    );
  }
}

const wealthInsightArticles = <(String, String, String)>[
  (
    'Account and KYC',
    'Register with your phone number and invitation code. Keep your login password private. Your account ID is read-only; your name can be updated in Personal Information.\n\nSubmit clear, complete Aadhaar or PAN documents through KYC Verification. Check the review status before adding a bank account. If documents are rejected, review the reason and upload corrected documents. Do not send identity documents through unsolicited messages.',
    'अपने मोबाइल नंबर और आमंत्रण कोड से पंजीकरण करें। लॉगिन पासवर्ड गोपनीय रखें। खाता आईडी बदली नहीं जा सकती; व्यक्तिगत जानकारी में नाम बदला जा सकता है।\n\nकेवाईसी सत्यापन में स्पष्ट और पूर्ण आधार या पैन दस्तावेज़ जमा करें। बैंक खाता जोड़ने से पहले समीक्षा की स्थिति देखें। अस्वीकृति पर कारण पढ़ें और सही दस्तावेज़ जमा करें। अनचाहे संदेशों में पहचान दस्तावेज़ न भेजें।',
  ),
  (
    'Market basics',
    'A quote is the latest available price, not a promise of execution. Quotes may be delayed or unavailable. Check the exchange, trading session and quote timestamp before placing an order.\n\nA watchlist tracks instruments; adding a symbol does not buy it. Price charts show historical market observations. They do not predict future returns.',
    'भाव नवीनतम उपलब्ध कीमत है, निष्पादन की गारंटी नहीं। भाव में देरी हो सकती है या वह उपलब्ध नहीं हो सकता। ऑर्डर देने से पहले एक्सचेंज, सत्र और भाव का समय देखें।\n\nवॉचलिस्ट केवल शेयरों पर नज़र रखती है; शेयर जोड़ने से खरीद नहीं होती। चार्ट पिछले बाज़ार भाव दिखाते हैं, भविष्य के रिटर्न का अनुमान नहीं।',
  ),
  (
    'Order types',
    'A market order requests execution at the available price. The final price can differ from the quote, especially when liquidity is low or prices move quickly.\n\nA limit order sets the highest purchase price or lowest sale price you accept. It may fill partly or not at all. Review quantity, price, available funds and order status. An order submission is not a completed trade; check fills in Order Book and Order History.',
    'मार्केट ऑर्डर उपलब्ध भाव पर निष्पादन का अनुरोध करता है। कम तरलता या तेज़ बदलाव में अंतिम कीमत दिखाए गए भाव से अलग हो सकती है।\n\nलिमिट ऑर्डर खरीद की अधिकतम या बिक्री की न्यूनतम स्वीकार्य कीमत तय करता है। वह आंशिक रूप से पूरा हो सकता है या नहीं भी। मात्रा, कीमत, उपलब्ध राशि और स्थिति जाँचें। ऑर्डर भेजना पूरा हुआ ट्रेड नहीं है; ऑर्डर बुक और इतिहास में निष्पादन देखें।',
  ),
  (
    'Order validity',
    'DAY orders remain eligible during the trading day and expire if not filled by the session cutoff. IOC means immediate-or-cancel: any unfilled remainder is cancelled. FOK means fill-or-kill: the entire quantity must execute immediately or the order is cancelled.\n\nOnly use validity options supported by the selected order screen. A cancellation request may race with a fill. Refresh the order status and holdings before submitting a replacement.',
    'DAY ऑर्डर ट्रेडिंग दिन तक मान्य रहता है और सत्र समाप्त होने पर अधूरा हिस्सा समाप्त हो जाता है। IOC में तुरंत पूरा न हुआ हिस्सा रद्द होता है। FOK में पूरी मात्रा तुरंत पूरी होनी चाहिए, अन्यथा ऑर्डर रद्द होता है।\n\nकेवल ऑर्डर स्क्रीन पर उपलब्ध अवधि विकल्प चुनें। रद्द करने के दौरान भी निष्पादन हो सकता है। नया ऑर्डर देने से पहले स्थिति और होल्डिंग रीफ़्रेश करें।',
  ),
  (
    'Funding and withdrawals',
    'Use Add Funds to open the Deposit page and contact in-app support. Finance credits your account after payment is confirmed. Check the Funds Ledger for completed entries.\n\nSet a six-digit Withdrawal PIN in Profile. This is separate from your login password and is required when submitting a withdrawal. Add a bank account and check available funds. The minimum withdrawal is INR 100. Submitted funds are frozen during review; approval debits cash, while rejection releases the frozen amount. Keep the withdrawal order number for follow-up.',
    'राशि जोड़ने के लिए ऐप की सहायता टीम से संपर्क करें। वित्त टीम की पुष्टि और क्रेडिट के बाद ही राशि दिखाई देती है। पूरे हुए लेनदेन राशि के लेजर में देखें।\n\nप्रोफ़ाइल में छह अंकों का निकासी पिन सेट करें। यह लॉगिन पासवर्ड से अलग है और निकासी अनुरोध के लिए आवश्यक है। स्वीकृत बैंक खाता जोड़ें और उपलब्ध राशि जाँचें। न्यूनतम निकासी 100 रुपये है। समीक्षा के दौरान राशि रोक दी जाती है; स्वीकृति पर कटती है और अस्वीकृति पर मुक्त होती है। अनुरोध का ऑर्डर नंबर सुरक्षित रखें।',
  ),
  (
    'Holdings and returns',
    'Home Total Asset Value combines account cash and all stock holdings. Available funds and frozen margin are parts of account funds, not additional assets. Portfolio is limited to Institutional, OTC and IPO holdings; ordinary stocks remain in trading holdings.\n\nUnrealized profit or loss compares current valuation with acquisition cost. Realized profit or loss comes from completed sales. Period returns use recorded account profit observations, not deposits. History begins when reliable observations are available; insufficient history is shown explicitly. Missing quotes may use cost as a fallback valuation.',
    'होम पर कुल परिसंपत्ति मूल्य में खाते की नकदी और सभी शेयर होल्डिंग शामिल हैं। उपलब्ध राशि और रोका गया मार्जिन खाते की राशि के हिस्से हैं, अतिरिक्त परिसंपत्तियाँ नहीं। पोर्टफोलियो में केवल संस्थागत, ओटीसी और आईपीओ हैं; सामान्य शेयर ट्रेडिंग होल्डिंग में रहते हैं।\n\nअप्राप्त लाभ या हानि वर्तमान मूल्य और खरीद लागत का अंतर है। प्राप्त लाभ या हानि पूरी हुई बिक्री से आती है। अवधि का रिटर्न दर्ज किए गए लाभ के अवलोकनों पर आधारित है, जमा राशि पर नहीं। पर्याप्त विश्वसनीय इतिहास न होने पर यह स्पष्ट दिखाया जाता है। भाव न मिलने पर लागत को वैकल्पिक मूल्य माना जा सकता है।',
  ),
  (
    'Institutional, OTC and IPO',
    'Review each offer’s price, eligibility and terms before submitting. Institutional offers and OTC orders can require review. An application or pending order is not a settled holding.\n\nIPO applications may be pending, allocated or rejected. An allocation can create an outstanding payment obligation. Check the allocation notice, required payment and status before assuming shares are available to sell. Portfolio allocation includes settled positions, not pending applications. Availability and returns are never guaranteed.',
    'आवेदन से पहले हर प्रस्ताव की कीमत, पात्रता और शर्तें पढ़ें। संस्थागत प्रस्ताव और ओटीसी ऑर्डर की समीक्षा आवश्यक हो सकती है। आवेदन या लंबित ऑर्डर निपटान की गई होल्डिंग नहीं है।\n\nआईपीओ आवेदन लंबित, आवंटित या अस्वीकृत हो सकता है। आवंटन पर भुगतान बकाया हो सकता है। शेयर बेचने योग्य मानने से पहले आवंटन सूचना, भुगतान और स्थिति जाँचें। परिसंपत्ति आवंटन में निपटान की गई होल्डिंग आती है, लंबित आवेदन नहीं। उपलब्धता और रिटर्न की गारंटी नहीं है।',
  ),
  (
    'Risk and account security',
    'Investments can lose value. Concentration, liquidity, price gaps and operational delays can increase losses. Borrowed funds add repayment obligations. Read product terms and do not rely on past performance as a guarantee.\n\nNever share passwords or your Withdrawal PIN, including with someone claiming to be support. Change your login password from Change Password and your withdrawal password from Transaction PIN. Five failed PIN attempts temporarily lock PIN verification. If you suspect account misuse, contact in-app support promptly. This learning material is general education, not personalized investment advice.',
    'निवेश का मूल्य घट सकता है। एक ही निवेश में अधिक राशि, कम तरलता, कीमत में अंतर और परिचालन देरी से नुकसान बढ़ सकता है। उधार की राशि चुकाने की ज़िम्मेदारी होती है। उत्पाद की शर्तें पढ़ें और पिछले प्रदर्शन को गारंटी न मानें।\n\nपासवर्ड या निकासी पिन किसी से साझा न करें, सहायता कर्मचारी होने का दावा करने वाले से भी नहीं। लॉगिन पासवर्ड और निकासी पिन अलग पृष्ठों से बदलें। पाँच गलत पिन प्रयासों के बाद सत्यापन अस्थायी रूप से बंद हो जाता है। दुरुपयोग की आशंका पर ऐप सहायता से संपर्क करें। यह सामान्य शिक्षा है, व्यक्तिगत निवेश सलाह नहीं।',
  ),
];
