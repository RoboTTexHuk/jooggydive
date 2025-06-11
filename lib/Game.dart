import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'LVL.dart' show LevelSelectScreen;

// ---------------------
// МОДЕЛИ
// ---------------------
class _Coral {
  final double x;
  final double y;
  final String asset;
  _Coral(this.x, this.y, this.asset);
}

class _Danger {
  final double x;
  final double y;
  final String asset;
  _Danger(this.x, this.y, this.asset);
}

// ---------------------
// SHARED PREFERENCES HELPERS
// ---------------------
Future<int> getMaxOpenedLevel() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('maxOpenedLevel') ?? 1;
}

Future<void> setMaxOpenedLevel(int lvl) async {
  final prefs = await SharedPreferences.getInstance();
  print('[SAVE] maxOpenedLevel = $lvl'); // <-- Выводим в лог
  await prefs.setInt('maxOpenedLevel', lvl);
}

// ---------------------
// ИГРОВОЙ ЭКРАН
// ---------------------
class FishGameScreen extends StatefulWidget {
  final int lvl;
  const FishGameScreen({super.key, required this.lvl});

  @override
  State<FishGameScreen> createState() => _FishGameScreenState();
}

class _FishGameScreenState extends State<FishGameScreen> {
  static const double fishSize = 80;
  static const double coralSize = 80;
  static const double coinSize = 48;
  static const double dangerSize = 80;

  double fishX = 0.0;
  double fishY = -0.2;
  int score = 0;
  bool gameOver = false;
  bool paused = false;
  int lvl = 1;
  int nextLvlScore = 400;

  int maxOpenedLevel = 1;

  List<_Coral> corals = [];
  List<_Danger> dangers = [];
  List<Offset> coins = [];
  Timer? _timer;
  Timer? _countdownTimer;
  Timer? _gameOverTimer;
  Random random = Random();

  int countdown = 3;
  bool showCountdown = true;

  @override
  void initState() {
    super.initState();
    _loadMaxLevelAndStart();
  }

  Future<void> _loadMaxLevelAndStart() async {
    maxOpenedLevel = await getMaxOpenedLevel();
    lvl = widget.lvl.clamp(1, 15);
    nextLvlScore = (lvl == 1) ? 10 : lvl * 400; // <--- тут
    startLevel();
  }

  void startLevel() {
    if (!mounted) return;
    setState(() {
      fishX = 0.0;
      score = (lvl == 1) ? 0 : score;
      gameOver = false;
      paused = false;
      showCountdown = true;
      countdown = 3;
      nextLvlScore = lvl * 400; // <--- тут
      corals = [
        _Coral(0.95, randomY(), 'assets/coral1.png'),
        _Coral(-0.95, randomY(), 'assets/coral2.png'),
        _Coral(-0.95, randomY(), 'assets/coral3.png'),
      ];
      dangers = generateDangersByLevel(lvl);
      coins = List.generate(3, (index) => randomCoinPosition());
    });
    _timer?.cancel();
    _gameOverTimer?.cancel();
    startCountdown();
  }

