import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../state.dart';
import '../nav.dart';
import '../models/group.dart';
import '../components/theme_toggle.dart';
import '../services/firestore_service.dart';

class GroupSettingsScreen extends StatefulWidget {
  const GroupSettingsScreen({super.key});

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  bool _dailyReminder = true;
  bool _weeklyAlert = false;
  bool _yearlyRecap = true;
  bool _isGeneratingCode = false;
  bool _isLeavingGroup = false;
  bool _isStartingNewMachine = false;

  int? _songCap;
  int? _episodeCap;
  String _quizDifficulty = 'medium';
  late TextEditingController _songCapController;
  late TextEditingController _episodeCapController;
  bool _savingCaps = false;

  Future<void> _saveCaps({
    required Group group,
    required int songCap,
    required int episodeCap,
    required String quizDifficulty,
  }) async {
    final newSongCap = _songCap ?? songCap;
    final newEpisodeCap = _episodeCap ?? episodeCap;
    if (newSongCap < 1 ||
        newSongCap > 10 ||
        newEpisodeCap < 1 ||
        newEpisodeCap > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caps out of range.')),
      );
      return;
    }
    setState(() {
      _savingCaps = true;
    });
    await FirestoreService().updateGroupSettings(group.id, {
      'songCapPerUser': newSongCap,
      'episodeCapPerUser': newEpisodeCap,
      'quizDifficulty': quizDifficulty,
    });
    if (!mounted) return;
    setState(() {
      _savingCaps = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caps updated!')),
    );
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<NostalgiaProvider>();
    final group = provider.currentGroup;
    _songCap = group?.songCapPerUser ?? 7;
    _episodeCap = group?.episodeCapPerUser ?? 1;
    _quizDifficulty = group?.quizDifficulty ?? 'medium';
    _songCapController = TextEditingController(text: _songCap.toString());
    _episodeCapController = TextEditingController(text: _episodeCap.toString());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final newSongCap = group?.songCapPerUser ?? 7;
    final newEpisodeCap = group?.episodeCapPerUser ?? 1;
    final newQuizDifficulty = group?.quizDifficulty ?? 'medium';
    if (_songCap != newSongCap) {
      setState(() {
        _songCap = newSongCap;
        _songCapController.text = _songCap.toString();
      });
    }
    if (_episodeCap != newEpisodeCap) {
      setState(() {
        _episodeCap = newEpisodeCap;
        _episodeCapController.text = _episodeCap.toString();
      });
    }
    if (_quizDifficulty != newQuizDifficulty) {
      setState(() {
        _quizDifficulty = newQuizDifficulty;
      });
    }
  }

