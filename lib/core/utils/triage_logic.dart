import '../models/triage_level.dart';

/// Pure function — no side effects.
/// Derives triage level from the household's vulnerability list.
///
/// CRITICAL  : Bedridden | Oxygen | Dialysis
/// HIGH      : Wheelchair | Senior
/// ELEVATED  : Pregnant | Infant | PWD
/// STABLE    : (none of the above)
TriageLevel assessTriage(List<Vulnerability> vulnerabilities) {
  if (vulnerabilities.isEmpty) return TriageLevel.stable;

  const criticalSet = {
    Vulnerability.bedridden,
    Vulnerability.oxygen,
    Vulnerability.dialysis,
  };
  const highSet = {
    Vulnerability.wheelchair,
    Vulnerability.senior,
  };
  const elevatedSet = {
    Vulnerability.pregnant,
    Vulnerability.infant,
    Vulnerability.pwd,
  };

  if (vulnerabilities.any(criticalSet.contains)) return TriageLevel.critical;
  if (vulnerabilities.any(highSet.contains))     return TriageLevel.high;
  if (vulnerabilities.any(elevatedSet.contains)) return TriageLevel.elevated;
  return TriageLevel.stable;
}
