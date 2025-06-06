import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:therapy_ai/Launch Sign In/page1.dart';
import 'services/openai.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env variables
  await dotenv.load(fileName: ".env");

  // Clear any old credential∏s first
  await OpenAIStorage.clearCredentials();

  // Get credentials from .env and store in SharedPreferences
  final apiKey = dotenv.env['OPENAI_API_KEY'];
  
  final assistantId = dotenv.env['OPENAI_ASSISTANT_ID'];

  print('[Main] API Key from .env: ${apiKey?.substring(0, 20)}...');

  if (apiKey != null && apiKey.startsWith('sk-proj-') && apiKey.length > 50) {
    await OpenAIStorage.saveCredentials(
      apiKey: apiKey,
      assistantId: assistantId ?? '',
    );
    print('[Main] ✅ Credentials saved to SharedPreferences');
  } else {
    print('[Main] ❌ Invalid API key format');
  }

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Therapy AI',
      home: Page1(),
      debugShowCheckedModeBanner: false,
    );
  }
}