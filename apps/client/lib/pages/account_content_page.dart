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

    final count = _structured.length;

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
          ? (_structuredApiOk
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
                        _structured[index].title.trim().isNotEmpty
                            ? _structured[index].title
                            : 'Article ${index + 1}',
                      ),
                      subtitle:
                          _structured[index].summary?.trim().isNotEmpty == true
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
                            article: _structured[index],
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
  const WealthInsightArticlePage({super.key, required this.article});

  final InsightArticle article;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(title: AppText(article.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SelectableText(
              article.body,
              style: const TextStyle(fontSize: 16, height: 1.7),
            ),
          ),
        ),
      ),
    );
  }
}
