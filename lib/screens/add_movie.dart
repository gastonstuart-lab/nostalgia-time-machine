import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:nostalgia_time_machine/components/theme_toggle.dart';
import 'package:nostalgia_time_machine/services/firestore_service.dart';
import 'package:nostalgia_time_machine/state.dart';
import 'package:nostalgia_time_machine/theme.dart';

class AddMovieScreen extends StatefulWidget {
  const AddMovieScreen({super.key});

  @override
  State<AddMovieScreen> createState() => _AddMovieScreenState();
}

class _AddMovieScreenState extends State<AddMovieScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.lightOnSurface, width: 3),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Movie Limit', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Text(
          'You already reached your weekly cap (1/1 movies).',
          style: TextStyle(color: AppTheme.lightPrimaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMovie() async {
    final provider = context.read<NostalgiaProvider>();
    final groupId = provider.currentGroup?.id;
    final weekId = provider.currentWeekId;
    final userId = provider.currentUserId;

    if (groupId == null || weekId == null || userId.isEmpty) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movie title is required.')),
      );
      return;
    }

    final existing =
        await _firestoreService.getMyMoviePickThisWeek(groupId, weekId, userId);
    if (existing != null) {
      _showLimitDialog();
      return;
    }

    final parsedYear = int.tryParse(_yearController.text.trim());

    setState(() => _saving = true);
    try {
      await _firestoreService.addMovie(
        groupId: groupId,
        weekId: weekId,
        title: title,
        year: parsedYear,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movie pick saved!')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('LIMIT_REACHED')) {
        _showLimitDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save movie: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final year =
        context.watch<NostalgiaProvider>().currentGroup?.currentYear ?? 1990;
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Pick a Movie',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
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
              Text(
                'Weekly Movie Pick ($year)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.lightPrimaryText,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Movie title',
                  helperText: 'Required',
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              TextField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  helperText: 'Optional',
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              ElevatedButton(
                onPressed: _saving ? null : _saveMovie,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Movie Pick'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
