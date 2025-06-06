// lib/screens/playlist_recommendation.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/playlist_service.dart';
import '../models/playlist.dart';

class PlaylistRecommendation extends StatefulWidget {
  const PlaylistRecommendation({super.key});

  @override
  State<PlaylistRecommendation> createState() => _PlaylistRecommendationState();
}

class _PlaylistRecommendationState extends State<PlaylistRecommendation> {
  bool _isLoading = false;

  String _buildAppleSearchUrl(String mood) {
    final query = Uri.encodeComponent('$mood playlist');
    return 'https://music.apple.com/us/search?term=$query';
  }

  String _buildSpotifySearchUrl(String mood) {
    final query = Uri.encodeComponent('$mood playlist');
    return 'https://open.spotify.com/search/$query';
  }

  Future<void> _openUrl(String url) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showErrorSnackBar('Could not open link');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to open link: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return FutureBuilder<List<Playlist>>(
      future: PlaylistService.generatePlaylists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingWidget();
        }

        if (snapshot.hasError) {
          return _ErrorWidget(
            message: 'Failed to load playlists: ${snapshot.error}',
            onRetry: () => setState(() {}),
          );
        }

        final playlists = snapshot.data;
        if (playlists == null || playlists.length < 3) {
          return _ErrorWidget(
            message: 'Not enough playlists available',
            onRetry: () => setState(() {}),
          );
        }

        return _PlaylistGrid(
          playlists: playlists,
          onAppleMusic: _buildAppleSearchUrl,
          onSpotify: _buildSpotifySearchUrl,
          onOpenUrl: _openUrl,
          isLoading: _isLoading,
          colorScheme: colorScheme,
        );
      },
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading playlists...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorWidget({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade400,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistGrid extends StatelessWidget {
  final List<Playlist> playlists;
  final String Function(String) onAppleMusic;
  final String Function(String) onSpotify;
  final Future<void> Function(String) onOpenUrl;
  final bool isLoading;
  final ColorScheme colorScheme;

  const _PlaylistGrid({
    required this.playlists,
    required this.onAppleMusic,
    required this.onSpotify,
    required this.onOpenUrl,
    required this.isLoading,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left column with two smaller cards
          Flexible(
            flex: 2,
            fit: FlexFit.tight,
            child: Column(
              children: [
                Expanded(
                  child: _PlaylistCard(
                    playlist: playlists[0],
                    icon: Icons.music_note,
                    onTap: () => onOpenUrl(onAppleMusic(playlists[0].mood)),
                    isLoading: isLoading,
                    colorScheme: colorScheme,
                    showPlayButton: false,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _PlaylistCard(
                    playlist: playlists[1],
                    icon: Icons.headphones,
                    onTap: () => onOpenUrl(onAppleMusic(playlists[1].mood)),
                    isLoading: isLoading,
                    colorScheme: colorScheme,
                    showPlayButton: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right column with platform selection
          Flexible(
            flex: 3,
            fit: FlexFit.tight,
            child: _PlatformSelectionCard(
              playlist: playlists[2],
              onAppleMusic: () => onOpenUrl(onAppleMusic(playlists[2].mood)),
              onSpotify: () => onOpenUrl(onSpotify(playlists[2].mood)),
              isLoading: isLoading,
              colorScheme: colorScheme,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;
  final ColorScheme colorScheme;
  final bool showPlayButton;

  const _PlaylistCard({
    required this.playlist,
    required this.icon,
    required this.onTap,
    required this.isLoading,
    required this.colorScheme,
    required this.showPlayButton,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(
                  icon,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      playlist.mood,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playlist.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showPlayButton) ...[
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.play_arrow,
                    color: colorScheme.onSecondary,
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformSelectionCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onAppleMusic;
  final VoidCallback onSpotify;
  final bool isLoading;
  final ColorScheme colorScheme;

  const _PlatformSelectionCard({
    required this.playlist,
    required this.onAppleMusic,
    required this.onSpotify,
    required this.isLoading,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              playlist.mood,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              playlist.description,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            const Text(
              "Choose your platform",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PlatformButton(
                  icon: Icons.apple,
                  label: 'Apple Music',
                  color: Colors.black87,
                  onTap: isLoading ? null : onAppleMusic,
                  colorScheme: colorScheme,
                ),
                _PlatformButton(
                  icon: Icons.music_note,
                  label: 'Spotify',
                  color: const Color(0xFF1DB954), // Spotify green
                  onTap: isLoading ? null : onSpotify,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final ColorScheme colorScheme;

  const _PlatformButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}