import 'package:flutter/material.dart';

enum BonusType {
  none,
  doubleLetter,
  tripleLetter,
  doubleWord,
  tripleWord,
  star,
}

// Nouvelle disposition 15x15 avec vos bonus
// Légende :
// • = none
// V = doubleLetter
// O = tripleLetter
// R = doubleWord
// P = tripleWord
// C = star (Étoile)
const List<List<BonusType>> bonusMap = [
  //    A  B  C  D  E  F  G  H  I  J  K  L  M  N  O
  [
    BonusType.star, // A1
    BonusType.none, // B1
    BonusType.doubleLetter, // C1
    BonusType.none, // D1
    BonusType.tripleLetter, // E1
    BonusType.none, // F1
    BonusType.none, // G1
    BonusType.none, // H1
    BonusType.none, // I1
    BonusType.none, // J1
    BonusType.tripleLetter, // K1
    BonusType.none, // L1
    BonusType.doubleLetter, // M1
    BonusType.none, // N1
    BonusType.star, // O1
  ],
  [
    BonusType.none, // A2
    BonusType.tripleWord, // B2
    BonusType.none, // C2
    BonusType.none, // D2
    BonusType.none, // E2
    BonusType.doubleLetter, // F2
    BonusType.none, // G2
    BonusType.none, // H2
    BonusType.none, // I2
    BonusType.doubleLetter, // J2
    BonusType.none, // K2
    BonusType.none, // L2
    BonusType.none, // M2
    BonusType.tripleWord, // N2
    BonusType.none, // O2
  ],
  [
    BonusType.doubleLetter, // A3
    BonusType.none, // B3
    BonusType.doubleWord, // C3
    BonusType.none, // D3
    BonusType.none, // E3
    BonusType.none, // F3
    BonusType.tripleLetter, // G3
    BonusType.none, // H3
    BonusType.tripleLetter, // I3
    BonusType.none, // J3
    BonusType.none, // K3
    BonusType.none, // L3
    BonusType.doubleWord, // M3
    BonusType.none, // N3
    BonusType.doubleLetter, // O3
  ],
  [
    BonusType.none, // A4
    BonusType.none, // B4
    BonusType.none, // C4
    BonusType.tripleWord, // D4
    BonusType.none, // E4
    BonusType.none, // F4
    BonusType.none, // G4
    BonusType.doubleLetter, // H4
    BonusType.none, // I4
    BonusType.none, // J4
    BonusType.none, // K4
    BonusType.tripleWord, // L4
    BonusType.none, // M4
    BonusType.none, // N4
    BonusType.none, // O4
  ],
  [
    BonusType.tripleLetter, // A5
    BonusType.none, // B5
    BonusType.none, // C5
    BonusType.none, // D5
    BonusType.doubleWord, // E5
    BonusType.none, // F5
    BonusType.none, // G5
    BonusType.none, // H5
    BonusType.none, // I5
    BonusType.none, // J5
    BonusType.doubleWord, // K5
    BonusType.none, // L5
    BonusType.none, // M5
    BonusType.none, // N5
    BonusType.tripleLetter, // O5
  ],
  [
    BonusType.none, // A6
    BonusType.doubleLetter, // B6
    BonusType.none, // C6
    BonusType.none, // D6
    BonusType.none, // E6
    BonusType.star, // F6
    BonusType.none, // G6
    BonusType.none, // H6
    BonusType.none, // I6
    BonusType.star, // J6
    BonusType.none, // K6
    BonusType.none, // L6
    BonusType.none, // M6
    BonusType.doubleLetter, // N6
    BonusType.none, // O6
  ],
  [
    BonusType.none, // A7
    BonusType.none, // B7
    BonusType.tripleLetter, // C7
    BonusType.none, // D7
    BonusType.none, // E7
    BonusType.none, // F7
    BonusType.tripleLetter, // G7
    BonusType.none, // H7
    BonusType.tripleLetter, // I7
    BonusType.none, // J7
    BonusType.none, // K7
    BonusType.none, // L7
    BonusType.tripleLetter, // M7
    BonusType.none, // N7
    BonusType.none, // O7
  ],
  [
    BonusType.none, // A8
    BonusType.none, // B8
    BonusType.none, // C8
    BonusType.doubleLetter, // D8
    BonusType.none, // E8
    BonusType.none, // F8
    BonusType.none, // G8
    BonusType.none, // H8
    BonusType.none, // I8
    BonusType.none, // J8
    BonusType.none, // K8
    BonusType.doubleLetter, // L8
    BonusType.none, // M8
    BonusType.none, // N8
    BonusType.none, // O8
  ],
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
  [
    BonusType.none, // A12
    BonusType.none, // B12
    BonusType.none, // C12
    BonusType.tripleWord, // D12
    BonusType.none, // E12
    BonusType.none, // F12
    BonusType.none, // G12
    BonusType.doubleLetter, // H12
    BonusType.none, // I12
    BonusType.none, // J12
    BonusType.none, // K12
    BonusType.tripleWord, // L12
    BonusType.none, // M12
    BonusType.none, // N12
    BonusType.none, // O12
  ],
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
  [
    BonusType.star, // A15
    BonusType.none, // B15
    BonusType.doubleLetter, // C15
    BonusType.none, // D15
    BonusType.tripleLetter, // E15
    BonusType.none, // F15
    BonusType.none, // G15
    BonusType.none, // H15
    BonusType.none, // I15
    BonusType.none, // J15
    BonusType.tripleLetter, // K15
    BonusType.none, // L15
    BonusType.doubleLetter, // M15
    BonusType.none, // N15
    BonusType.star, // O15
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

// Indique si le bonus est activé par une lettre (pour l'effet visuel)
bool isLetterBonus(BonusType bonus) {
  return bonus == BonusType.doubleLetter || bonus == BonusType.tripleLetter;
}

bool isWordBonus(BonusType bonus) {
  return bonus == BonusType.doubleWord || bonus == BonusType.tripleWord;
}
