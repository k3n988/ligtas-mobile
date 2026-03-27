import 'package:flutter/material.dart';

// ── Vulnerability enum ─────────────────────────────────────────────────────────

enum Vulnerability { bedridden, senior, wheelchair, infant, pregnant, pwd, oxygen, dialysis }

extension VulnerabilityX on Vulnerability {
  String get label {
    switch (this) {
      case Vulnerability.bedridden:  return 'Bedridden';
      case Vulnerability.senior:     return 'Senior Citizen';
      case Vulnerability.wheelchair: return 'Wheelchair';
      case Vulnerability.infant:     return 'Infant';
      case Vulnerability.pregnant:   return 'Pregnant';
      case Vulnerability.pwd:        return 'PWD';
      case Vulnerability.oxygen:     return 'Oxygen-dependent';
      case Vulnerability.dialysis:   return 'Dialysis';
    }
  }

  IconData get icon {
    switch (this) {
      case Vulnerability.bedridden:  return Icons.hotel;
      case Vulnerability.senior:     return Icons.elderly;
      case Vulnerability.wheelchair: return Icons.accessible;
      case Vulnerability.infant:     return Icons.child_care;
      case Vulnerability.pregnant:   return Icons.pregnant_woman;
      case Vulnerability.pwd:        return Icons.accessibility_new;
      case Vulnerability.oxygen:     return Icons.air;
      case Vulnerability.dialysis:   return Icons.water_drop;
    }
  }

  /// Which triage level this vulnerability triggers
  TriageLevel get triggersLevel {
    switch (this) {
      case Vulnerability.bedridden:
      case Vulnerability.oxygen:
      case Vulnerability.dialysis:
        return TriageLevel.critical;
      case Vulnerability.wheelchair:
      case Vulnerability.senior:
        return TriageLevel.high;
      case Vulnerability.pregnant:
      case Vulnerability.infant:
      case Vulnerability.pwd:
        return TriageLevel.elevated;
    }
  }
}

// ── Triage level ──────────────────────────────────────────────────────────────

enum TriageLevel { critical, high, elevated, stable }

extension TriageLevelX on TriageLevel {
  String get label {
    switch (this) {
      case TriageLevel.critical: return 'CRITICAL';
      case TriageLevel.high:     return 'HIGH';
      case TriageLevel.elevated: return 'ELEVATED';
      case TriageLevel.stable:   return 'STABLE';
    }
  }

  String get hex {
    switch (this) {
      case TriageLevel.critical: return '#ff4d4d';
      case TriageLevel.high:     return '#f39c12';
      case TriageLevel.elevated: return '#f1c40f';
      case TriageLevel.stable:   return '#58a6ff';
    }
  }

  Color get color {
    switch (this) {
      case TriageLevel.critical: return const Color(0xFFFF4D4D);
      case TriageLevel.high:     return const Color(0xFFF39C12);
      case TriageLevel.elevated: return const Color(0xFFF1C40F);
      case TriageLevel.stable:   return const Color(0xFF58A6FF);
    }
  }

  Color get lightColor {
    switch (this) {
      case TriageLevel.critical: return const Color(0xFFFFCDD2);
      case TriageLevel.high:     return const Color(0xFFFFE0B2);
      case TriageLevel.elevated: return const Color(0xFFFFF9C4);
      case TriageLevel.stable:   return const Color(0xFFBBDEFB);
    }
  }

  int get priority {
    switch (this) {
      case TriageLevel.critical: return 0;
      case TriageLevel.high:     return 1;
      case TriageLevel.elevated: return 2;
      case TriageLevel.stable:   return 3;
    }
  }
}
