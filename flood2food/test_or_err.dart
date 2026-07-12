// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.post(
    Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer YOUR_OPENROUTER_API_KEY',
    },
    body: jsonEncode({
      'model': 'meta-llama/llama-3.3-70b-instruct:free',
      'messages': [{'role': 'user', 'content': 'hello'}],
    })
  );
  print(res.statusCode);
  print(res.body);
}

