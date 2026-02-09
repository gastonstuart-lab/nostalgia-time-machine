import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../state.dart';
import '../nav.dart';
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
        content: const Text('Are you sure you want to leave this group? This action cannot be undone.'),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final group = provider.currentGroup;
    final members = provider.members;
    final isDark = provider.themeMode == ThemeMode.dark;

    if (group == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).iconTheme.color),
          onPressed: () => context.pop(),
        ),
        title: Text("Group Settings", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
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
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2),
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
                        border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2),
                      ),
                      child: Center(
                        child: Icon(Icons.groups_rounded, color: Theme.of(context).colorScheme.onSecondary, size: 40),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Rewind Collective", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          Text("Started at: 1990", style: Theme.of(context).textTheme.bodyMedium),
                          Text("Current Year: ${group.currentYear}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              Text("Invite Friends", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppTheme.spacingSm),
              
              // Invite Code
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2),
                  boxShadow: AppTheme.shadowMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Share this code with your crew to start the time machine together.", style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppTheme.spacingMd),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: group.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied to clipboard!')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.background,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(group.code, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                            Icon(Icons.content_copy_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isGeneratingCode ? null : _generateNewCode,
                            icon: _isGeneratingCode 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: const Text("Generate New Code"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.onSurface,
                              side: BorderSide(color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        OutlinedButton.icon(
                          onPressed: () {
                            Share.share('Join my Rewind crew! Code: ${group.code}');
                          },
                          icon: const Icon(Icons.share_rounded),
                          label: const Text("Share"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.secondary,
                            side: BorderSide(color: Theme.of(context).colorScheme.secondary),
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
                  Text("Time Travelers (${members.length})", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text("See All", style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSm),

              // Members List
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2),
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
                            initials: member.displayName.substring(0, 1).toUpperCase(),
                            color: Color(member.avatarColor),
                            isAdmin: index == 0,
                          ),
                          if (!isLast) Divider(color: Theme.of(context).dividerColor),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              Text("Reminders", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppTheme.spacingSm),
              
              // Reminders
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2),
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
                      subtitle: "Notify when the week ends and AI recap is generated",
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
                  color: isDark ? const Color(0xFF2B1515) : const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: Theme.of(context).colorScheme.error, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Danger Zone", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: AppTheme.spacingMd),
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
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
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
              border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2),
            ),
            child: Center(
              child: Text(initials, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(role, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (isAdmin)
            Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface),
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
              Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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