  void startCountdown() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    setState(() {
      showCountdown = true;
      countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        countdown--;
      });
      if (countdown == 0) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          setState(() {
            showCountdown = false;
          });
          runGame();
        });
      }
    });
  }

  void runGame() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;
      if (!gameOver && !paused) {
        moveItems();
        checkCollisions();
        checkLvlUp();
      }
    });


  }

  List<_Danger> generateDangersByLevel(int lvl) {
    final List<_Danger> list = [];
    list.add(_Danger(randomX(), randomY(), 'assets/shark.png'));
    if (lvl >= 3) list.add(_Danger(randomX(), randomY(), 'assets/pufferfish.png'));
    if (lvl >= 5) list.add(_Danger(randomX(), randomY(), 'assets/jellyfish.png'));
    if (lvl >= 7) list.add(_Danger(randomX(), randomY(), 'assets/starfish.png'));
    if (lvl >= 9) list.add(_Danger(randomX(), randomY(), 'assets/shark.png'));
    if (lvl >= 10) list.add(_Danger(randomX(), randomY(), 'assets/shark.png'));
    if (lvl >= 12) list.add(_Danger(randomX(), randomY(), 'assets/pufferfish.png'));
    return list;
  }

  Offset randomCoinPosition() {
    double x = random.nextDouble() * 1.4 - 0.7;
    double y = random.nextDouble() * -1.2;
    return Offset(x, y);
  }

  double randomX() => random.nextDouble() * 1.7 - 0.85;
  double randomY() => random.nextDouble() * -1.2 + 1.2;

  void moveItems() {
    double baseSpeed = 0.008 + lvl * 0.0015;
    double dangerSpeed = 0.012 + lvl * 0.0022;
    double coinSpeed = 0.01 + lvl * 0.0012;

    if (!mounted) return;
    setState(() {
      coins = coins.map((c) {
        double newY = c.dy - coinSpeed;
        if (newY < -1.2) {
          return Offset(random.nextDouble() * 1.4 - 0.7, 1.2);
        }
        return Offset(c.dx, newY);
      }).toList();

      corals = corals.map((c) {
        double newY = c.y - baseSpeed;
        if (newY < -1.2) {
          if (c.asset == 'assets/coral1.png') {
            return _Coral(0.95, 1.2, c.asset);
          } else {
            return _Coral(-0.95, 1.2, c.asset);
          }
        }
        return _Coral(c.x, newY, c.asset);
      }).toList();

      dangers = dangers.map((d) {
        double newY = d.y - dangerSpeed;
        if (newY < -1.2) {
          return _Danger(randomX(), 1.2, d.asset);
        }
        return _Danger(d.x, newY, d.asset);
      }).toList();
    });
  }

  void checkCollisions() {
    Rect fishRect = Rect.fromCenter(
      center: Offset(fishX, fishY),
      width: fishSize / 400,
      height: fishSize / 800,
    );
    for (int i = 0; i < coins.length; i++) {
      Rect coinRect = Rect.fromCenter(
        center: Offset(coins[i].dx, coins[i].dy),
        width: coinSize / 400,
        height: coinSize / 800,
      );
      if (fishRect.overlaps(coinRect)) {
        if (!mounted) return;
        setState(() {
          score += 10;
          coins[i] = Offset(random.nextDouble() * 1.4 - 0.7, 1.2);
        });
      }
    }
    for (int i = 0; i < corals.length; i++) {
      Rect coralRect = Rect.fromCenter(
        center: Offset(corals[i].x, corals[i].y),
        width: coralSize / 400,
        height: coralSize / 800,
      );
      if (fishRect.overlaps(coralRect)) {
        if (!mounted) return;
        setState(() {
          gameOver = true;
        });
        _timer?.cancel();
        showGameOverTextAndGoToMenu();
        break;
      }
    }
    for (int i = 0; i < dangers.length; i++) {
      Rect dangerRect = Rect.fromCenter(
        center: Offset(dangers[i].x, dangers[i].y),
        width: dangerSize / 400,
        height: dangerSize / 800,
      );
      if (fishRect.overlaps(dangerRect)) {
        if (!mounted) return;
        setState(() {
          gameOver = true;
        });
        _timer?.cancel();
        showGameOverTextAndGoToMenu();
        break;
      }
    }
  }

// ... (остальной код без изменений)
  void checkLvlUp() async {
    if (score >= nextLvlScore && lvl < 15) {
      if (!mounted) return;
      setState(() {
        lvl = lvl + 1;
      });

      int nextLevel = lvl + 1;
      if (nextLevel != maxOpenedLevel) {
        maxOpenedLevel = nextLevel;

      }

      if (!mounted) return;
  _timer!.cancel();
      await setMaxOpenedLevel(nextLevel);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LevelSelectScreen(),
        ),
            (route) => false,
      );
    }
  }
