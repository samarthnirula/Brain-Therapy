// lib/models/playlist.dart

class Playlist {
  final String title;
  final String description;
  final String mood;
  final String spotifyUrl;
  final String appleMusicUrl;

  Playlist({
    required this.title,
    required this.description,
    required this.mood,
    required this.spotifyUrl,
    required this.appleMusicUrl,
  });
}
