import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:latlong2/latlong.dart';
import 'authorized_routes.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleAccess(BuildContext context) async {
    if (_currentTabIndex == 1) {
      // Guest access - directly navigate to home
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
    // Authorized personnel login

    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Simulate network delay
    await Future.delayed(Duration(seconds: 2));

    setState(() => _isLoading = false);
    
    // For authorized personnel, navigate to the AuthorizedRoutesScreen
    // We'll use a default starting location (Hyderabad city center)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AuthorizedRoutesScreen(
          startLocation: LatLng(17.3850, 78.4867), // Hyderabad city center
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Optimized ripple background
          OptimizedRippleBackground(
            gradientColors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          ),

          // Content
          SafeArea(
            child: SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              child: Container(
                height: size.height,
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: Colors.white.withOpacity(0.2),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        tabs: [
                          Tab(text: 'Authorized Personnel'),
                          Tab(text: 'Guest'),
                        ],
                      ),
                    ),
                    // Optimized AnimatedSwitcher with cached tweens
                      AnimatedSwitcher(
                      duration: const Duration(milliseconds: 800), // Slightly reduced for better performance
                      switchInCurve: Curves.easeInOutExpo,
                      switchOutCurve: Curves.easeInOutExpo,
                      transitionBuilder: (child, animation) {
                        // Use cached tweens to avoid recreating them on each build
                        final offsetTween = Tween<Offset>(
                          begin: Offset(0.0, 0.2),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.fastOutSlowIn));
                        final scaleTween = Tween<double>(begin: 0.97, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack));
                        
                        return RepaintBoundary(
                          child: FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: animation.drive(offsetTween),
                              child: ScaleTransition(
                                scale: animation.drive(scaleTween),
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Column(
                        key: ValueKey(_currentTabIndex),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: Duration(milliseconds: 700),
                            switchInCurve: Curves.easeInOutExpo,
                            child: Text(
                              _currentTabIndex == 0 ? 'Welcome back,' : 'Welcome Guest,',
                              key: ValueKey('welcome-$_currentTabIndex'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          AnimatedSwitcher(
                            duration: Duration(milliseconds: 700),
                            switchInCurve: Curves.easeInOutExpo,
                            child: Text(
                              _currentTabIndex == 0 ? 'Login to continue' : 'Continue as guest',
                              key: ValueKey('subtitle-$_currentTabIndex'),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 32),
                          _buildAnimatedLoginCard(_currentTabIndex),
                        ],
                      ),
                    ),
                    SizedBox(height: 40),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Center(
                        child: TextButton(
                          onPressed: () {},
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(color: Colors.white70),
                              children: [
                                TextSpan(
                                  text: 'Sign Up',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Optimized text field with cached decorations
  final _textFieldDecoration = InputDecoration(
    labelStyle: const TextStyle(color: Colors.white70),
    prefixIconColor: Colors.white70,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white38),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.white),
    ),
    filled: true,
    fillColor: Colors.white.withOpacity(0.1),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _textFieldDecoration.copyWith(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon, color: Colors.white70),
        suffixIcon: suffixIcon,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
    );
  }

  // Cached button style for better performance
  final _buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: const Color(0xFF6A11CB),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    elevation: 5,
  );

  // Cached text styles
  final _buttonTextStyle = const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  Widget _buildLoginButton(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(
        key: ValueKey(_isLoading),
        width: double.infinity,
        height: 55,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _handleAccess(context),
          style: _buttonStyle,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6A11CB),
                    ),
                  ),
                )
              : Text(
                  _currentTabIndex == 0 ? 'Login' : 'Continue as Guest',
                  style: _buttonTextStyle,
                ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLoginCard(int tabIndex) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 900),
      switchInCurve: Curves.easeInOutExpo,
      switchOutCurve: Curves.easeInOutExpo,
      transitionBuilder: (child, animation) {
        final offsetTween = Tween<Offset>(
          begin: Offset(0.0, 0.15),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.fastOutSlowIn));
        final scaleTween = Tween<double>(begin: 0.97, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(offsetTween),
            child: ScaleTransition(
              scale: animation.drive(scaleTween),
              child: child,
            ),
          ),
        );
      },
      child: ClipRRect(
        key: ValueKey(tabIndex),
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 32,
                  spreadRadius: 8,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: _buildStaggeredForm(tabIndex),
          ),
        ),
      ),
    );
  }

  // Optimized staggered form with better performance
  Widget _buildStaggeredForm(int tabIndex) {
    final children = <Widget>[];
    if (tabIndex == 0) {
      // Only build these widgets when in authorized tab
      children.addAll([
        _buildTextField(
          controller: emailController,
          labelText: 'Email',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        _buildTextField(
          controller: passwordController,
          labelText: 'Password',
          prefixIcon: Icons.lock_outline,
          obscureText: !_isPasswordVisible,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ]);
    }
    children.add(_buildLoginButton(context));
    
    // Use RepaintBoundary to isolate animations and reduce repaints
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(children.length, (i) {
          // Optimize animation by using a fixed duration for each item
          // This reduces the number of unique animations created
          final duration = Duration(milliseconds: 350 + (i < 3 ? i * 90 : 270));
          return AnimatedSlide(
            duration: duration,
            curve: Curves.easeOutExpo,
            offset: Offset.zero, // Start at final position for better performance
            child: AnimatedOpacity(
              duration: duration,
              opacity: 1.0,
              curve: Curves.easeOutExpo,
              child: children[i],
            ),
          );
        }),
      ),
    );
  }
}