  Future<void> _generateNewCode() async {
    final provider = context.read<NostalgiaProvider>();
    final group = provider.currentGroup;
    if (group == null) return;

    setState(() => _isGeneratingCode = true);

    try {
      await FirestoreService().generateNewGroupCode(group.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New group code generated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate code: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingCode = false);
      }
    }
  }

  Future<void> _leaveGroup() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text(
            'Are you sure you want to leave this group? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLeavingGroup = true);

    try {
      final provider = context.read<NostalgiaProvider>();
      await provider.leaveGroup();

      if (mounted) {
        context.go(AppRoutes.joinCreate);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave group: $e')),
        );
        setState(() => _isLeavingGroup = false);
      }
    }
  }

  Future<void> _startNewTimeMachine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a New Time Machine?'),
        content: const Text(
            'This will leave your current crew and create a new one.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isStartingNewMachine = true);
    try {
      final provider = context.read<NostalgiaProvider>();
      await provider.leaveGroup();
      if (mounted) {
        context.go(AppRoutes.joinCreate);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start new time machine: $e')),
      );
      setState(() => _isStartingNewMachine = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final members = provider.members;
    final isDark = provider.themeMode == ThemeMode.dark;
    final userUid = provider.currentUserProfile?.uid ?? '';
    final isAdmin = group != null && group.adminUid == userUid;
    final songCap = _songCap ?? 7;
    final episodeCap = _episodeCap ?? 1;
    final quizDifficulty = _quizDifficulty;

    if (group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Theme.of(context).iconTheme.color),
          onPressed: () => context.pop(),
        ),
        title: Text("Group Settings",
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
        actions: const [
          ThemeToggle(),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Group Info
              // Admin-only caps editor
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Weekly Caps",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: AppTheme.spacingSm),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Songs per user: ${_songCap ?? 7}",
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                                Slider(
                                  value: (_songCap ?? 7).toDouble(),
                                  min: 1,
                                  max: 10,
                                  divisions: 9,
                                  label: (_songCap ?? 7).toString(),
                                  onChanged: (value) {
                                    setState(() {
                                      _songCap = value.round();
                                      _songCapController.text =
                                          _songCap.toString();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Episodes per user: ${_episodeCap ?? 1}",
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                                Slider(
                                  value: (_episodeCap ?? 1).toDouble(),
                                  min: 1,
                                  max: 3,
                                  divisions: 2,
                                  label: (_episodeCap ?? 1).toString(),
                                  onChanged: (value) {
                                    setState(() {
                                      _episodeCap = value.round();
                                      _episodeCapController.text =
                                          _episodeCap.toString();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      DropdownButtonFormField<String>(
                        value: quizDifficulty,
                        decoration: InputDecoration(
                          labelText: 'Quiz Difficulty',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        iconEnabledColor: Theme.of(context).colorScheme.onSurface,
                        items: [
                          DropdownMenuItem(
                              value: 'easy',
                              child: Text('Easy',
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.onSurface))),
                          DropdownMenuItem(
                              value: 'medium',
                              child: Text('Medium',
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.onSurface))),
                          DropdownMenuItem(
                              value: 'hard',
                              child: Text('Hard',
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.onSurface))),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _quizDifficulty = value;
                          });
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      ElevatedButton(
                        onPressed: _savingCaps
                            ? null
                            : () => _saveCaps(
                                  group: group,
                                  songCap: songCap,
                                  episodeCap: episodeCap,
                                  quizDifficulty: quizDifficulty,
                                ),
                        child: _savingCaps
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text("Save Caps"),
                      ),
                    ],
                  ),
                ),
              if (!isAdmin)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Weekly Caps",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: AppTheme.spacingSm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _songCapController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: "Songs per user",
                                helperText: "1–10",
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMd),
                          Expanded(
                            child: TextField(
                              controller: _episodeCapController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: "Episodes per user",
                                helperText: "1–3",
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'Quiz Difficulty',
                          helperText: quizDifficulty[0].toUpperCase() +
                              quizDifficulty.substring(1),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      ElevatedButton(
                        onPressed: null,
                        child: const Text("Save Caps (admin only)"),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface, width: 2),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 2),
                      ),
                      child: Center(
                        child: Icon(Icons.groups_rounded,
                            color: Theme.of(context).colorScheme.onSecondary,
                            size: 40),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Rewind Collective",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          Text("Started at: ${group.currentDecadeStart}",
                              style: Theme.of(context).textTheme.bodyMedium),
                          Text("Current Year: ${group.currentYear}",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              Text("Invite Friends",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppTheme.spacingSm),

              // Invite Code
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface, width: 2),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        "Share this code with your crew to start the time machine together.",
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppTheme.spacingMd),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: group.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Code copied to clipboard!')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(group.code,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)),
                            Icon(Icons.content_copy_rounded,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _isGeneratingCode ? null : _generateNewCode,
                            icon: _isGeneratingCode
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: const Text("Generate New Code"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSurface,
                              side: BorderSide(
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        OutlinedButton.icon(
                          onPressed: () {
                            SharePlus.instance.share(
                              ShareParams(
                                  text:
                                      'Join my Rewind crew! Code: ${group.code}'),
                            );
                          },
                          icon: const Icon(Icons.share_rounded),
                          label: const Text("Share"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.secondary,
                            side: BorderSide(
                                color: Theme.of(context).colorScheme.secondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Time Travelers (${members.length})",
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text("See All",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSm),

              // Members List
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface, width: 2),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Column(
                  children: [
                    ...members.asMap().entries.map((entry) {
                      final index = entry.key;
                      final member = entry.value;
                      final isLast = index == members.length - 1;
                      return Column(
                        children: [
                          _MemberTile(
                            name: member.displayName,
                            role: index == 0 ? "Group Admin" : "Member",
                            initials: member.displayName
                                .substring(0, 1)
                                .toUpperCase(),
                            color: Color(member.avatarColor),
                            isAdmin: index == 0,
                          ),
                          if (!isLast)
                            Divider(color: Theme.of(context).dividerColor),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              Text("Reminders",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppTheme.spacingSm),

              // Reminders
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface, width: 2),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Column(
                  children: [
                    _ToggleRow(
                      title: "Daily Song Reminder",
                      subtitle: "Alert if you haven't added your daily track",
                      value: _dailyReminder,
                      onChanged: (v) => setState(() => _dailyReminder = v),
                    ),
                    Divider(color: Theme.of(context).dividerColor),
                    _ToggleRow(
                      title: "Weekly TV Alert",
                      subtitle: "Don't forget to pick the week's show",
                      value: _weeklyAlert,
                      onChanged: (v) => setState(() => _weeklyAlert = v),
                    ),
                    Divider(color: Theme.of(context).dividerColor),
                    _ToggleRow(
                      title: "Yearly Recap Ready",
                      subtitle:
                          "Notify when the week ends and AI recap is generated",
                      value: _yearlyRecap,
                      onChanged: (v) => setState(() => _yearlyRecap = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // Danger Zone
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2B1515)
                      : const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.error, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Danger Zone",
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: AppTheme.spacingMd),
                    OutlinedButton.icon(
                      onPressed: _isStartingNewMachine ? null : _startNewTimeMachine,
                      icon: _isStartingNewMachine
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restart_alt_rounded),
                      label: const Text("Start New Time Machine"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),
                    OutlinedButton.icon(
                      onPressed: _isLeavingGroup ? null : _leaveGroup,
                      icon: _isLeavingGroup
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout),
                      label: const Text("Leave Group"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String role;
  final String initials;
  final Color color;
  final bool isAdmin;

  const _MemberTile({
    required this.name,
    required this.role,
    required this.initials,
    required this.color,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface, width: 2),
            ),
            child: Center(
              child: Text(initials,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(role, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (isAdmin)
            Icon(Icons.more_vert,
                color: Theme.of(context).colorScheme.onSurface),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.secondary,
        ),
      ],
    );
  }
}
