import 'package:flutter/material.dart';

enum BonusType {
  none,
  doubleLetter,
  tripleLetter,
  doubleWord,
  tripleWord,
  star,
}

// Nouvelle disposition 15×15 avec vos bonus
// Légende :
// • = none
// V = doubleLetter
// O = tripleLetter
// R = doubleWord
// P = tripleWord
// C = star (Étoile)
const List<List<BonusType>> bonusMap = [
  // Ligne 1 (complète)
  [
    BonusType.doubleWord, // A1 (R)
    BonusType.none, // B1
    BonusType.doubleLetter, // C1 (V)
    BonusType.none, // D1
    BonusType.tripleLetter, // E1 (O)
    BonusType.none, // F1
    BonusType.none, // G1
    BonusType.tripleWord, // H1 (P)
    BonusType.none, // I1 = G1
    BonusType.none, // J1 = F1
    BonusType.tripleLetter, // K1 = E1
    BonusType.none, // L1 = D1
    BonusType.doubleLetter, // M1 = C1
    BonusType.none, // N1 = B1
    BonusType.doubleWord, // O1 = A1
  ],
  // Ligne 2
  [
    BonusType.none, // A2
    BonusType.tripleWord, // B2 (P)
    BonusType.none, // C2
    BonusType.none, // D2
    BonusType.none, // E2
    BonusType.doubleLetter, // F2 (V)
    BonusType.none, // G2
    BonusType.none, // H2
    BonusType.none, // I2 = G2
    BonusType.doubleLetter, // J2 = F2
    BonusType.none, // K2 = E2
    BonusType.none, // L2 = D2
    BonusType.none, // M2 = C2
    BonusType.tripleWord, // N2 = B2
    BonusType.none, // O2 = A2
  ],
  // Ligne 3
  [
    BonusType.doubleLetter, // A3 (V)
    BonusType.none, // B3
    BonusType.doubleWord, // C3 (R)
    BonusType.none, // D3
    BonusType.none, // E3
    BonusType.none, // F3
    BonusType.tripleLetter, // G3 (O)
    BonusType.none, // H3
    BonusType.tripleLetter, // I3 = G3
    BonusType.none, // J3 = F3
    BonusType.none, // K3 = E3
    BonusType.none, // L3 = D3
    BonusType.doubleWord, // M3 = C3
    BonusType.none, // N3 = B3
    BonusType.doubleLetter, // O3 = A3
  ],
  // Ligne 4
  [
    BonusType.none, // A4
    BonusType.none, // B4
    BonusType.none, // C4
    BonusType.tripleWord, // D4 (P)
    BonusType.none, // E4
    BonusType.none, // F4
    BonusType.none, // G4
    BonusType.star, // H4 (C)
    BonusType.none, // I4 = G4
    BonusType.none, // J4 = F4
    BonusType.none, // K4 = E4
    BonusType.tripleWord, // L4 = D4
    BonusType.none, // M4 = C4
    BonusType.none, // N4 = B4
    BonusType.none, // O4 = A4
  ],
  // Ligne 5
  [
    BonusType.tripleLetter, // A5 (O)
    BonusType.none, // B5
    BonusType.none, // C5
    BonusType.none, // D5
    BonusType.doubleWord, // E5 (R)
    BonusType.none, // F5
    BonusType.none, // G5
    BonusType.none, // H5
    BonusType.none, // I5 = G5
    BonusType.none, // J5 = F5
    BonusType.doubleWord, // K5 = E5
    BonusType.none, // L5 = D5
    BonusType.none, // M5 = C5
    BonusType.none, // N5 = B5
    BonusType.tripleLetter, // O5 = A5
  ],
  // Ligne 6
  [
    BonusType.none, // A6
    BonusType.doubleLetter, // B6 (V)
    BonusType.none, // C6
    BonusType.none, // D6
    BonusType.none, // E6
    BonusType.star, // F6 (C)
    BonusType.none, // G6
    BonusType.none, // H6
    BonusType.none, // I6 = G6
    BonusType.star, // J6 = F6
    BonusType.none, // K6 = E6
    BonusType.none, // L6 = D6
    BonusType.none, // M6 = C6
    BonusType.doubleLetter, // N6 = B6
    BonusType.none, // O6 = A6
  ],
  // Ligne 7
  [
    BonusType.none, // A7
    BonusType.none, // B7
    BonusType.tripleLetter, // C7 (O)
    BonusType.none, // D7
    BonusType.none, // E7
    BonusType.none, // F7
    BonusType.tripleLetter, // G7 (O)
    BonusType.none, // H7
    BonusType.tripleLetter, // I7 = G7
    BonusType.none, // J7 = F7
    BonusType.none, // K7 = E7
    BonusType.none, // L7 = D7
    BonusType.tripleLetter, // M7 = C7
    BonusType.none, // N7 = B7
    BonusType.none, // O7 = A7
  ],
  // Ligne 8 (axe horizontal)
  [
    BonusType.tripleWord, // A8 (P)
    BonusType.none, // B8
    BonusType.none, // C8
    BonusType.star, // D8 (C)
    BonusType.none, // E8
    BonusType.none, // F8
    BonusType.none, // G8
    BonusType.doubleWord, // H8 (R)
    BonusType.none, // I8 = G8
    BonusType.none, // J8 = F8
    BonusType.none, // K8 = E8
    BonusType.star, // L8 = D8
    BonusType.none, // M8 = C8
    BonusType.none, // N8 = B8
    BonusType.tripleWord, // O8 = A8
  ],
  // Ligne 9 = miroir de la ligne 7
  [
    BonusType.none, // A9
    BonusType.none, // B9
    BonusType.tripleLetter, // C9
    BonusType.none, // D9
    BonusType.none, // E9
    BonusType.none, // F9
    BonusType.tripleLetter, // G9
    BonusType.none, // H9
    BonusType.tripleLetter, // I9
    BonusType.none, // J9
    BonusType.none, // K9
    BonusType.none, // L9
    BonusType.tripleLetter, // M9
    BonusType.none, // N9
    BonusType.none, // O9
  ],
  // Ligne 10 = miroir de la ligne 6
  [
    BonusType.none, // A10
    BonusType.doubleLetter, // B10
    BonusType.none, // C10
    BonusType.none, // D10
    BonusType.none, // E10
    BonusType.star, // F10
    BonusType.none, // G10
    BonusType.none, // H10
    BonusType.none, // I10
    BonusType.star, // J10
    BonusType.none, // K10
    BonusType.none, // L10
    BonusType.none, // M10
    BonusType.doubleLetter, // N10
    BonusType.none, // O10
  ],
  // Ligne 11 = miroir de la ligne 5
  [
    BonusType.tripleLetter, // A11
    BonusType.none, // B11
    BonusType.none, // C11
    BonusType.none, // D11
    BonusType.doubleWord, // E11
    BonusType.none, // F11
    BonusType.none, // G11
    BonusType.none, // H11
    BonusType.none, // I11
    BonusType.none, // J11
    BonusType.doubleWord, // K11
    BonusType.none, // L11
    BonusType.none, // M11
    BonusType.none, // N11
    BonusType.tripleLetter, // O11
  ],
  // Ligne 12 = miroir de la ligne 4
  [
    BonusType.none, // A12
    BonusType.none, // B12
    BonusType.none, // C12
    BonusType.tripleWord, // D12
    BonusType.none, // E12
    BonusType.none, // F12
    BonusType.none, // G12
    BonusType.star, // H12 (C)
    BonusType.none, // I12
    BonusType.none, // J12
    BonusType.none, // K12
    BonusType.tripleWord, // L12
    BonusType.none, // M12
    BonusType.none, // N12
    BonusType.none, // O12
  ],
  // Ligne 13 = miroir de la ligne 3
  [
    BonusType.doubleLetter, // A13
    BonusType.none, // B13
    BonusType.doubleWord, // C13
    BonusType.none, // D13
    BonusType.none, // E13
    BonusType.none, // F13
    BonusType.tripleLetter, // G13
    BonusType.none, // H13
    BonusType.tripleLetter, // I13
    BonusType.none, // J13
    BonusType.none, // K13
    BonusType.none, // L13
    BonusType.doubleWord, // M13
    BonusType.none, // N13
    BonusType.doubleLetter, // O13
  ],
  // Ligne 14 = miroir de la ligne 2
  [
    BonusType.none, // A14
    BonusType.tripleWord, // B14
    BonusType.none, // C14
    BonusType.none, // D14
    BonusType.none, // E14
    BonusType.doubleLetter, // F14
    BonusType.none, // G14
    BonusType.none, // H14
    BonusType.none, // I14
    BonusType.doubleLetter, // J14
    BonusType.none, // K14
    BonusType.none, // L14
    BonusType.none, // M14
    BonusType.tripleWord, // N14
    BonusType.none, // O14
  ],
  // Ligne 15 = miroir de la ligne 1
  [
    BonusType.doubleWord, // A15
    BonusType.none, // B15
    BonusType.doubleLetter, // C15
    BonusType.none, // D15
    BonusType.tripleLetter, // E15
    BonusType.none, // F15
    BonusType.none, // G15
    BonusType.tripleWord, // H15
    BonusType.none, // I15
    BonusType.none, // J15
    BonusType.tripleLetter, // K15
    BonusType.none, // L15
    BonusType.doubleLetter, // M15
    BonusType.none, // N15
    BonusType.doubleWord, // O15
  ],
];

Color getColorForBonus(BonusType bonus) {
  switch (bonus) {
    case BonusType.doubleLetter:
      return const Color(0xFF2ECC71); // Vert émeraude
    case BonusType.tripleLetter:
      return const Color(0xFFF1C40F); // Or
    case BonusType.doubleWord:
      return const Color(0xFFE74C3C); // Rouge rubis
    case BonusType.tripleWord:
      return const Color(0xFF9B59B6); // Violet royal
    case BonusType.star:
      return const Color(0xFF00D2FF); // Bleu cyan
    case BonusType.none:
      return const Color(0xFFD4A574); // Bois clair veiné
  }
}

String bonusLabel(BonusType bonus) {
  switch (bonus) {
    case BonusType.doubleLetter:
      return "L2";
    case BonusType.tripleLetter:
      return "L3";
    case BonusType.doubleWord:
      return "M2";
    case BonusType.tripleWord:
      return "M3";
    case BonusType.star:
      return "★";
    default:
      return "";
  }
}

bool isLetterBonus(BonusType bonus) {
  return bonus == BonusType.doubleLetter || bonus == BonusType.tripleLetter;
}

bool isWordBonus(BonusType bonus) {
  return bonus == BonusType.doubleWord || bonus == BonusType.tripleWord;
}
