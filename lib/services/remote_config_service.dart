import 'dart:convert';
import 'package:dio/dio.dart';

class RemoteConfigService {
  final String gistRawUrl = 'https://gist.githubusercontent.com/sohailcollege2032008-tech/fc40c7c5779304c071d8d4f0371e2cd4/raw';

  Future<String> fetchActiveBaseUrl() async {
    try {
      final dio = Dio();
      final response = await dio.get(gistRawUrl);
      if (response.statusCode == 200) {
        if (response.data is String) {
           final data = jsonDecode(response.data);
           return data['active_base_url'];
        }
        return response.data['active_base_url'];
      }
      return 'https://pub-88e20fcf77474141905d65991b1e1b51.r2.dev'; // fallback
    } catch (e) {
      return 'https://pub-88e20fcf77474141905d65991b1e1b51.r2.dev'; // fallback
    }
  }
}
