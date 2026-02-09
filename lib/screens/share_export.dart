import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../state.dart';
import '../models/song.dart';
import '../models/episode.dart';

class ShareExportScreen extends StatelessWidget {
  const ShareExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final songs = List<Song>.from(provider.songs);
    final episodes = List<Episode>.from(provider.episodes);

    if (group == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final topSong = songs.isNotEmpty ? songs.first : null;

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.lightOnSurface),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text("SHARE THE VIBE", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.lightPrimary, fontWeight: FontWeight.w800)),
            Text("Year ${group.currentYear} Recap", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.lightPrimaryText, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Card
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.lightBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: AppTheme.lightOnSurface, width: 3),
                  boxShadow: AppTheme.shadowMd,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Mock Halftone pattern background
                    Container(
                      height: 380,
                      color: AppTheme.lightSurface, // Placeholder
                      child: Stack(
                        children: [
                           Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingLg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("REWIND COLLECTIVE", style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.lightOnSurface)),
                                    Text("WK. 05", style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.lightOnSurface)),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                if (topSong != null)
                                  Container(
                                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                                    decoration: BoxDecoration(
                                      color: AppTheme.lightAccent,
                                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                      border: Border.all(color: AppTheme.lightOnSurface, width: 2),
                                    ),
                                    child: Column(
                                      children: [
                                        Text("SONG OF THE WEEK", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.lightOnSurface)),
                                        Text(topSong.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.lightOnPrimary), textAlign: TextAlign.center),
                                        Text("${topSong.artist} • Added by ${topSong.addedByName}", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.lightOnSurface)),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: AppTheme.spacingMd),
                                Container(
                                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                    border: Border.all(color: AppTheme.lightOnSurface, width: 2),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("THE ${group.currentYear} VIBE CHECK", style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.lightSecondary)),
                                      Text(
                                        "A week dominated by grunge and the birth of Britpop. Your group leaned heavy into the Seattle sound, with a surprise TV pivot to the 'Friends' pilot. Pure nostalgia fuel.",
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.lightOnSurface, height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingMd),
                                ...songs.take(3).map((s) => _SummaryItem(
                                  label: "${s.title} - ${s.artist}", 
                                  meta: s.addedByName, 
                                  dotColor: AppTheme.lightPrimary
                                )),
                                if (episodes.isNotEmpty)
                                  _SummaryItem(
                                    label: "${episodes.first.showTitle} (${episodes.first.episodeTitle})",
                                    meta: "TV PICK",
                                    dotColor: AppTheme.lightOnSurface,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              Text("Export Playlist", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.lightOnSurface)),
              const SizedBox(height: AppTheme.spacingMd),
              
              _ExportCard(
                title: "Spotify",
                subtitle: "Save ${group.currentYear} to your library",
                icon: Icons.library_music,
                iconBg: const Color(0xFF1DB954),
                iconColor: Colors.white,
              ),
              _ExportCard(
                title: "YouTube",
                subtitle: "Generate a video playlist",
                icon: Icons.play_circle_filled,
                iconBg: const Color(0xFFFF0000),
                iconColor: Colors.white,
              ),

              const SizedBox(height: AppTheme.spacingXl),

              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded),
                label: const Text("Download Image"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.lightSecondary,
                  foregroundColor: AppTheme.lightOnPrimary,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text("Share to Instagram"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.lightOnSurface,
                  side: const BorderSide(color: AppTheme.lightOnSurface, width: 2),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String meta;
  final Color dotColor;

  const _SummaryItem({
    required this.label,
    required this.meta,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.lightPrimaryText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(meta, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.lightSecondaryText)),
        ],
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _ExportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.lightOnSurface, width: 3),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.lightOnSurface, width: 2),
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.lightPrimaryText)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.lightSecondaryText)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.lightSecondaryText),
        ],
      ),
    );
  }
}
