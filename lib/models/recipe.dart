class Recipe {
  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final String cookingTime;

  Recipe({
    required this.title,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.cookingTime,
  });

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      title: map['title'] as String? ?? 'Untitled Recipe',
      description: map['description'] as String? ?? '',
      ingredients: List<String>.from(map['ingredients'] ?? []),
      instructions: List<String>.from(map['instructions'] ?? []),
      cookingTime: map['cooking_time'] as String? ?? 'Unknown',
    );
  }
}
