import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart';

class SentimentAnalysisService {
  static const _apiEndpoint = 'https://language.googleapis.com/v1/documents:analyzeSentiment';
  static ServiceAccountCredentials? _credentials;

  Future<void> _initializeCredentials() async {
    if (_credentials != null) return;

    try {
      // Load the service account key JSON file
      final jsonString = await rootBundle.loadString('assets/ashesi-engage-3b79286765a6.json');
      final jsonMap = json.decode(jsonString);
      
      _credentials = ServiceAccountCredentials.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Failed to load service account credentials: $e');
    }
  }

  Future<String> _getAccessToken() async {
    await _initializeCredentials();
    if (_credentials == null) {
      throw Exception('Credentials not initialized');
    }

    try {
      final client = await clientViaServiceAccount(
        _credentials!,
        ['https://www.googleapis.com/auth/cloud-language']
      );
      final accessToken = client.credentials.accessToken.data;
      client.close();
      return accessToken;
    } catch (e) {
      throw Exception('Failed to get access token: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeSentiment(String text) async {
    try {
      final accessToken = await _getAccessToken();
      
      final response = await http.post(
        Uri.parse(_apiEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'document': {
            'type': 'PLAIN_TEXT',
            'content': text,
          },
          'encodingType': 'UTF8',
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('API request failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to analyze sentiment: $e');
    }
  }

  static String interpretSentiment(double score, double magnitude) {
    String sentimentText;
    if (score >= 0.5) {
      sentimentText = 'Very Positive';
    } else if (score > 0.1) {
      sentimentText = 'Positive';
    } else if (score >= -0.1) {
      sentimentText = 'Neutral';
    } else if (score >= -0.5) {
      sentimentText = 'Negative';
    } else {
      sentimentText = 'Very Negative';
    }

    String intensityText;
    if (magnitude >= 2.0) {
      intensityText = 'Strong';
    } else if (magnitude >= 1.0) {
      intensityText = 'Moderate';
    } else {
      intensityText = 'Mild';
    }

    return '$sentimentText | $intensityText';
  }

  static String getSentimentDescription(double score, double magnitude) {
    return '''
Score ($score): Indicates the overall emotional leaning
• -1.0 to -0.5: Very Negative
• -0.5 to -0.1: Negative
• -0.1 to 0.1: Neutral
• 0.1 to 0.5: Positive
• 0.5 to 1.0: Very Positive

Magnitude ($magnitude): Measures emotional intensity
• 0.0 to 1.0: Mild emotion
• 1.0 to 2.0: Moderate emotion
• 2.0+: Strong emotion

Combined Interpretation: ${interpretSentiment(score, magnitude)}
''';
  }
} 