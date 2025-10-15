import 'package:cab_tracker_app/view/attendance_screen.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _primaryController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _logoController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _logoRotation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        AssetImage("assets/images/cabApp.png"),
        context,
      );
    });
    
    _primaryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _setupAnimations();
    _startAnimationSequence();
    
    
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AttendanceScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOutCubic,
                )),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  void _setupAnimations() {
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _primaryController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _primaryController, curve: const Interval(0.2, 0.8, curve: Curves.elasticOut)),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _primaryController, curve: const Interval(0.3, 1.0, curve: Curves.easeOutBack)));
    
    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(_floatingController);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(_pulseController);
    _logoRotation = Tween<double>(begin: -0.1, end: 0.1).animate(_logoController);
  }

  void _startAnimationSequence() async {
    _floatingController.repeat();
    _pulseController.repeat(reverse: true);
    _particleController.repeat();
    
    await Future.delayed(const Duration(milliseconds: 200));
    _primaryController.forward();
    
    await Future.delayed(const Duration(milliseconds: 800));
    _logoController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _rotateAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.3 + (_rotateAnimation.value * 0.6), -0.4),
                    radius: 1.5,
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.4),
                      const Color(0xFF8B5CF6).withOpacity(0.3),
                      const Color(0xFF06B6D4).withOpacity(0.2),
                      const Color(0xFF0A0A0B),
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              );
            },
          ),
          
          // Floating particles
          ...List.generate(12, (index) {
            return AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                final progress = (_particleController.value + (index * 0.1)) % 1.0;
                final angle = (index * 30.0) * (math.pi / 180);
                final radius = 100 + (progress * 200);
                
                return Positioned(
                  left: size.width * 0.5 + math.cos(angle) * radius - 3,
                  top: size.height * 0.4 + math.sin(angle) * radius - 3,
                  child: Opacity(
                    opacity: (1.0 - progress) * 0.6,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF60A5FA),
                            const Color(0xFF34D399),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF60A5FA).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          
          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glassmorphic logo container
                      AnimatedBuilder(
                        animation: Listenable.merge([_pulseAnimation, _logoRotation]),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Transform.rotate(
                              angle: _logoRotation.value,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.15),
                                      Colors.white.withOpacity(0.05),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: Image.asset("assets/images/cabApp.png")
                                  // BackdropFilter(
                                  //   filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  //   child: Container(
                                  //     decoration: BoxDecoration(
                                  //       gradient: LinearGradient(
                                  //         begin: Alignment.topLeft,
                                  //         end: Alignment.bottomRight,
                                  //         colors: [
                                  //           Colors.white.withOpacity(0.1),
                                  //           Colors.white.withOpacity(0.02),
                                  //         ],
                                  //       ),
                                  //     ),
                                  //     child: Center(
                                  //       child: ShaderMask(
                                  //         shaderCallback: (bounds) => const LinearGradient(
                                  //           colors: [
                                  //             Color(0xFF60A5FA),
                                  //             Color(0xFF34D399),
                                  //             Color(0xFFFBBF24),
                                  //           ],
                                  //         ).createShader(bounds),
                                  //         child:  Icon(
                                  //           Icons.local_taxi,
                                  //           size: 70,
                                  //           color: Colors.white,
                                  //         ),
                                  //       ),
                                  //     ),
                                  //   ),
                                  // ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 60),
                      
                      // Modern typography with gradient
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFF60A5FA),
                            Color(0xFF34D399),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Attendance Tracker',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 4.0,
                            height: 1.1,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      
                      // Modern minimal loading indicator
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Rotating gradient ring
                            AnimatedBuilder(
                              animation: _rotateAnimation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _rotateAnimation.value * 2 * math.pi,
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(
                                        colors: [
                                          const Color(0xFF6366F1),
                                          const Color(0xFF8B5CF6),
                                          const Color(0xFF6366F1).withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.3, 0.7, 1.0],
                                      ),
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Loading text with typewriter effect
                      AnimatedBuilder(
                        animation: _primaryController,
                        builder: (context, child) {
                          return Text(
                            'Initializing...',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.6),
                              letterSpacing: 3.0,
                            ),
                          );
                        },
                      ),
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
}

