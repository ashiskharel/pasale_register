import 'dart:math';

import '../models/vendor.dart';

/// Calculates the Levenshtein distance between two strings.
int levenshteinDistance(String s, String t) {
  if (s == t) return 0;
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;

  final v0 = List<int>.filled(t.length + 1, 0);
  final v1 = List<int>.filled(t.length + 1, 0);

  for (var i = 0; i < t.length + 1; i++) {
    v0[i] = i;
  }

  for (var i = 0; i < s.length; i++) {
    v1[0] = i + 1;

    for (var j = 0; j < t.length; j++) {
      final cost = (s[i] == t[j]) ? 0 : 1;
      v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
    }

    for (var j = 0; j < t.length + 1; j++) {
      v0[j] = v1[j];
    }
  }

  return v1[t.length];
}

/// Calculates a similarity score between 0.0 and 1.0.
/// 1.0 means exact match.
double calculateSimilarity(String s1, String s2) {
  if (s1.isEmpty && s2.isEmpty) return 1.0;
  if (s1.isEmpty || s2.isEmpty) return 0.0;
  
  final s1Lower = s1.toLowerCase().trim();
  final s2Lower = s2.toLowerCase().trim();
  
  if (s1Lower == s2Lower) return 1.0;

  final distance = levenshteinDistance(s1Lower, s2Lower);
  final maxLength = max(s1Lower.length, s2Lower.length);

  return 1.0 - (distance / maxLength);
}

/// Finds the best matching vendor for a given OCR string.
/// Returns null if no vendor meets the threshold.
Vendor? findBestVendorMatch(String ocrText, List<Vendor> vendors, {double threshold = 0.6}) {
  if (ocrText.isEmpty || vendors.isEmpty) return null;

  Vendor? bestMatch;
  double highestScore = 0.0;

  // Exact substring check first (highly confident if OCR is a subset of Vendor name or vice versa)
  final ocrLower = ocrText.toLowerCase().trim();
  for (final vendor in vendors) {
    final vLower = vendor.name.toLowerCase().trim();
    if (vLower == ocrLower || vLower.contains(ocrLower) || ocrLower.contains(vLower)) {
       // If one contains the other, give it a high baseline score depending on length diff
       final score = 0.8 + (0.2 * (min(vLower.length, ocrLower.length) / max(vLower.length, ocrLower.length)));
       if (score > highestScore) {
         highestScore = score;
         bestMatch = vendor;
       }
    }
  }
  
  if (highestScore >= 0.9) return bestMatch; // Skip levenshtein if we found an excellent substring match

  // Fuzzy match fallback
  for (final vendor in vendors) {
    final score = calculateSimilarity(ocrText, vendor.name);
    if (score > highestScore) {
      highestScore = score;
      bestMatch = vendor;
    }
  }

  if (highestScore >= threshold) {
    return bestMatch;
  }

  return null;
}
