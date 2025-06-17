import 'package:flutter/material.dart';
import 'Translations.dart';

enum Rank {
  learnerDriver(
    title: 'Learner Driver',
    color: Colors.grey,
  ),
  cityDriver(
    title: 'City Driver',
    color: Colors.green,
  ),
  highwayCruiser(
    title: 'Highway Cruiser',
    color: Colors.blueAccent,
  ),
  trackDayEnthusiast(
    title: 'Track Day Enthusiast',
    color: Colors.purple,
  ),
  pitCrewChief(
    title: 'Pit Crew Chief',
    color: Colors.yellow,
  );

  final String title;
  final Color color;

  const Rank({
    required this.title,
    required this.color,
  });

  static Rank fromString(String title) {
    final normalizedTitle = title.trim();
    switch (normalizedTitle) {
      case 'Learner Driver':
      case 'Újonc':
        return Rank.learnerDriver;
      case 'City Driver':
        return Rank.cityDriver;
      case 'Highway Cruiser':
        return Rank.highwayCruiser;
      case 'Track Day Enthusiast':
        return Rank.trackDayEnthusiast;
      case 'Pit Crew Chief':
        return Rank.pitCrewChief;
      default:
        debugPrint('Unknown rank: $normalizedTitle, falling back to learnerDriver');
        return Rank.learnerDriver;
    }
  }
}

Color getRankColor(String rankTitle, {String language = 'en'}) {
  final t = translations[language] ?? translations['en']!;
  String normalizedRank;

  final trimmedRank = rankTitle.trim();
  
  if (['Learner Driver', 'City Driver', 'Highway Cruiser', 'Track Day Enthusiast', 'Pit Crew Chief', 'Újonc'].contains(trimmedRank)) {
    normalizedRank = trimmedRank == 'Újonc' ? 'Learner Driver' : trimmedRank;
  } else {
    if (trimmedRank == t['rankLearnerDriver'] || trimmedRank == 'Újonc') {
      normalizedRank = 'Learner Driver';
    } else if (trimmedRank == t['rankCityDriver']) {
      normalizedRank = 'City Driver';
    } else if (trimmedRank == t['rankHighwayCruiser']) {
      normalizedRank = 'Highway Cruiser';
    } else if (trimmedRank == t['rankTrackDayEnthusiast']) {
      normalizedRank = 'Track Day Enthusiast';
    } else if (trimmedRank == t['rankPitCrewChief']) {
      normalizedRank = 'Pit Crew Chief';
    } else {
      debugPrint('Unknown localized rank: $trimmedRank, falling back to Learner Driver');
      normalizedRank = 'Learner Driver';
    }
  }

  final rank = Rank.fromString(normalizedRank);
  return rank.color;
}