import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Game.dart' show FishGameScreen;

Future<int> getMaxOpenedLevel() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('maxOpenedLevel') ?? 1;
}

Future<void> setMaxOpenedLevel(int lvl) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('maxOpenedLevel', lvl);
}

class LevelSelectScreen extends StatefulWidget {
  final int? passedMaxOpenedLevel;
  const LevelSelectScreen({super.key, this.passedMaxOpenedLevel});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  int maxOpenedLevel = 1;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadLevel();
  }

  Future<void> loadLevel() async {
    final spMaxOpenedLevel = await getMaxOpenedLevel();
    int newMaxOpenedLevel = widget.passedMaxOpenedLevel ?? spMaxOpenedLevel;

    if (spMaxOpenedLevel > newMaxOpenedLevel) {
      // Если в SharedPreferences уровень выше — используем его
      maxOpenedLevel = spMaxOpenedLevel;
    } else {
      // Если переданный выше (например, после прохождения) — обновляем SharedPreferences
      maxOpenedLevel = newMaxOpenedLevel;
      await setMaxOpenedLevel(maxOpenedLevel);
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/bg2.png',
              fit: BoxFit.cover,
            ),
          ),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                child: GridView.builder(
                  itemCount: 15,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 32,
                    crossAxisSpacing: 32,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final lvl = index + 1;
                    final isOpen = lvl <= maxOpenedLevel;
                    return GestureDetector(
                      onTap: isOpen
                          ? () async {
                        // После прохождения уровня можно передавать новый maxOpenedLevel:
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FishGameScreen(lvl: lvl),
                          ),
                        );
                        await loadLevel();
                      }
                          : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            isOpen ? 'assets/coin.png' : 'assets/bubble.png',
                            width: 92,
                            height: 92,
                            color: isOpen ? null : Colors.white.withOpacity(0.92),
                          ),
                          if (isOpen)
                            Text(
                              '$lvl',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFDDF0A),
                                shadows: [
                                  Shadow(
                                    blurRadius: 3,
                                    color: Colors.black38,
                                    offset: Offset(1, 2),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}