import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:ui';

void main() {
  runApp(const ParkinsonDetectionApp());
}

class ParkinsonDetectionApp extends StatelessWidget {
  const ParkinsonDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parkinson Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'Poppins',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// In-memory history storage
List<Map<String, dynamic>> predictionHistory = [];

// ==================== SPLASH SCREEN ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fade;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        CustomPageRoute(page: const InputScreen()),
      );
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, sin(_waveController.value * pi) * 8),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.health_and_safety,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Parkinson\'s\nDetection',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== INPUT SCREEN ====================
class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<String> _featureNames = const [
    'MDVP:Fo(Hz)', 'MDVP:Fhi(Hz)', 'MDVP:Flo(Hz)', 'MDVP:Jitter(%)',
    'MDVP:Jitter(Abs)', 'MDVP:RAP', 'MDVP:PPQ', 'Jitter:DDP',
    'MDVP:Shimmer', 'MDVP:Shimmer(dB)', 'Shimmer:APQ3', 'Shimmer:APQ5',
    'MDVP:APQ', 'Shimmer:DDA', 'NHR', 'HNR', 'RPDE', 'DFA',
    'spread1', 'spread2', 'D2', 'PPE'
  ];

  // Threshold for Parkinson's detection based on MDVP:Fo(Hz)
  static const double parkinsonThreshold = 145.0;

  @override
  void initState() {
    super.initState();
    for (var name in _featureNames) {
      _controllers[name] = TextEditingController();
      _focusNodes[name] = FocusNode();
    }
    _loadExampleValues();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  void _loadExampleValues() {
    final r = Random(42);
    for (var name in _featureNames) {
      String value;
      if (name.contains('Fo')) {
        // Random frequency: sometimes above threshold, sometimes below
        value = (120 + r.nextDouble() * 60).toStringAsFixed(2);
      } else if (name.contains('Jitter') || name.contains('Shimmer'))
        value = (0.001 + r.nextDouble() * 0.05).toStringAsFixed(5);
      else if (name.contains('HNR')) value = (10 + r.nextDouble() * 15).toStringAsFixed(2);
      else if (name.contains('RPDE')) value = (0.2 + r.nextDouble() * 0.5).toStringAsFixed(3);
      else value = (r.nextDouble() * 2).toStringAsFixed(4);
      _controllers[name]!.text = value;
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) c.dispose();
    for (var f in _focusNodes.values) f.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;

    // Get MDVP:Fo(Hz) value (first feature)
    double? frequency = double.tryParse(_controllers[_featureNames.first]!.text);
    if (frequency == null) return;

    // Simple rule: frequency > threshold -> Parkinson's
    final isParkinson = frequency > parkinsonThreshold;
    // Confidence based on how far the frequency is from threshold
    double confidence = isParkinson
        ? (0.5 + (frequency - parkinsonThreshold) / 50).clamp(0.5, 0.99)
        : (0.5 + (parkinsonThreshold - frequency) / 50).clamp(0.5, 0.99);

    // Haptic feedback
    if (isParkinson) {
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.lightImpact();
    }

    // Save to in-memory history
    final features = _featureNames
        .map((name) => double.parse(_controllers[name]!.text))
        .toList();
    predictionHistory.insert(0, {
      'timestamp': DateTime.now(),
      'isParkinson': isParkinson,
      'confidence': confidence,
      'features': features,
    });
    if (predictionHistory.length > 10) predictionHistory.removeLast();

    if (context.mounted) {
      Navigator.push(
        context,
        CustomPageRoute(
          page: ResultScreen(
            isParkinson: isParkinson,
            confidence: confidence,
            features: features,
            featureNames: _featureNames,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Input Features'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                CustomPageRoute(page: const HistoryScreen()),
              );
            },
          ),
        ],
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.1)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    children: [
                      const Icon(Icons.healing, size: 32, color: Colors.white70),
                      const SizedBox(height: 8),
                      const Text(
                        'Voice Biomarker Analysis',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Frequency > 145 Hz → Parkinson’s',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: _featureNames.map((name) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              double width = constraints.maxWidth < 600
                                  ? (MediaQuery.of(context).size.width - 56) / 2
                                  : 250;
                              return SizedBox(
                                width: width,
                                child: TextFormField(
                                  controller: _controllers[name],
                                  focusNode: _focusNodes[name],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: name,
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.15),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: const BorderSide(color: Colors.white, width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Required';
                                    if (double.tryParse(v) == null) return 'Invalid number';
                                    return null;
                                  },
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: ElevatedButton.icon(
                            onPressed: _predict,
                            icon: const Icon(Icons.mic),
                            label: const Text('Analyze Voice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF764ba2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                              elevation: 5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton.small(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _loadExampleValues();
                          setState(() {});
                        },
                        child: const Icon(Icons.download),
                        tooltip: 'Load example values',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== RESULT SCREEN ====================
class ResultScreen extends StatelessWidget {
  final bool isParkinson;
  final double confidence;
  final List<double> features;
  final List<String> featureNames;

  const ResultScreen({
    super.key,
    required this.isParkinson,
    required this.confidence,
    required this.features,
    required this.featureNames,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isParkinson
              ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFff6b6b), Color(0xFFee5a24)],
          )
              : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00b894), Color(0xFF019874)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Hero(
                  tag: 'resultIcon',
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 700),
                    builder: (_, value, __) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isParkinson ? Colors.red : Colors.green).withOpacity(0.2),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            isParkinson ? Icons.warning_rounded : Icons.check_circle_rounded,
                            size: 100 * value,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  isParkinson ? 'Parkinson’s Detected' : 'Healthy',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black26)],
                  ),
                ),
                const SizedBox(height: 16),
                Hero(
                  tag: 'confidenceCard',
                  child: GlassCard(
                    child: Column(
                      children: [
                        const Text(
                          'AI Confidence',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: CircularProgressIndicator(
                                value: confidence,
                                strokeWidth: 12,
                                backgroundColor: Colors.white24,
                                color: Colors.white,
                              ),
                            ),
                            Column(
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: confidence),
                                  duration: const Duration(milliseconds: 800),
                                  builder: (_, val, __) => Text(
                                    '${(val * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const Text('confidence', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: confidence,
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up, color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Decision Rule',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'MDVP:Fo(Hz) = ${features[0].toStringAsFixed(2)} Hz\n'
                            'Threshold = 145 Hz → ${features[0] > 145 ? "Parkinson’s" : "Healthy"}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Feature Value Distribution',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: features.length,
                          itemBuilder: (context, index) {
                            final value = features[index];
                            final maxVal = features.reduce(max);
                            final normalized = (value / maxVal).clamp(0.0, 1.0);
                            return Container(
                              width: 30,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    height: normalized * 140,
                                    width: 20,
                                    decoration: BoxDecoration(
                                      color: index == 0
                                          ? Colors.yellow.withOpacity(0.8)
                                          : Colors.white.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  RotatedBox(
                                    quarterTurns: 1,
                                    child: Text(
                                      featureNames[index].split(':').last,
                                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    icon: const Icon(Icons.replay),
                    label: const Text('New Screening'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isParkinson ? const Color(0xFFee5a24) : const Color(0xFF019874),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== HISTORY SCREEN ====================
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Prediction History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: predictionHistory.isEmpty
              ? const Center(
            child: Text('No predictions yet', style: TextStyle(color: Colors.white70)),
          )
              : ListView.builder(
            itemCount: predictionHistory.length,
            itemBuilder: (context, index) {
              final entry = predictionHistory[index];
              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      entry['isParkinson'] ? Icons.warning : Icons.check_circle,
                      color: entry['isParkinson'] ? Colors.redAccent : Colors.greenAccent,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry['isParkinson'] ? 'Parkinson’s Detected' : 'Healthy',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Confidence: ${(entry['confidence'] * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            _formatDate(entry['timestamp']),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
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
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute}';
}

// ==================== REUSABLE WIDGETS ====================
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GlassCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class CustomPageRoute extends PageRouteBuilder {
  final Widget page;

  CustomPageRoute({required this.page})
      : super(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 0.05);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
      return FadeTransition(
        opacity: animation.drive(fadeTween),
        child: SlideTransition(
          position: animation.drive(tween),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 600),
  );
}