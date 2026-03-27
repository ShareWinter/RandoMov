import 'package:random_movie/models/movie.dart';

class HistoryMonthKey {
  final int year;
  final int month;

  const HistoryMonthKey({
    required this.year,
    required this.month,
  });

  factory HistoryMonthKey.fromDate(DateTime date) {
    return HistoryMonthKey(year: date.year, month: date.month);
  }

  DateTime get firstDay => DateTime(year, month);

  DateTime get lastDay => DateTime(year, month + 1, 0, 23, 59, 59, 999);

  HistoryMonthKey previous() {
    final previousMonth = DateTime(year, month - 1);
    return HistoryMonthKey.fromDate(previousMonth);
  }

  HistoryMonthKey next() {
    final nextMonth = DateTime(year, month + 1);
    return HistoryMonthKey.fromDate(nextMonth);
  }

  @override
  bool operator ==(Object other) {
    return other is HistoryMonthKey &&
        other.year == year &&
        other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}

class HistoryDaySummary {
  final DateTime date;
  final List<Movie> movies;

  const HistoryDaySummary({
    required this.date,
    required this.movies,
  });

  bool get hasMovies => movies.isNotEmpty;

  int get count => movies.length;

  String get primaryPoster {
    for (final movie in movies) {
      if (movie.poster.isNotEmpty) {
        return movie.poster;
      }
    }
    return '';
  }
}

class HistoryMonthData {
  final HistoryMonthKey month;
  final Map<int, HistoryDaySummary> summariesByDay;

  const HistoryMonthData({
    required this.month,
    required this.summariesByDay,
  });

  bool get isEmpty => summariesByDay.isEmpty;

  HistoryDaySummary? summaryForDay(int day) => summariesByDay[day];
}
