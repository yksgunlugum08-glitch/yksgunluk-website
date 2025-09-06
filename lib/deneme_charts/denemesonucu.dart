class DenemeSonucu {
  final String date;
  final double score;
  final Map<String, dynamic>? netler;

  DenemeSonucu({
    required this.date,
    required this.score,
    this.netler,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'score': score,
        if (netler != null) 'netler': netler,
      };

  factory DenemeSonucu.fromJson(Map<String, dynamic> json) {
    double parsedScore = 0.0;
    if (json['score'] != null) {
      parsedScore = (json['score'] as num).toDouble();
    } else if (json['netler'] != null && json['netler'] is Map) {
      // Eğer sadece netler varsa, toplamlarını score olarak al
      parsedScore = (json['netler'] as Map)
          .values
          .fold<double>(0.0, (a, b) => a + (b is num ? b.toDouble() : double.tryParse(b.toString()) ?? 0.0));
    }
    return DenemeSonucu(
      date: json['date'],
      score: parsedScore,
      netler: json['netler'] != null ? Map<String, dynamic>.from(json['netler']) : null,
    );
  }
}