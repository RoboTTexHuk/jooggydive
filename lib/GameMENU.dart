import 'package:flutter/material.dart';

import 'howtoplaysreen.dart' show HowToPlayScreen;

class JooggyDiveHome extends StatelessWidget {
  const JooggyDiveHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Получим размеры экрана для правильного позиционирования
    return Scaffold(
      body: Stack(
        children: [
          // Фон
          Positioned.fill(
            child: Image.asset(
              'assets/bg2.png',
              fit: BoxFit.cover,
            ),
          ),
          // Рыбка

          // Логотип
          Align(
            alignment: const Alignment(0, -0.1),
            child: Image.asset(
              'assets/logo.png',
              width: 300,
            ),
          ),
          // Кнопка PLAY
          Align(
            alignment: const Alignment(0, 0.7),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => HowToPlayScreen()),
                );
              },
              child: Image.asset(
                'assets/play_button.png',
                width: 320,
              ),
            ),
          ),
        ],
      ),
    );
  }
}