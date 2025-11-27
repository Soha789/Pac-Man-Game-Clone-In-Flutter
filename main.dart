import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const PacManApp());
}

class PacManApp extends StatefulWidget {
  const PacManApp({super.key});

  @override
  State<PacManApp> createState() => _PacManAppState();
}

class _PacManAppState extends State<PacManApp> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      primarySwatch: Colors.yellow,
      scaffoldBackgroundColor:
          isDarkMode ? const Color(0xFF000814) : Colors.grey.shade200,
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDarkMode ? const Color(0xFF000814) : Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Pac-Man',
      theme: theme,
      home: PacManGameScreen(
        isDarkMode: isDarkMode,
        onToggleDarkMode: () {
          setState(() {
            isDarkMode = !isDarkMode;
          });
        },
      ),
    );
  }
}

class PacManGameScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;

  const PacManGameScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<PacManGameScreen> createState() => _PacManGameScreenState();
}

// Grid configuration
const int rows = 17;
const int cols = 11;
const int numberOfSquares = rows * cols;

/// Directions for movement
enum Direction { up, down, left, right, none }

class _PacManGameScreenState extends State<PacManGameScreen> {
  int pacmanPosition = 0;
  List<int> ghostPositions = [];
  Set<int> walls = {};
  Set<int> pellets = {};
  Set<int> powerPellets = {};
  int score = 0;
  bool isGameOver = false;
  bool isPowerMode = false;

  Timer? ghostTimer;
  Timer? powerTimer;

  Direction currentDirection = Direction.none;
  final Random random = Random();

  double ghostSpeedMs = 450; // changed by difficulty
  String difficulty = 'Easy'; // Easy, Medium, Hard

  @override
  void initState() {
    super.initState();
    _setupMaze();
    _startGame();
  }

  @override
  void dispose() {
    ghostTimer?.cancel();
    powerTimer?.cancel();
    super.dispose();
  }

  void _setupMaze() {
    walls.clear();

    // Outer walls
    for (int c = 0; c < cols; c++) {
      walls.add(c); // top row
      walls.add((rows - 1) * cols + c); // bottom row
    }
    for (int r = 0; r < rows; r++) {
      walls.add(r * cols); // left column
      walls.add(r * cols + (cols - 1)); // right column
    }

    // Some inner walls for a simple maze
    for (int c = 2; c < cols - 2; c++) {
      walls.add(4 * cols + c);
      walls.add(12 * cols + c);
    }
    for (int r = 6; r < 11; r++) {
      walls.add(r * cols + 3);
      walls.add(r * cols + 7);
    }

    // Pellets and power pellets
    pellets.clear();
    powerPellets.clear();

    for (int i = 0; i < numberOfSquares; i++) {
      if (!walls.contains(i)) {
        pellets.add(i);
      }
    }

    // Place power pellets in 4 inner "corners"
    powerPellets.add(1 * cols + 1);
    powerPellets.add(1 * cols + (cols - 2));
    powerPellets.add((rows - 2) * cols + 1);
    powerPellets.add((rows - 2) * cols + (cols - 2));
  }

  void _startGame() {
    isGameOver = false;
    score = 0;
    isPowerMode = false;
    currentDirection = Direction.none;

    // Pac-Man start
    pacmanPosition = (rows - 3) * cols + (cols ~/ 2);

    // Ghosts start near center
    ghostPositions = [
      (rows ~/ 2) * cols + (cols ~/ 2),
      (rows ~/ 2) * cols + (cols ~/ 2) - 2,
      (rows ~/ 2) * cols + (cols ~/ 2) + 2,
    ];

    ghostTimer?.cancel();
    _startGhostTimer();
    setState(() {});
  }

  void _startGhostTimer() {
    ghostTimer = Timer.periodic(
      Duration(milliseconds: ghostSpeedMs.toInt()),
      (timer) {
        if (isGameOver) {
          timer.cancel();
          return;
        }
        _moveGhosts();
        _checkCollisions();
      },
    );
  }

  void _setDifficulty(String value) {
    difficulty = value;
    switch (value) {
      case 'Easy':
        ghostSpeedMs = 450;
        break;
      case 'Medium':
        ghostSpeedMs = 300;
        break;
      case 'Hard':
        ghostSpeedMs = 200;
        break;
      default:
        ghostSpeedMs = 450;
    }
    ghostTimer?.cancel();
    _startGhostTimer();
    setState(() {});
  }

  // Pac-Man movement via buttons
  void _movePacman(Direction direction) {
    if (isGameOver) return;

    currentDirection = direction;
    int newPosition = pacmanPosition;

    switch (direction) {
      case Direction.left:
        newPosition = pacmanPosition - 1;
        break;
      case Direction.right:
        newPosition = pacmanPosition + 1;
        break;
      case Direction.up:
        newPosition = pacmanPosition - cols;
        break;
      case Direction.down:
        newPosition = pacmanPosition + cols;
        break;
      case Direction.none:
        return;
    }

    if (_isInBounds(newPosition) && !_isWall(newPosition)) {
      setState(() {
        pacmanPosition = newPosition;
      });
      _eatPelletOrPowerPellet();
      _checkCollisions();
    }
  }

  bool _isInBounds(int pos) {
    return pos >= 0 && pos < numberOfSquares;
  }

  bool _isWall(int pos) {
    return walls.contains(pos);
  }

