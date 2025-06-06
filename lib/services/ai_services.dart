import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _apiKey = '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';
  static const String _assistantId = 'asst_6CzPt0btLBGYhlyLC6X7EEPT';
  static const String _baseUrl = 'https://api.openai.com/v1';

  static Future<List<Map<String, String>>?> sendSurveyEntry({
    required String question,
    required String answer,
    required int index,
  }) async {
    try {
      print('🤖 AIService: Sending Q$index to Assistant...');
      final threadId = await _createThread();
      if (threadId == null) throw Exception('Failed to create thread');

      final messageAdded = await _addMessage(threadId, question, answer);
      if (!messageAdded) throw Exception('Failed to add message');

      final runId = await _runAssistant(threadId);
      if (runId == null) throw Exception('Failed to run assistant');

      final output = await _waitForRunCompletion(threadId, runId);
      if (output != null) {
        print('✅ AI Response for Q$index (raw):\n$output\n');
        final parsed = _parseDoses(output);
        if (parsed != null) {
          print('✅ AI Response for Q$index (parsed):\n$parsed\n');
          return parsed;
        }
      }
    } catch (e) {
      print('❌ AIService Error for Q$index: $e');
    }
    return null;
  }

  static Future<String?> _createThread() async {
    final res = await http.post(
      Uri.parse('$_baseUrl/threads'),
      headers: _headers(),
      body: jsonEncode({}), // ✅ Must be present even if empty
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['id'];
    } else {
      print('❌ Failed to create thread: ${res.statusCode} ${res.body}');
    }
    return null;
  }

  static Future<bool> _addMessage(String threadId, String question, String answer) async {
    final content = 'User was asked:\n"$question"\nThey answered:\n"$answer"\nGenerate 5 personalized daily mental health doses in JSON using the daily_dose_generator schema.';
    final res = await http.post(
      Uri.parse('$_baseUrl/threads/$threadId/messages'),
      headers: _headers(),
      body: jsonEncode({
        'role': 'user',
        'content': content,
      }),
    );
    if (res.statusCode != 200) {
      print('❌ Failed to add message: ${res.statusCode} ${res.body}');
    }
    return res.statusCode == 200;
  }

  static Future<String?> _runAssistant(String threadId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/threads/$threadId/runs'),
      headers: _headers(),
      body: jsonEncode({
        'assistant_id': _assistantId,
        'tools': [
          {
            'type': 'function',
            'function': {'name': 'daily_dose_generator'}
          }
        ]
      }),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['id'];
    } else {
      print('❌ Failed to run assistant: ${res.statusCode} ${res.body}');
    }
    return null;
  }

  static Future<String?> _waitForRunCompletion(String threadId, String runId) async {
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 2));
      print('⏳ Polling status... attempt ${i + 1}/30');
      final res = await http.get(
        Uri.parse('$_baseUrl/threads/$threadId/runs/$runId'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final status = data['status'];
        if (status == 'completed') {
          return _getMessages(threadId);
        } else if (status == 'failed' || status == 'cancelled') {
          throw Exception('Run failed or cancelled');
        }
      } else {
        print('❌ Error while polling run: ${res.statusCode} ${res.body}');
      }
    }
    throw Exception('Timeout waiting for run to complete');
  }

  static Future<String?> _getMessages(String threadId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/threads/$threadId/messages'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final messages = data['data'];
      if (messages != null && messages.isNotEmpty) {
        for (var msg in messages) {
          if (msg['role'] == 'assistant') {
            final contentList = msg['content'];
            for (var content in contentList) {
              if (content['type'] == 'function_call') {
                return content['function_call']['arguments'];
              } else if (content['type'] == 'text') {
                return content['text']['value'];
              }
            }
          }
        }
      }
    } else {
      print('❌ Failed to fetch messages: ${res.statusCode} ${res.body}');
    }
    return null;
  }

  static List<Map<String, String>>? _parseDoses(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      final List<dynamic> doses = decoded['doses'];
      return doses.map<Map<String, String>>((item) {
        return {
          'title': item['title'],
          'subtitle': item['subtitle'],
          'answer': item['answer'],
        };
      }).toList();
    } catch (e) {
      print('❌ Failed to parse doses: $e');
      return null;
    }
  }

  static Map<String, String> _headers() => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'OpenAI-Beta': 'assistants=v2', // ✅ REQUIRED FOR V2
      };
}
