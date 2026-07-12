// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'YOUR_GEMINI_API_KEY';
  final model = 'gemini-2.5-flash';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
  
  print('Requesting Gemini API ($model)...');
  
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Halo, siapa kamu? Jawab dengan singkat.'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
      }
    }),
  );

  print('Status: ${response.statusCode}');
  print('Response body: ${response.body}');
}

