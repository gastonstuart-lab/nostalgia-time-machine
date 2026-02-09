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
                          fact:
                              "The Lion King was the highest-grossing film of $year, and the Sony PlayStation was first released in Japan!",
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
                    decoration: const BoxDecoration(
                      color: AppTheme.lightSurface,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24)),
                      border: Border(
                          top: BorderSide(
                              color: AppTheme.lightDivider, width: 3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingMd),
                            decoration: BoxDecoration(
                              color: AppTheme.lightBackground,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              border: Border.all(
                                  color: AppTheme.lightDivider, width: 2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.psychology,
                                    color: AppTheme.lightSecondaryText,
                                    size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    enabled: !_isSending,
                                    style: const TextStyle(
                                        color: AppTheme.lightPrimaryText),
                                    cursorColor: AppTheme.lightPrimaryText,
                                    decoration: InputDecoration(
                                      hintText: "Ask about $year...",
                                      hintStyle: const TextStyle(
                                          color: AppTheme.lightSecondaryText),
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
  final String fact;

  const _TriviaCard({required this.fact});

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
                "Did you know? - 1994",
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
