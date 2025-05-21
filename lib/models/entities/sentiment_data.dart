class SentimentData {
  final double score;
  final double magnitude;

  SentimentData({
    required this.score,
    required this.magnitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'magnitude': magnitude,
    };
  }

  factory SentimentData.fromMap(Map<String, dynamic> map) {
    return SentimentData(
      score: map['score']?.toDouble() ?? 0.0,
      magnitude: map['magnitude']?.toDouble() ?? 0.0,
    );
  }

  String get interpretation {
    String sentiment;
    if (score >= 0.5) {
      sentiment = 'Very Positive';
    } else if (score > 0.1) {
      sentiment = 'Positive';
    } else if (score >= -0.1) {
      sentiment = 'Neutral';
    } else if (score >= -0.5) {
      sentiment = 'Negative';
    } else {
      sentiment = 'Very Negative';
    }

    String intensity;
    if (magnitude >= 2.0) {
      intensity = 'Strong';
    } else if (magnitude >= 1.0) {
      intensity = 'Moderate';
    } else {
      intensity = 'Mild';
    }

    return '$intensity $sentiment';
  }
} 