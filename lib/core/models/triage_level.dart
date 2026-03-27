enum TriageLevel { critical, high, elevated, stable }

extension TriageLevelX on TriageLevel {
  String get label {
    switch (this) {
      case TriageLevel.critical:
        return 'CRITICAL';
      case TriageLevel.high:
        return 'HIGH';
      case TriageLevel.elevated:
        return 'ELEVATED';
      case TriageLevel.stable:
        return 'STABLE';
    }
  }

  int get priority {
    switch (this) {
      case TriageLevel.critical:
        return 0;
      case TriageLevel.high:
        return 1;
      case TriageLevel.elevated:
        return 2;
      case TriageLevel.stable:
        return 3;
    }
  }
}
