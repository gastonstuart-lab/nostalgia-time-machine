import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../state.dart';
import '../services/youtube_service.dart';
import '../models/youtube_search_result.dart';
import '../components/theme_toggle.dart';

class AddTVEpisodeScreen extends StatefulWidget {
  const AddTVEpisodeScreen({super.key});

  @override
  State<AddTVEpisodeScreen> createState() => _AddTVEpisodeScreenState();
}

class _AddTVEpisodeScreenState extends State<AddTVEpisodeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final YouTubeService _youtubeService = YouTubeService();
  List<YouTubeSearchResult> _results = [];
  bool _isSearching = false;
  String? _errorMessage;

  Future<void> _search([String? queryOverride]) async {
    final query = (queryOverride ?? _searchController.text).trim();
    if (query.isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await _youtubeService.searchVideos(query, maxResults: 10);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = e.toString().contains('API key not configured')
              ? 'YouTube API key not configured. Please add your API key in lib/config/youtube_config.dart'
              : 'Failed to search YouTube. Please try again.';
        });
      }
    }
  }

  void _handleChipTap(String label) {
    _searchController.text = label;
    _search(label);
  }

  void _handleSuggest(int year) {
    final queries = [
      'best sitcom episode $year',
      'classic TV episode $year',
      '${year}s television episode',
      'popular TV show $year',
    ];
    final query = queries[DateTime.now().millisecond % queries.length];
    _searchController.text = query;
    _search(query);
  }

  Future<void> _addEpisode(YouTubeSearchResult result) async {
    final provider = context.read<NostalgiaProvider>();
    final episodes = provider.episodes;

    // Check limit before attempting
    if (episodes.length >= 1) {
      if (!mounted) return;
      _showLimitDialog();
      return;
    }

    final youtubeUrl = 'https://www.youtube.com/watch?v=${result.videoId}';
    
    final success = await provider.addEpisode(
      showTitle: result.title,
      episodeTitle: result.channelTitle,
      youtubeId: result.videoId,
      youtubeUrl: youtubeUrl,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Added ${result.title} to the watchlist!")),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add episode. Please try again.")),
      );
    }
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.lightOnSurface, width: 3),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Episode Limit', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Text(
          'This week already has an episode. Replace it from the dashboard.',
          style: TextStyle(color: AppTheme.lightPrimaryText),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pop();
            },
            child: const Text('Go to Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final episodes = provider.episodes;
    final year = group?.currentYear ?? 1990;

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text("TV TIME MACHINE", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
            Text("THE ${year}s", style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: const [
          ThemeToggle(),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // AI Helper
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: AppTheme.lightPrimary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.lightOnSurface, width: 3),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.lightOnPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.lightOnSurface, width: 2),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.lightPrimary, size: 24),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Nostalgia Assistant",
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppTheme.lightOnPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Want to see the top sitcoms from $year?",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.lightOnPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _handleSuggest(year),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.lightAccent,
                        foregroundColor: AppTheme.lightOnSurface,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text("Suggest"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // Search
              Text("Search YouTube for an episode", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.lightOnSurface, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppTheme.spacingSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.lightOnSurface, width: 3),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppTheme.lightOnSurface),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: "Show name or episode title...",
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    GestureDetector(
                      onTap: _search,
                      child: const Icon(Icons.arrow_forward_rounded, color: AppTheme.lightOnSurface),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // Chips
              Wrap(
                spacing: AppTheme.spacingSm,
                runSpacing: AppTheme.spacingSm,
                children: [
                  _SuggestionChip(icon: Icons.theater_comedy_rounded, label: "Sitcoms", onTap: () => _handleChipTap("Sitcoms")),
                  _SuggestionChip(icon: Icons.travel_explore_rounded, label: "Sci-Fi", onTap: () => _handleChipTap("Sci-Fi")),
                  _SuggestionChip(icon: Icons.child_care_rounded, label: "Cartoons", onTap: () => _handleChipTap("Cartoons")),
                  _SuggestionChip(icon: Icons.menu_book_rounded, label: "Drama", onTap: () => _handleChipTap("Drama")),
                ],
              ),

              const SizedBox(height: AppTheme.spacingMd),
              const Divider(color: AppTheme.lightOnSurface, thickness: 2),
              const SizedBox(height: AppTheme.spacingMd),

              // Results
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text("Search Results", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.lightOnSurface)),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: AppTheme.spacingSm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isSearching)
                const Center(child: CircularProgressIndicator())
              else if (_results.isNotEmpty)
                ..._results.map((result) => _TVResultCard(
                  result: result,
                  onAdd: () => _addEpisode(result),
                  isDisabled: episodes.length >= 1,
                ))
              else
                 Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingXl),
                    child: Text(
                      "Search for TV shows from $year!",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.lightSecondaryText),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.lightOnSurface, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.lightPrimary),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.lightPrimaryText, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _TVResultCard extends StatelessWidget {
  final YouTubeSearchResult result;
  final VoidCallback onAdd;
  final bool isDisabled;

  const _TVResultCard({
    required this.result,
    required this.onAdd,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.lightOnSurface, width: 3),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(9),
              bottomLeft: Radius.circular(9),
            ),
            child: result.thumbnailUrl.isNotEmpty
                ? Image.network(
                    result.thumbnailUrl,
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 120,
                      height: 90,
                      color: AppTheme.lightSecondary,
                      child: const Icon(Icons.tv, color: AppTheme.lightOnPrimary, size: 40),
                    ),
                  )
                : Container(
                    width: 120,
                    height: 90,
                    color: AppTheme.lightSecondary,
                    child: const Icon(Icons.tv, color: AppTheme.lightOnPrimary, size: 40),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.lightPrimaryText,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 12, color: AppTheme.lightSecondaryText),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          result.channelTitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.lightSecondaryText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: isDisabled ? null : onAdd,
            icon: Icon(
              Icons.add_circle,
              color: isDisabled ? Colors.grey : AppTheme.lightPrimary,
              size: 32,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
        ],
      ),
    );
  }
}