// ... (остальной код без изменений)
  void moveFish(double delta) {
    if (!mounted) return;
    setState(() {
      fishX += delta;
      if (fishX < -1) fishX = -1;
      if (fishX > 1) fishX = 1;
    });
  }

  void showGameOverTextAndGoToMenu() {
    if (_gameOverTimer != null && _gameOverTimer!.isActive) return;
    _gameOverTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LevelSelectScreen(),
        ),
            (route) => false,
      );
    });
  }

  double alignX(BuildContext ctx, double x) =>
      (MediaQuery.of(ctx).size.width / 2) * (x + 1) - fishSize / 2;
  double alignY(BuildContext ctx, double y) =>
      (MediaQuery.of(ctx).size.height / 2) * (y + 1) - fishSize / 2;

  void pauseGame() {
    if (!mounted) return;
    setState(() {
      paused = true;
    });
    _timer?.cancel();
  }

  void resumeGame() {
    if (!mounted) return;
    setState(() {
      paused = false;
    });
    startCountdown();
  }

  void backToMenu() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _gameOverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Статичный фон
          Positioned.fill(
            child: Image.asset('assets/bg3.png', fit: BoxFit.cover),
          ),
          Positioned(
            top: 40,
            right: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.black38, borderRadius: BorderRadius.circular(16)),
              child: Text("Level: $lvl",
                  style: const TextStyle(fontSize: 22, color: Colors.white)),
            ),
          ),
          ..._buildGameObjects(context),
          Positioned(
            top: 40,
            left: 20,
            child: GestureDetector(
              onTap: paused || showCountdown ? null : pauseGame,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pause, color: Colors.white, size: 32),
              ),
            ),
          ),
          if (paused)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'PAUSE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: backToMenu,
                      child: const Text('Back to menu'),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () {
                        resumeGame();
                      },
                      child: const Text('Start'),
                    ),
                  ],
                ),
              ),
            ),
          if (showCountdown)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: countdown > 0
                      ? Text(
                    '$countdown',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 100,
                        fontWeight: FontWeight.bold),
                  )
                      : const Text(
                    'START!',
                    style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 64,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          if (gameOver)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Text(
                    "GAME OVER\nYour score: $score\nLevel: $lvl",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      color: Colors.red[300],
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 10, color: Colors.black)
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGameObjects(BuildContext context) {
    return [
      Positioned(
          top: 40,
          left: 80,
          child: Row(
            children: [
              Image.asset('assets/coin.png', width: 32),
              const SizedBox(width: 8),
              Text('$score',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black)
                      ])),
            ],
          )),
      AnimatedPositioned(
        duration: const Duration(milliseconds: 60),
        left: alignX(context, fishX),
        top: alignY(context, fishY),
        child: Image.asset('assets/fish.png', width: fishSize),
      ),
      ...coins.map((c) => Positioned(
        left: alignX(context, c.dx),
        top: alignY(context, c.dy),
        child: Image.asset('assets/coin.png', width: coinSize),
      )),
      ...corals.map((c) => Positioned(
        left: alignX(context, c.x),
        top: alignY(context, c.y),
        child: Image.asset(c.asset, width: coralSize),
      )),
      ...dangers.map((d) => Positioned(
        left: alignX(context, d.x),
        top: alignY(context, d.y),
        child: Image.asset(d.asset, width: dangerSize),
      )),
      Positioned(
        left: 30,
        bottom: 60,
        child: GestureDetector(
          onTap: paused || showCountdown || gameOver ? null : () => moveFish(-0.15),
          child: Opacity(
            opacity: paused || showCountdown || gameOver ? 0.4 : 1.0,
            child: Image.asset('assets/arrow_left.png', width: 80),
          ),
        ),
      ),
      Positioned(
        right: 30,
        bottom: 60,
        child: GestureDetector(
          onTap: paused || showCountdown || gameOver ? null : () => moveFish(0.15),
          child: Opacity(
            opacity: paused || showCountdown || gameOver ? 0.4 : 1.0,
            child: Image.asset('assets/arrow_right.png', width: 80),
          ),
        ),
      ),
    ];
  }
}