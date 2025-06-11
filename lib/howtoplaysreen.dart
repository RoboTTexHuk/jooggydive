import 'package:flutter/material.dart';

import 'Game.dart' show FishGameScreen;
import 'LVL.dart' show LevelSelectScreen;

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Фоновое изображение
          Positioned.fill(
            child: Image.asset(
              'assets/bg2.png',
              fit: BoxFit.cover,
            ),
          ),
          // Основная карточка с правилами
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xB01BB6E3), // Прозрачный синий
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.lightBlueAccent,
                  width: 4,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // HOW TO PLAY
                  Text(
                    'HOW TO PLAY',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Colors.yellow[300],
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Collect coins
                  Text(
                    'Collect coins for points',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.yellow[200],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Image.asset(
                    'assets/coin.png',
                    height: 48,
                  ),
                  const SizedBox(height: 20),
                  // Collect bubbles
                  Text(
                    'Collect bubbles for air',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.yellow[200],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Image.asset(
                    'assets/bubble.png',
                    height: 48,
                  ),
                  const SizedBox(height: 20),
                  // Avoid creatures
                  Text(
                    'Avoid these creatures',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.yellow[200],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Существа в две строки
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/jellyfish.png', height: 54),
                      const SizedBox(width: 16),
                      Image.asset('assets/starfish.png', height: 54),
                      const SizedBox(width: 16),
                      Image.asset('assets/pufferfish.png', height: 54),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Image.asset('assets/shark.png', height: 54),
                  const SizedBox(height: 30),
                  // Кнопка PLAY
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => LevelSelectScreen()),
                      );
                    },
                    child: Image.asset(
                      'assets/play_button.png',
                      height: 70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}