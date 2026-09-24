import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/app_logger.dart';
import '../../../features/location/data/places_api.dart';
import '../../../l10n/l10n_extensions.dart';

/// Sunucuda il/ilçe arar: kutu + debounce + sonuç listesi.
///
/// Açılışta boş sorgu gönderilir; sunucu il merkezlerini (popüler önce) döner,
/// kullanıcı hiç yazmadan büyük şehirleri görür. Yazarken 300 ms bekler; 2
/// karakterden kısa sorguda istek atılmaz. Ağ/sunucu hatası "internet gerekli"
/// + yeniden dene olur; arama metni log'lanmaz.
class PlaceSearchPanel extends StatefulWidget {
  final PlacesApi api;
  final ValueChanged<PlaceMatch> onSelected;
  final bool autofocus;

  static const Duration debounce = Duration(milliseconds: 300);
  static const int minQueryLength = 2;
  static const int resultLimit = 10;

  const PlaceSearchPanel({
    super.key,
    required this.api,
    required this.onSelected,
    this.autofocus = true,
  });

  @override
  State<PlaceSearchPanel> createState() => _PlaceSearchPanelState();
}

class _PlaceSearchPanelState extends State<PlaceSearchPanel> {
  final _controller = TextEditingController();
  Timer? _timer;

  /// Geç gelen eski cevabın yeni sonuçların üstüne yazmasını engeller.
  int _requestSeq = 0;

  List<PlaceMatch> _results = const [];
  bool _searching = false;
  bool _failed = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _search('');
      return;
    }
    if (query.length < PlaceSearchPanel.minQueryLength) return;
    _timer = Timer(PlaceSearchPanel.debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final seq = ++_requestSeq;
    setState(() {
      _searching = true;
      _failed = false;
      _lastQuery = query;
    });
    try {
      final results = await widget.api.search(
        query,
        limit: PlaceSearchPanel.resultLimit,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } on Exception catch (e) {
      // Ağ, zaman aşımı, 5xx/503, bozuk gövde: kullanıcı için tek anlam,
      // "sunucuya ulaşılamadı".
      if (!mounted || seq != _requestSeq) return;
      AppLogger().warning('Place search failed', e);
      setState(() {
        _results = const [];
        _searching = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(),
        const SizedBox(height: 12),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildField() {
    final tokens = context.tokens;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        style: TextStyle(color: tokens.textPrimary),
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: context.l10n.locationSearchPlaceholder,
          hintStyle: TextStyle(color: tokens.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: tokens.textTertiary),
          suffixIcon: _buildSuffix(),
        ),
      ),
    );
  }

  Widget? _buildSuffix() {
    final tokens = context.tokens;
    if (_searching) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: tokens.accent,
          ),
        ),
      );
    }
    if (_controller.text.isNotEmpty) {
      return IconButton(
        icon: Icon(Icons.close_rounded, color: tokens.textTertiary),
        onPressed: () {
          _controller.clear();
          _onChanged('');
        },
      );
    }
    return null;
  }

  Widget _buildBody() {
    final tokens = context.tokens;
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.locationNeedsInternet,
              textAlign: TextAlign.center,
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _search(_lastQuery),
              child: Text(context.l10n.actionRetry),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      if (_searching) return const SizedBox.shrink();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.locationSearchNoResult,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textTertiary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: _results.length,
      itemBuilder: (context, index) => _tile(_results[index]),
    );
  }

  Widget _tile(PlaceMatch match) {
    final tokens = context.tokens;
    final alias = match.matchedAlias;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        widget.onSelected(match);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.surface),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: tokens.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.displayName,
                    style: TextStyle(color: tokens.textPrimary, fontSize: 15),
                  ),
                  if (alias != null)
                    Text(
                      context.l10n.placeAliasIncluded(alias),
                      style: AppTypography.hint.copyWith(
                        color: tokens.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
