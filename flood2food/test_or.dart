// ignore_for_file: avoid_print
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
  print('Requesting $url');
  
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer YOUR_OPENROUTER_API_KEY',
    },
    body: jsonEncode({
      'model': 'meta-llama/llama-3.1-8b-instruct:free',
      'messages': [{'role': 'user', 'content': 'hello'}],
      'temperature': 0.7,
    }),
  );

  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
}

