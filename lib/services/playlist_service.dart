// lib/services/playlist_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dart_openai/dart_openai.dart';
import '../models/playlist.dart';
import 'openai.dart';

class PlaylistService {
  static final _firestore = FirebaseFirestore.instance;
  static bool _isInitialized = false;

  static Future<bool> _initializeOpenAI() async {
    if (_isInitialized) return true;

    final apiKey = await OpenAIStorage.getApiKey();
    if (apiKey == null || !apiKey.startsWith('sk-')) {
      debugPrint('[PlaylistService] ❌ Invalid or missing OpenAI API key');
      return false;
    }

    try {
      OpenAI.apiKey = apiKey;
      _isInitialized = true;
      debugPrint('[PlaylistService] ✅ OpenAI initialized');
      return true;
    } catch (e) {
      debugPrint('[PlaylistService] ❌ Initialization failed: $e');
      return false;
    }
  }

  static Future<List<Playlist>> generatePlaylists() async {
    debugPrint('[PlaylistService] ▶ Starting generatePlaylists');

    if (!await _initializeOpenAI()) return _getFallbackPlaylists();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _getFallbackPlaylists();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('survey_responses')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final responses = snapshot.docs.map((doc) {
        final q = (doc.data()['question'] ?? '').toString().trim();
        final a = (doc.data()['answer'] ?? '').toString().trim();
        return 'Q: $q\nA: $a';
      }).join('\n\n');

      final result = await OpenAI.instance.chat.create(
        model: 'gpt-3.5-turbo',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'You are a music therapist. Based on these responses, generate 3 playlist suggestions in JSON with the following fields: mood, title, description, spotifyUrl, appleMusicUrl. Respond ONLY with a JSON array.',
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(responses),
            ],
          ),
        ],
      );

      final reply = result.choices.first.message.content?.first.text ?? '';
      return _parsePlaylistsFromJSON(reply);
    } catch (e) {
      debugPrint('[PlaylistService] ❌ Chat completion error: $e');
      return _getFallbackPlaylists();
    }
  }

  static List<Playlist> _parsePlaylistsFromJSON(String raw) {
    try {
      final cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(cleaned);
      final jsonText = match?.group(0) ?? cleaned;
      final parsed = jsonDecode(jsonText);

      final playlists = (parsed as List).map((item) {
        final map = item as Map<String, dynamic>;
        return Playlist(
          mood: map['mood'] ?? 'Relax',
          title: map['title'] ?? 'Untitled',
          description: map['description'] ?? '',
          spotifyUrl: map['spotifyUrl'] ?? '',
          appleMusicUrl: map['appleMusicUrl'] ?? '',
        );
      }).toList();

      return playlists.take(3).toList();
    } catch (e) {
      debugPrint('[PlaylistService] ❌ JSON parse error: $e');
      return _getFallbackPlaylists();
    }
  }

  static List<Playlist> _getFallbackPlaylists() {
    return [
      Playlist(
        mood: 'Calm',
        title: 'Morning Calm',
        description: 'Soft acoustic songs to ease into the day.',
        spotifyUrl: '',
        appleMusicUrl: '',
      ),
      Playlist(
        mood: 'Focus',
        title: 'Focus Flow',
        description: 'Ambient and chill beats to help you concentrate.',
        spotifyUrl: '',
        appleMusicUrl: '',
      ),
      Playlist(
        mood: 'Happy',
        title: 'Uplifting Vibes',
        description: 'Feel-good pop and indie tracks to boost your mood.',
        spotifyUrl: '',
        appleMusicUrl: '',
      ),
    ];
  }
}
