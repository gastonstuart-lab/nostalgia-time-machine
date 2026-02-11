import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:nostalgia_time_machine/theme.dart';
import 'package:nostalgia_time_machine/state.dart';
import 'package:nostalgia_time_machine/services/firestore_service.dart';
import 'package:nostalgia_time_machine/services/chat_service.dart';
import 'package:nostalgia_time_machine/models/chat_message.dart';

class NostalgiaAssistantScreen extends StatefulWidget {
  const NostalgiaAssistantScreen({super.key});

  @override
  State<NostalgiaAssistantScreen> createState() =>
      _NostalgiaAssistantScreenState();
}

class _NostalgiaAssistantScreenState extends State<NostalgiaAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();
  final ChatService _chatService = ChatService();

  String? _sessionId;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  List<ChatMessage> _messages = [];
  bool _isInitializing = true;
  bool _isSending = false;
  static const Map<int, String> _yearTrivia = {
    1980: 'Pac-Man became a global arcade phenomenon in 1980.',
    1981: 'MTV launched in 1981 and quickly reshaped music culture.',
    1982: 'Michael Jackson released "Thriller" in 1982.',
    1983: 'CDs started gaining mainstream traction in 1983.',
    1984: '"Like a Virgin" helped define pop music in 1984.',
    1985: 'Live Aid took place in 1985 with globally watched performances.',
    1986: 'Top Gun helped soundtrack-driven pop culture explode in 1986.',
    1987: 'Synth-pop and stadium rock were dominant in 1987 charts.',
    1988: 'The late 80s saw hip-hop become more mainstream by 1988.',
    1989: 'Nintendo Game Boy launched in 1989.',
    1990: '90s pop and alternative sounds started breaking through in 1990.',
    1991: 'Nirvana\'s "Nevermind" arrived in 1991 and changed rock radio.',
    1992: 'The Bodyguard soundtrack became one of the era\'s biggest sellers.',
    1993: '"Jurassic Park" was one of 1993\'s defining blockbusters.',
    1994: '"The Lion King" was the highest-grossing film of 1994.',
    1995: 'The Sony PlayStation launched in North America in 1995.',
    1996: 'The Spice Girls\' "Wannabe" became a global pop anthem in 1996.',
    1997: '"Titanic" became a major global phenomenon in 1997.',
    1998: 'Britney Spears\' "...Baby One More Time" debuted in 1998.',
    1999: 'The Y2K era heavily shaped late-90s pop culture in 1999.',
    2000: 'The new millennium accelerated digital music adoption in 2000.',
  };

  String _triviaForYear(int year) {
    return _yearTrivia[year] ??
        'Every region had different chart leaders in $year. Ask for US or UK top songs, TV hits, or major pop-culture moments.';
  }

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final provider = context.read<NostalgiaProvider>();
    final groupId = provider.currentGroup?.id;
    final userUid = provider.currentUserId;

    if (groupId == null) {
      debugPrint('❌ No active group');
      setState(() => _isInitializing = false);
      return;
    }

    try {
      // STEP 2: Ensure default session exists on screen load
      final sessionId = await _firestoreService.getOrCreateChatSession(groupId,
          createdByUid: userUid);
      setState(() => _sessionId = sessionId);

      // Listen to messages in real-time
      _messagesSubscription = _firestoreService
          .streamChatMessages(groupId, sessionId)
          .listen((messages) {
        setState(() {
          _messages = messages;
          _isInitializing = false;
        });
        _scrollToBottom();
      });

      // Add welcome message if this is a new session
      if (_messages.isEmpty) {
        final year = provider.currentGroup?.currentYear ?? 1990;
        await _firestoreService.addChatMessage(
          groupId: groupId,
          sessionId: sessionId,
          text:
              "Hey there! I'm your time-traveling guide for $year. Need help finding that perfect song or classic TV episode?",
          senderType: 'assistant',
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize chat: $e');
      setState(() => _isInitializing = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isSending) return;

    final provider = context.read<NostalgiaProvider>();
    final groupId = provider.currentGroup?.id;
    final userUid = provider.currentUserId;
    final year = provider.currentGroup?.currentYear ?? 1990;

    // STEP 3: Fail-safe validation
    if (groupId == null) {
      debugPrint('❌ Missing groupId');
      _showError('Error: No active group. Please rejoin or create a group.');
      return;
    }

    final userMessage = _controller.text.trim();
    _controller.clear();

    setState(() => _isSending = true);

    try {
      // STEP 3: Use default session and ensure it exists
      const sessionId = 'default';

      // Write user message to Firestore (session will be auto-created if missing)
      await _firestoreService.addChatMessage(
        groupId: groupId,
        sessionId: sessionId,
        text: userMessage,
        senderType: 'user',
        userUid: userUid,
        status: 'sent',
      );

      // Update local sessionId if needed
      if (_sessionId != sessionId) {
        setState(() => _sessionId = sessionId);
      }

      _scrollToBottom();

      // Process message and wait for assistant response so loading state is accurate.
      await _chatService
          .processUserMessage(
        groupId: groupId,
        sessionId: sessionId,
        userMessage: userMessage,
        userUid: userUid,
        year: year,
      )
          .catchError((e) {
        debugPrint('❌ AI response failed: $e');
        _showError('AI assistant is temporarily unavailable.');
      });
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');
      _showError('Failed to send message. Please check your connection.');
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _formatTime(DateTime time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final group = context.watch<NostalgiaProvider>().currentGroup;
    final year = group?.currentYear ?? 1990;

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.lightOnPrimary),
          onPressed: () => context.pop(),
        ),
        backgroundColor: AppTheme.lightPrimary,
        title: Column(
          children: [
            Text("Nostalgia Assistant",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.lightOnPrimary,
                    fontWeight: FontWeight.bold)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppTheme.lightSuccess, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text("Online: $year Mode",
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppTheme.lightOnPrimary)),
              ],
            ),
          ],
        ),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppTheme.spacingLg),
                      children: [
                        _TriviaCard(
                          year: year,
                          fact: _triviaForYear(year),
                        ),
                        ..._messages.map((msg) => _ChatBubble(
                              message: msg,
                              formatTime: _formatTime,
                              onCopy: () {
                                Clipboard.setData(
                                    ClipboardData(text: msg.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Copied message')),
                                );
                              },
                            )),
                        if (_isSending)
                          Container(
                            margin: const EdgeInsets.only(
                                bottom: AppTheme.spacingLg),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightAccent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                      child: Text("AI",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                ),
                                const SizedBox(width: AppTheme.spacingMd),
                                Container(
                                  padding:
                                      const EdgeInsets.all(AppTheme.spacingMd),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightSurface,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusLg),
                                    border: Border.all(
                                        color: AppTheme.lightDivider, width: 2),
                                  ),
                                  child: SizedBox(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                        const SizedBox(
                                            width: AppTheme.spacingSm),
                                        const Text('Thinking...'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Input Area
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingLg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24)),
                      border: Border(
                          top: BorderSide(
                              color: theme.dividerColor, width: 3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingMd),
                            decoration: BoxDecoration(
                              color: theme.scaffoldBackgroundColor,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              border: Border.all(
                                  color: theme.dividerColor, width: 2),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.psychology,
                                    color: isDark
                                        ? AppTheme.darkSecondaryText
                                        : AppTheme.lightSecondaryText,
                                    size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    enabled: !_isSending,
                                    style: TextStyle(
                                        color: isDark
                                            ? AppTheme.darkPrimaryText
                                            : AppTheme.lightPrimaryText),
                                    cursorColor: isDark
                                        ? AppTheme.darkPrimaryText
                                        : AppTheme.lightPrimaryText,
                                    decoration: InputDecoration(
                                      hintText: "Ask about $year...",
                                      hintStyle: TextStyle(
                                          color: isDark
                                              ? AppTheme.darkSecondaryText
                                              : AppTheme.lightSecondaryText),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMd),
                        GestureDetector(
                          onTap: _isSending ? null : _sendMessage,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _isSending
                                  ? AppTheme.lightDivider
                                  : AppTheme.lightAccent,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              border: Border.all(
                                  color: _isSending
                                      ? AppTheme.lightDivider
                                      : const Color(0xFFB47B1A),
                                  width: 2),
                            ),
                            child: Icon(Icons.send_rounded,
                                color: _isSending
                                    ? AppTheme.lightSecondaryText
                                    : AppTheme.lightOnSurface,
                                size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String Function(DateTime) formatTime;
  final VoidCallback onCopy;

  const _ChatBubble({
    required this.message,
    required this.formatTime,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.senderType == 'user';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingLg),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.lightAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                  child: Text("AI",
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: AppTheme.spacingMd),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppTheme.lightPrimary
                            : AppTheme.lightSurface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                          color: isUser
                              ? const Color(0xFF8B3A01)
                              : AppTheme.lightDivider,
                          width: 2,
                        ),
                        boxShadow: AppTheme.shadowSm,
                      ),
                      child: SelectableText(
                        message.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isUser
                                  ? AppTheme.lightOnPrimary
                                  : AppTheme.lightPrimaryText,
                            ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onCopy,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF8B3A01)
                                : AppTheme.lightDivider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: isUser
                                ? AppTheme.lightOnPrimary
                                : AppTheme.lightSecondaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formatTime(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.lightSecondaryText,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TriviaCard extends StatelessWidget {
  final int year;
  final String fact;

  const _TriviaCard({required this.year, required this.fact});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingLg),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9EF),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.lightAccent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: AppTheme.lightAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                "Did you know? - $year",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.lightOnSurface,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            fact,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightOnSurface,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
