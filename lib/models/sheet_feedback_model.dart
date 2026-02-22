class SheetFeedbackModel {
  final String category;
  final int rating;
  final String title;
  final String description;

  SheetFeedbackModel({
    required this.category,
    required this.rating,
    required this.title,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'rating': rating,
      'title': title,
      'description': description,
    };
  }
}
