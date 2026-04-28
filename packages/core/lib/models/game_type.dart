enum GameType {
  fichePerso,
  map,
  vraiFaux,
  friseChronologique,
  devineVerset,
  redactionBible;

  String get label {
    switch (this) {
      case fichePerso:
        return 'Fiche Personnage';
      case map:
        return 'Carte Biblique';
      case vraiFaux:
        return 'Vrai ou Faux';
      case friseChronologique:
        return 'Frise Chronologique';
      case devineVerset:
        return 'Divine ton Verset';
      case redactionBible:
        return 'Rédaction de la Bible';
    }
  }

  String get emoji {
    switch (this) {
      case fichePerso:
        return '👤';
      case map:
        return '🗺️';
      case vraiFaux:
        return '✅';
      case friseChronologique:
        return '📅';
      case devineVerset:
        return '📖';
      case redactionBible:
        return '✍️';
    }
  }

  String toJson() => name;

  static GameType fromJson(String value) =>
      GameType.values.firstWhere((e) => e.name == value);
}