  // ✅ Updated: checks WIN immediately after eating last pellet
  void _eatPelletOrPowerPellet() {
    bool ateSomething = false;

    if (pellets.contains(pacmanPosition)) {
      setState(() {
        pellets.remove(pacmanPosition);
        score += 10;
      });
      ateSomething = true;
    }

    if (powerPellets.contains(pacmanPosition)) {
      setState(() {
        powerPellets.remove(pacmanPosition);
        score += 50;
        _activatePowerMode();
      });
      ateSomething = true;
    }

    // ⭐ After eating ANY pellet, check if all are gone
    if (ateSomething &&
        pellets.isEmpty &&
        powerPellets.isEmpty &&
        !isGameOver) {
      _triggerGameOver(win: true);
    }
  }

  void _activatePowerMode() {
    powerTimer?.cancel();
    setState(() {
      isPowerMode = true;
    });

    powerTimer = Timer(const Duration(seconds: 7), () {
      setState(() {
        isPowerMode = false;
      });
    });
  }

  void _moveGhosts() {
    setState(() {
      for (int i = 0; i < ghostPositions.length; i++) {
        ghostPositions[i] = _nextGhostPosition(ghostPositions[i]);
      }
    });
  }

  int _nextGhostPosition(int ghostPos) {
    final List<int> possibleMoves = [];

    void tryAdd(int newPos) {
      if (_isInBounds(newPos) && !_isWall(newPos)) {
        possibleMoves.add(newPos);
      }
    }

    tryAdd(ghostPos - 1); // left
    tryAdd(ghostPos + 1); // right
    tryAdd(ghostPos - cols); // up
    tryAdd(ghostPos + cols); // down

    if (possibleMoves.isEmpty) return ghostPos;

    // Prefer moves closer to Pac-Man
    possibleMoves.sort((a, b) {
      final da = _distanceToPacman(a);
      final db = _distanceToPacman(b);
      return da.compareTo(db);
    });

    // 70% choose closest, 30% random
    if (random.nextDouble() < 0.7) {
      return possibleMoves.first;
    } else {
      return possibleMoves[random.nextInt(possibleMoves.length)];
    }
  }

  double _distanceToPacman(int pos) {
    int r1 = pos ~/ cols;
    int c1 = pos % cols;
    int r2 = pacmanPosition ~/ cols;
    int c2 = pacmanPosition % cols;
    return sqrt(pow(r1 - r2, 2) + pow(c1 - c2, 2));
  }

  void _checkCollisions() {
    for (int i = 0; i < ghostPositions.length; i++) {
      if (ghostPositions[i] == pacmanPosition) {
        if (isPowerMode) {
          // Pac-Man eats ghost
          setState(() {
            score += 100;
            ghostPositions[i] = (rows ~/ 2) * cols + (cols ~/ 2);
          });
        } else {
          _triggerGameOver();
          return;
        }
      }
    }
    // (Win check is now only in _eatPelletOrPowerPellet)
  }

  void _triggerGameOver({bool win = false}) {
    if (isGameOver) return; // avoid double dialogs
    setState(() {
      isGameOver = true;
    });
    ghostTimer?.cancel();
    powerTimer?.cancel();

    String title = win ? 'You Win!' : 'Game Over';
    String message = win
        ? 'You collected all the pellets!'
        : 'Pac-Man was caught by a ghost!';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: Text(title),
          content: Text('$message\n\nScore: $score'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _setupMaze();
                _startGame();
              },
              child: const Text('Restart'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCell(int index) {
    final bool isWall = walls.contains(index);
    final bool isPacman = index == pacmanPosition;
    final bool isGhost = ghostPositions.contains(index);
    final bool hasPellet = pellets.contains(index);
    final bool hasPowerPellet = powerPellets.contains(index);

    Color wallColor =
        widget.isDarkMode ? const Color(0xFF001233) : Colors.blueGrey.shade800;

    if (isWall) {
      return Container(
        decoration: BoxDecoration(
          color: wallColor,
          border: Border.all(color: Colors.black, width: 0.5),
        ),
      );
    }

    Widget? child;

    if (hasPellet) {
      child = Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.yellow.shade200,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    if (hasPowerPellet) {
      child = Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.orangeAccent,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    if (isGhost) {
      child = Center(
        child: Icon(
          Icons.android,
          color: isPowerMode ? Colors.blueAccent : Colors.redAccent,
          size: 20,
        ),
      );
    }

    if (isPacman) {
      child = const Center(
        child: Icon(
          Icons.circle,
          color: Colors.yellowAccent,
          size: 22,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF001845) : Colors.black,
        border: Border.all(color: Colors.grey.shade900, width: 0.3),
      ),
      child: child,
    );
  }

  Widget _buildControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Up
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: () => _movePacman(Direction.up),
              iconSize: 32,
            ),
          ],
        ),
        // Left / Down / Right
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_left),
              onPressed: () => _movePacman(Direction.left),
              iconSize: 32,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => _movePacman(Direction.down),
              iconSize: 32,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_right),
              onPressed: () => _movePacman(Direction.right),
              iconSize: 32,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Pac-Man'),
        actions: [
          Row(
            children: [
              const Text('Dark'),
              Switch(
                value: widget.isDarkMode,
                onChanged: (_) => widget.onToggleDarkMode(),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Score: $score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      'Difficulty: ',
                      style: TextStyle(color: Colors.white),
                    ),
                    DropdownButton<String>(
                      dropdownColor: Colors.black87,
                      value: difficulty,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(
                          value: 'Easy',
                          child: Text('Easy'),
                        ),
                        DropdownMenuItem(
                          value: 'Medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(
                          value: 'Hard',
                          child: Text('Hard'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _setDifficulty(value);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // Maze
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: cols / rows,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                  ),
                  itemCount: numberOfSquares,
                  itemBuilder: (context, index) {
                    return _buildCell(index);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Controls + Restart
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                _buildControls(),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    _setupMaze();
                    _startGame();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart Game'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
