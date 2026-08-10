import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cet4_app/core/database/database.dart';
import 'package:cet4_app/core/providers/database_provider.dart';
import 'package:cet4_app/core/providers/settings_provider.dart';

/// A read-only, paginated browser for the active wordbook.
class WordbookBrowserScreen extends ConsumerStatefulWidget {
  const WordbookBrowserScreen({super.key});

  @override
  ConsumerState<WordbookBrowserScreen> createState() =>
      _WordbookBrowserScreenState();
}

class _WordbookBrowserScreenState extends ConsumerState<WordbookBrowserScreen> {
  static const _pageSize = 50;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Word> _words = [];

  Timer? _searchDebounce;
  String _query = '';
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _query = value.trim();
      _reload();
    });
    setState(() {});
  }

  void _loadMoreWhenNeeded() {
    if (_scrollController.position.extentAfter < 300) {
      _loadPage();
    }
  }

  Future<void> _reload() async {
    final requestId = ++_requestId;
    setState(() {
      _words.clear();
      _isInitialLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _error = null;
    });
    await _loadPage(requestId: requestId);
  }

  Future<void> _loadPage({int? requestId}) async {
    if (_isLoadingMore || !_hasMore) return;

    final currentRequestId = requestId ?? _requestId;
    setState(() => _isLoadingMore = true);
    try {
      final database = await ref.read(databaseProvider.future);
      final page = await database.getWordbookPage(
        book: ref.read(settingsProvider).activeBook,
        query: _query,
        offset: _words.length,
        limit: _pageSize,
      );
      if (!mounted || currentRequestId != _requestId) return;
      setState(() {
        _words.addAll(page);
        _hasMore = page.length == _pageSize;
        _error = null;
      });
    } catch (error) {
      if (!mounted || currentRequestId != _requestId) return;
      setState(() => _error = error);
    } finally {
      if (mounted && currentRequestId == _requestId) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookLabel = ref.watch(settingsProvider).bookLabel;

    return Scaffold(
      appBar: AppBar(title: Text('浏览 $bookLabel'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: '搜索英文单词或中文释义',
              leading: const Icon(Icons.search),
              trailing: _searchController.text.isEmpty
                  ? null
                  : [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: '清除搜索',
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                    ],
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _words.isEmpty) {
      return _ErrorView(onRetry: _reload);
    }
    if (_words.isEmpty) {
      return _EmptyView(query: _query);
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _words.length + 1,
        separatorBuilder: (_, index) => index < _words.length - 1
            ? const Divider(height: 1)
            : const SizedBox(),
        itemBuilder: (context, index) {
          if (index == _words.length) return _buildFooter();
          final word = _words[index];
          return ListTile(
            title: Text(word.word),
            subtitle: Text(
              [word.phonetic, word.pos, word.meaning]
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join('  '),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return TextButton.icon(
        onPressed: _loadPage,
        icon: const Icon(Icons.refresh),
        label: const Text('加载失败，点击重试'),
      );
    }
    return const SizedBox(height: 8);
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(query.isEmpty ? '当前词书暂无单词' : '未找到匹配的单词'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          const Text('词书加载失败'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
