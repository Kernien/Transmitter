import 'package:flutter/material.dart';

/// Каталог предустановленных значков и популярных эмодзи для досок.
class VaultIcon {
  const VaultIcon._();

  /// Предустановленные значки Material с понятными ключами.
  static const Map<String, IconData> catalog = {
    'lock': Icons.lock_outline,
    'folder': Icons.folder_open_outlined,
    'work': Icons.work_outline,
    'home': Icons.home_outlined,
    'photo': Icons.photo_camera_outlined,
    'video': Icons.movie_outlined,
    'music': Icons.music_note_outlined,
    'code': Icons.code,
    'terminal': Icons.terminal_outlined,
    'book': Icons.menu_book_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'flight': Icons.flight_outlined,
    'idea': Icons.lightbulb_outline,
    'game': Icons.sports_esports_outlined,
    'star': Icons.star_outline,
    'chat': Icons.chat_bubble_outline,
    'bolt': Icons.bolt_outlined,
    'heart': Icons.favorite_outline,
    'coffee': Icons.coffee_outlined,
    'wallet': Icons.account_balance_wallet_outlined,
    'cloud': Icons.cloud_outlined,
    'shield': Icons.shield_outlined,
    'key': Icons.vpn_key_outlined,
    'fitness': Icons.fitness_center_outlined,
    'car': Icons.directions_car_outlined,
  };

  /// Популярные эмодзи для быстрого выбора.
  static const List<String> popularEmojis = [
    '💼', '🏠', '📷', '🎬', '🎵', '💻',
    '📚', '🛒', '✈️', '💡', '🎮', '⭐',
    '💬', '⚡', '❤️', '☕', '💰', '🔐',
    '🚀', '📌', '🎯', '🍔', '🚗', '🔥',
  ];

  /// Отображает значок: иконку из каталога, эмодзи или стандартную иконку.
  static Widget buildWidget(
    String? icon, {
    required bool isEncrypted,
    required Color color,
    double size = 18,
  }) {
    if (icon != null && icon.isNotEmpty) {
      if (catalog.containsKey(icon)) {
        return Icon(catalog[icon], size: size, color: color);
      }
      // Значок является эмодзи или произвольным символом
      return Text(
        icon,
        style: TextStyle(
          fontSize: size,
          height: 1,
        ),
      );
    }
    // По умолчанию: замок для зашифрованных, папка для открытых
    return Icon(
      isEncrypted ? Icons.lock_outline : Icons.folder_open_outlined,
      size: size,
      color: color,
    );
  }
}
