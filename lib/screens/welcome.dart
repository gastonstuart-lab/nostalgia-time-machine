import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../state.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _features = <({
    IconData icon,
    String title,
    String subtitle,
    Color accent,
  })>[
    (
      icon: Icons.auto_awesome_rounded,
      title: 'AI Nostalgia Assistant',
      subtitle: 'Year-aware song and TV suggestions, instantly.',
      accent: Color(0xFFF59E0B),
    ),
    (
      icon: Icons.groups_rounded,
      title: 'Live Group Playlist',
      subtitle: 'Build weekly memories with friends in real time.',
      accent: Color(0xFF06B6D4),
    ),
    (
      icon: Icons.quiz_rounded,
      title: 'Weekly Quiz Battles',
      subtitle: 'Compete on decade trivia and crown the winner.',
      accent: Color(0xFF22C55E),
    ),
    (
      icon: Icons.local_movies_rounded,
      title: 'AI Movie Finder',
      subtitle: 'Find the exact film, validate the year, preview the trailer.',
      accent: Color(0xFFEF4444),
    ),
    (
      icon: Icons.tv_rounded,
      title: 'TV Time Machine',
      subtitle: 'Discover shows running in your current year and add instantly.',
      accent: Color(0xFF8B5CF6),
    ),
  ];

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  Timer? _featureTicker;
  int _featureIndex = 0;
  bool _loadingGoogle = false;
  bool _loadingEmail = false;
  bool _loadingSignIn = false;
  bool _loadingReset = false;

  @override
  void initState() {
    super.initState();
    _featureTicker = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      if (!mounted) return;
      setState(() => _featureIndex = (_featureIndex + 1) % _features.length);
    });
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password (min 6 chars).')),
      );
      return;
    }
    setState(() => _loadingSignIn = true);
    try {
      await context.read<NostalgiaProvider>().signInWithEmail(email, password);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = e.message ?? e.code;
      if (e.code == 'user-not-found') {
        msg = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        msg = 'Incorrect password.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email sign-in failed: $msg')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Email sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _loadingSignIn = false);
    }
  }

  @override
  void dispose() {
    _featureTicker?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _loadingGoogle = true);
    try {
      await context.read<NostalgiaProvider>().signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _signUpWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password (min 6 chars).')),
      );
      return;
    }
    setState(() => _loadingEmail = true);
    try {
      await context.read<NostalgiaProvider>().signUpWithEmail(email, password);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'operation-not-allowed') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Email/Password sign-in is not enabled yet. Please use Google sign-in for now.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email sign-up failed: ${e.message ?? e.code}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Email sign-up failed: $e')));
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first.')),
      );
      return;
    }
    setState(() => _loadingReset = true);
    try {
      await context.read<NostalgiaProvider>().sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = e.message ?? e.code;
      if (e.code == 'user-not-found') {
        msg = 'No user found for that email.';
      } else if (e.code == 'invalid-email') {
        msg = 'That email address is invalid.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset failed: $msg')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feature = _features[_featureIndex];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF0F0F12), Color(0xFF1A1411)]
                : const [Color(0xFFF5F8FF), Color(0xFFEFF4FF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF4A7BFF), Color(0xFF7F8CFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.music_note_rounded,
                            color: Colors.white, size: 42),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Nostalgia Time Machine',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkPrimaryText : Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Travel back through the music of your life.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? AppTheme.darkSecondaryText : Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      child: Container(
                        key: ValueKey('feature_$_featureIndex'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF201914) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: feature.accent.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: feature.accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(feature.icon, color: feature.accent, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    feature.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppTheme.darkPrimaryText : Color(0xFF111827),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    feature.subtitle,
                                    style: TextStyle(
                                      color: isDark ? AppTheme.darkSecondaryText : const Color(0xFF6B7280),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _features.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _featureIndex ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _featureIndex
                                ? feature.accent
                                : const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadingGoogle ? null : _continueWithGoogle,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loadingGoogle
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue with Google'),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.darkSecondaryText : const Color(0xFF6B7280))),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _loadingEmail ? null : _signUpWithEmail,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loadingEmail
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign up with Email'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _loadingSignIn ? null : _signInWithEmail,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loadingSignIn
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in with Email'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadingReset ? null : _forgotPassword,
                      child: _loadingReset
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Forgot password?'),
                    ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