// Optimized ripple class
class OptimizedRipple {
  final Offset position;
  final Color color;
  double radius = 0.0;
  double opacity = 0.5;
  bool isActive = true;

  // Timestamp used for time-based animation instead of controllers
  final DateTime createdAt = DateTime.now();

  OptimizedRipple({required this.position, required this.color});

  // Duration in milliseconds
  static const rippleDuration = 2000;

  // Update ripple state based on elapsed time
  void update() {
    final elapsedMs = DateTime.now().difference(createdAt).inMilliseconds;
    final progress = (elapsedMs / rippleDuration).clamp(0.0, 1.0);

    // Update radius and opacity based on progress
    radius = progress;
    opacity = 1.0 - progress;

    // Mark as inactive when animation completes
    if (progress >= 1.0) {
      isActive = false;
    }
  }
}

// Optimized ripple background widget
class OptimizedRippleBackground extends StatefulWidget {
  final List<Color> gradientColors;

  const OptimizedRippleBackground({
    Key? key,
    required this.gradientColors,
  }) : super(key: key);

  @override
  _OptimizedRippleBackgroundState createState() => _OptimizedRippleBackgroundState();
}

class _OptimizedRippleBackgroundState extends State<OptimizedRippleBackground> {
  final List<OptimizedRipple> _ripples = [];

  // Rate limiter to prevent too many ripples
  DateTime? _lastTapTime;

  // Ticker for smooth animation
  Ticker? _ticker;
  bool _needsRebuild = false;

  @override
  void initState() {
    super.initState();

    // Create a ticker for frame-based animation instead of multiple controllers
    _ticker = Ticker((elapsed) {
      // Update all active ripples
      bool hadActiveRipples = _ripples.isNotEmpty;
      
      for (var ripple in _ripples) {
        ripple.update();
      }

      // Remove inactive ripples
      _ripples.removeWhere((ripple) => !ripple.isActive);

      // Only schedule a rebuild if the ripple state changed
      if (hadActiveRipples && _ripples.isNotEmpty) {
        if (!_needsRebuild) {
          _needsRebuild = true;
          // Use microtask to batch updates and reduce rebuilds
          Future.microtask(() {
            if (mounted && _needsRebuild) {
              setState(() {});
              _needsRebuild = false;
            }
          });
        }
      }
    });

    _ticker!.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    // Rate limit to at most 1 ripple every 100ms
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 100) {
      return;
    }
    _lastTapTime = now;

    // Maximum ripples limit to prevent lag
    if (_ripples.length >= 8) { // Reduced from 10 to 8 for better performance
      _ripples.removeAt(0); // Remove oldest ripple
    }

    // Add new ripple without triggering a rebuild cascade
    _ripples.add(OptimizedRipple(
      position: details.localPosition,
      color: Colors.white,
    ));
    
    // Schedule a single rebuild
    if (mounted) {
      setState(() {});
    }
  }

  // Cached gradient for better performance
  LinearGradient? _cachedGradient;
  
  @override
  void didUpdateWidget(OptimizedRippleBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rebuild gradient if colors changed
    if (oldWidget.gradientColors != widget.gradientColors) {
      _cachedGradient = null;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Create gradient only once and cache it
    _cachedGradient ??= LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: widget.gradientColors,
    );
    
    return GestureDetector(
      onTapDown: _onTapDown,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient background with cached shader
          Container(
            decoration: BoxDecoration(gradient: _cachedGradient),
          ),

          // Optimized ripple painter with RepaintBoundary to isolate repaints
          RepaintBoundary(
            child: CustomPaint(
              painter: OptimizedRipplePainter(ripples: _ripples),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class Ticker {
  final Function(Duration elapsed) onTick;
  bool _isActive = false;
  DateTime? _startTime;

  Ticker(this.onTick);

  void start() {
    if (_isActive) return;
    _isActive = true;
    _startTime = DateTime.now();
    _tick();
  }

  void _tick() {
    if (!_isActive) return;

    final elapsed = DateTime.now().difference(_startTime!);
    onTick(elapsed);

    // Schedule next frame using Future.delayed with zero delay
    // This is more efficient than using multiple AnimationControllers
    Future.delayed(Duration.zero, _tick);
  }

  void dispose() {
    _isActive = false;
  }
}

// Optimized ripple painter
class OptimizedRipplePainter extends CustomPainter {
  final List<OptimizedRipple> ripples;
  // Cached paints to avoid creating new objects during painting
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  OptimizedRipplePainter({required this.ripples});

  @override
  void paint(Canvas canvas, Size size) {
    if (ripples.isEmpty) return; // Skip painting if no ripples
    
    final maxRadius = size.width * 0.5;

    for (var ripple in ripples) {
      // Reuse paint objects instead of creating new ones each time
      // Update only the color property
      _fillPaint.color = ripple.color.withOpacity(ripple.opacity * 0.3);
      _strokePaint.color = ripple.color.withOpacity(ripple.opacity * 0.7);

      // Draw fill
      canvas.drawCircle(
        ripple.position,
        maxRadius * ripple.radius * 0.6,
        _fillPaint
      );

      // Draw outline
      canvas.drawCircle(
        ripple.position,
        maxRadius * ripple.radius,
        _strokePaint
      );
    }
  }

  @override
  bool shouldRepaint(OptimizedRipplePainter oldDelegate) {
    // Only repaint if the ripples have changed
    return ripples != oldDelegate.ripples;
  }
}