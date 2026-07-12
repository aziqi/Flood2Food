// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'YOUR_NVIDIA_NIM_API_KEY';
  final url = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
  
  print('Requesting NVIDIA NIM API...');
  
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    },
    body: jsonEncode({
      'model': 'meta/llama-3.1-8b-instruct',
      'messages': [
        {'role': 'user', 'content': 'Halo, siapa kamu? Jawab dengan singkat.'}
      ],
      'temperature': 0.7,
      'max_tokens': 1024,
    }),
  );

  print('Status: ${response.statusCode}');
  print('Response body: ${response.body}');
}

