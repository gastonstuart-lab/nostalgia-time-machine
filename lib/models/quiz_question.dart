class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explain;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explain = '',
  });

  Map<String, dynamic> toJson() => {
        'q': question,
        'choices': options,
        'answerIndex': correctIndex,
        'explain': explain,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions =
        (json['choices'] ?? json['options']) as List<dynamic>? ?? const [];
    return QuizQuestion(
      question: (json['q'] ?? json['question']) as String? ?? '',
      options: rawOptions.map((option) => option.toString()).toList(),
      correctIndex:
          ((json['answerIndex'] ?? json['correctIndex']) as num?)?.toInt() ?? 0,
      explain: json['explain'] as String? ?? '',
    );
  }
}
