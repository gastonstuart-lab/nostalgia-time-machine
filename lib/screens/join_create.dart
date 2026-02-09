import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../state.dart';
import '../components/theme_toggle.dart';

class JoinCreateScreen extends StatefulWidget {
  const JoinCreateScreen({super.key});

  @override
  State<JoinCreateScreen> createState() => _JoinCreateScreenState();
}

class _JoinCreateScreenState extends State<JoinCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  int _selectedAvatarIndex = 0;
  int _startDecade = 1990;
  String _quizDifficulty = 'medium';

  final List<Map<String, dynamic>> _avatars = [
    {'icon': Icons.person, 'color': AppTheme.lightBackground},
    {'icon': Icons.face_6, 'color': AppTheme.lightSecondary},
    {'icon': Icons.face_2, 'color': AppTheme.lightPrimary},
    {'icon': Icons.face_4, 'color': AppTheme.lightBackground},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinGroup() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name')),
      );
      return;
    }
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group code')),
      );
      return;
    }

    final avatar = _avatars[_selectedAvatarIndex];
    final success = await context.read<NostalgiaProvider>().joinGroup(
          code: _codeController.text.trim().toUpperCase(),
          displayName: _nameController.text,
          avatarIcon: 'avatar_$_selectedAvatarIndex',
          avatarColor: (avatar['color'] as Color).toARGB32(),
        );

    if (!mounted) return;

    if (success) {
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Group not found. Check the code and try again.')),
      );
    }
  }

  Future<void> _createGroup() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name')),
      );
      return;
    }

    final avatar = _avatars[_selectedAvatarIndex];
    final success = await context.read<NostalgiaProvider>().createGroup(
          displayName: _nameController.text,
          avatarIcon: 'avatar_$_selectedAvatarIndex',
          avatarColor: (avatar['color'] as Color).toARGB32(),
          startDecade: _startDecade,
          quizDifficulty: _quizDifficulty,
        );

    if (!mounted) return;

    if (success) {
      final code = context.read<NostalgiaProvider>().currentGroup?.code;
      if (code != null) {
        _showSuccessDialog(code);
      } else {
        context.go('/dashboard');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to create group. Please try again.')),
      );
    }
  }

  void _showSuccessDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.lightBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          side: const BorderSide(color: AppTheme.lightOnSurface, width: 3),
        ),
        title: Row(
          children: const [
            Icon(Icons.celebration, color: AppTheme.lightPrimary),
            SizedBox(width: AppTheme.spacingSm),
            Text('Time Machine Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with your friends:'),
            const SizedBox(height: AppTheme.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.lightAccent,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.lightOnSurface, width: 2),
              ),
              child: SelectableText(
                code,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: AppTheme.lightOnSurface,
                    ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied group code!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                ),
                TextButton.icon(
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(text: 'Join my Rewind crew! Code: $code'),
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/dashboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lightPrimary,
              foregroundColor: AppTheme.lightOnPrimary,
            ),
            child: const Text('Start Journey'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Theme Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  ThemeToggle(),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),
              // Header
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.lightPrimary,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppTheme.lightOnSurface, width: 3),
                      boxShadow: AppTheme.shadowMd,
                    ),
                    child: const Icon(Icons.history_edu_rounded,
                        color: AppTheme.lightOnPrimary, size: 40),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    "REWIND",
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppTheme.lightPrimary,
                          height: 1.0,
                        ),
                  ),
                  Text(
                    "COLLECTIVE",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.lightOnSurface,
                          height: 1.0,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXl),

              // Identity Section
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: AppTheme.lightAccent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: AppTheme.lightOnSurface, width: 3),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "YOUR IDENTITY",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.lightOnSurface,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    _RetroInput(
                      label: "DISPLAY NAME",
                      hint: "Enter nickname...",
                      controller: _nameController,
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Text(
                      "CHOOSE AVATAR",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.lightOnSurface,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_avatars.length, (index) {
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedAvatarIndex = index),
                          child: _AvatarPickerItem(
                            icon: _avatars[index]['icon'],
                            bgColor: _avatars[index]['color'],
                            isSelected: _selectedAvatarIndex == index,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),

              // Join Group Card
              _ActionCard(
                title: "JOIN GROUP",
                description:
                    "Have a secret code? Jump into an existing time machine.",
                icon: Icons.group_add,
                bgColor: AppTheme.lightBackground,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.lightBackground,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                              color: AppTheme.lightOnSurface, width: 2),
                        ),
                        child: TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            hintText: "CODE: 1990",
                            hintStyle: TextStyle(color: AppTheme.lightHint),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    GestureDetector(
                      onTap: _joinGroup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.lightSecondary,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                              color: AppTheme.lightOnSurface, width: 3),
                        ),
                        child: const Text(
                          "GO",
                          style: TextStyle(
                            color: AppTheme.lightOnPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // Create Group Card
              _ActionCard(
                title: "NEW CREW",
                description:
                    "Choose your starting decade and quiz difficulty, then launch your crew.",
                icon: Icons.auto_awesome,
                bgColor: AppTheme.lightSecondary,
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      value: _startDecade,
                      decoration: const InputDecoration(
                        labelText: "Starting Decade",
                      ),
                      items: const [
                        DropdownMenuItem(value: 1970, child: Text('1970s')),
                        DropdownMenuItem(value: 1980, child: Text('1980s')),
                        DropdownMenuItem(value: 1990, child: Text('1990s')),
                        DropdownMenuItem(value: 2000, child: Text('2000s')),
                        DropdownMenuItem(value: 2010, child: Text('2010s')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _startDecade = value);
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    DropdownButtonFormField<String>(
                      value: _quizDifficulty,
                      decoration: const InputDecoration(
                        labelText: "Initial Quiz Difficulty",
                      ),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(
                            value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _quizDifficulty = value);
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    GestureDetector(
                      onTap: _createGroup,
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: AppTheme.lightOnSurface,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.rocket_launch,
                                color: AppTheme.lightOnPrimary, size: 20),
                            SizedBox(width: AppTheme.spacingSm),
                            Text(
                              "CREATE TIME MACHINE",
                              style: TextStyle(
                                color: AppTheme.lightOnPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingXl),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                            color: AppTheme.lightOnSurface,
                            borderRadius: BorderRadius.circular(99))),
                    const SizedBox(width: AppTheme.spacingSm),
                    const Icon(Icons.album,
                        color: AppTheme.lightOnSurface, size: 24),
                    const SizedBox(width: AppTheme.spacingSm),
                    Container(
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                            color: AppTheme.lightOnSurface,
                            borderRadius: BorderRadius.circular(99))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetroInput extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;

  const _RetroInput({
    required this.label,
    required this.hint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.lightOnSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.lightBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.lightOnSurface, width: 3),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppTheme.lightHint),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarPickerItem extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final bool isSelected;

  const _AvatarPickerItem({
    required this.icon,
    required this.bgColor,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.lightOnSurface, width: 3),
        boxShadow: isSelected ? AppTheme.shadowSm : null,
      ),
      child: Center(
        child: Icon(icon, color: AppTheme.lightOnSurface, size: 32),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color bgColor;
  final Widget child;

  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.bgColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingLg),
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.lightOnSurface, width: 3),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.lightBackground,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.lightOnSurface, width: 2),
                ),
                child: Icon(icon, color: AppTheme.lightOnSurface, size: 24),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.lightOnSurface,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightOnSurface,
                ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          child,
        ],
      ),
    );
  }
}
