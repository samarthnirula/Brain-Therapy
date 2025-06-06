// lib/widgets/gradient_playlist_section.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/playlist.dart';
import '../services/playlist_service.dart';

class GradientPlaylistSection extends StatefulWidget {
  const GradientPlaylistSection({super.key});

  @override
  State<GradientPlaylistSection> createState() => _GradientPlaylistSectionState();
}

class _GradientPlaylistSectionState extends State<GradientPlaylistSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late Future<List<Playlist>> _playlistsFuture;
  List<Playlist>? _displayPlaylists;

  @override
  void initState() {
    super.initState();
    // Begin loading playlists
    _playlistsFuture = PlaylistService.generatePlaylists();

    // Animation controller for looping horizontal gradient
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Select six unique playlists (never repeat within this session)
  void _selectSixUnique(List<Playlist> all) {
    if (_displayPlaylists != null || all.isEmpty) return;
    final rnd = Random();
    final temp = List<Playlist>.from(all);
    temp.shuffle(rnd);
    _displayPlaylists = temp.length <= 6 ? temp : temp.sublist(0, 6);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final alignmentX = _animation.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(alignmentX, 0),
                end: Alignment(alignmentX - 2, 0),
                colors: const [
                  Color(0xFFD1C4E9), // Light purple
                  Color(0xFFB39DDB), // Medium purple
                  Color(0xFF9575CD), // Darker purple
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: FutureBuilder<List<Playlist>>(
              future: _playlistsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load playlists\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _playlistsFuture = PlaylistService.generatePlaylists();
                              _displayPlaylists = null;
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final all = snapshot.data ?? [];
                _selectSixUnique(all);
                final list = _displayPlaylists!;

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final pl = list[index];
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First line: Mood (instead of title)
                          Text(
                            pl.mood,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Second line: Description
                          Text(
                            pl.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          // Row of icons linking to Spotify & Apple Music
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _launchUrl(pl.spotifyUrl),
                                child: Row(
                                  children: const [
                                    Icon(Icons.music_note, color: Colors.green, size: 28),
                                    SizedBox(width: 4),
                                    Text(
                                      'Spotify',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              GestureDetector(
                                onTap: () => _launchUrl(pl.appleMusicUrl),
                                child: Row(
                                  children: const [
                                    Icon(Icons.apple, color: Colors.black, size: 28),
                                    SizedBox(width: 4),
                                    Text(
                                      'Apple Music',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
