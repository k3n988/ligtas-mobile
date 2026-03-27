import '../models/triage_level.dart';

/// Pure function — no side effects. Deterministically assigns a triage level
/// based on the household's vulnerability and structural damage profile.
TriageLevel assessTriage({
  required int medicalCount,
  required int elderlyCount,
  required int infantCount,
  required bool hasDisabled,
  required int damageLevel,
  required int memberCount,
}) {
  final int vulnerable = elderlyCount + infantCount + (hasDisabled ? 1 : 0);

  // ── CRITICAL ─────────────────────────────────────────────────────────────
  // Structure destroyed, multiple medical needs, or medical + major damage
  if (damageLevel == 3 ||
      medicalCount >= 3 ||
      (medicalCount >= 1 && damageLevel >= 2) ||
      (medicalCount >= 2 && vulnerable >= 1)) {
    return TriageLevel.critical;
  }

  // ── HIGH ─────────────────────────────────────────────────────────────────
  // Major structural damage, any medical need, many vulnerable, or disabled
  if (damageLevel == 2 ||
      medicalCount >= 1 ||
      vulnerable >= 3 ||
      (hasDisabled && damageLevel >= 1)) {
    return TriageLevel.high;
  }

  // ── ELEVATED ─────────────────────────────────────────────────────────────
  // Minor damage or presence of vulnerable members
  if (damageLevel == 1 || vulnerable >= 1) {
    return TriageLevel.elevated;
  }

  // ── STABLE ───────────────────────────────────────────────────────────────
  return TriageLevel.stable;
}
