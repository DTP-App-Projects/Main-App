String convertArabicToEnglish(String input) {
  final arabicToEnglishMap = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };

  return input.replaceAllMapped(RegExp(r'[٠-٩]'), (match) {
    return arabicToEnglishMap[match.group(0)] ?? match.group(0)!;
  });
}