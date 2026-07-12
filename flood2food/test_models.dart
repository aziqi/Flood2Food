// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('https://openrouter.ai/api/v1/models'));
  final body = jsonDecode(res.body);
  final models = body['data'] as List;
  
  for (var m in models) {
    if (m['id'].toString().contains(':free')) {
      print(m['id']);
    }
  }
}

