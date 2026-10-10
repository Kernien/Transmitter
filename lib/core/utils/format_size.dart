/// Размер файла для показа пользователю: «512 Б», «12,4 КБ», «3,1 МБ».
String formatFileSize(int bytes) {
  const units = ['Б', 'КБ', 'МБ', 'ГБ'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 || value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1).replaceAll('.', ',');
  return '$text ${units[unit]}';
}
