import 'package:clinic_web_dashboard/constants/app_constants.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';
import 'encryption_service.dart';

class DoctorChatScreen extends StatefulWidget {
  final String chatId;
  final String doctorId;
  final String userId;
  final String userName;
  final String encryptionKey;

  const DoctorChatScreen({
    super.key,
    required this.chatId,
    required this.doctorId,
    required this.userId,
    required this.userName,
    required this.encryptionKey,
  });

  @override
  State<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isTyping = ValueNotifier<bool>(false);

  bool _isSending = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _markMessagesAsRead();

    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _animationController.dispose();
    _isTyping.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.atEdge && _scrollController.position.pixels == 0) {
      _markMessagesAsRead();
    }
  }

  void _markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsRead(widget.chatId, widget.doctorId);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();
    _isTyping.value = false;

    HapticFeedback.lightImpact();

    try {
      await _chatService.sendMessage(
        widget.chatId,
        widget.doctorId,
        'doctor',
        text,
      );
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackBar('Failed to send message. Please try again.');
      _messageController.text = text;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatMessageTime(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return '${DateFormat('dd/MM').format(dateTime)} ${DateFormat('HH:mm').format(dateTime)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessageList()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = _getAvatarColors(widget.userName);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: GoogleFonts.inter(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
                StreamBuilder<Map<String, bool>>(
                  stream: _chatService.getTypingStatus(widget.chatId, widget.doctorId),
                  builder: (context, snapshot) {
                    final isOtherTyping = snapshot.data?[widget.userId] ?? false;
                    return Text(
                      isOtherTyping ? 'Typing...' : 'Patient',
                      style: GoogleFonts.inter(
                        color: isOtherTyping ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            onSelected: (value) async {
              if (value == 'clear') {
                await _chatService.clearChat(widget.chatId);
              } else if (value == 'delete') {
                await _chatService.deleteChat(widget.chatId);
                if (mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear chat')),
              PopupMenuItem(value: 'delete', child: Text('Delete chat')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection(Collections.chats).doc(widget.chatId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return _buildEmptyState();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);

        if (messages.isEmpty) {
          return _buildEmptyState();
        }
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length + (messages.isNotEmpty ? messages.length - 1 : 0),
            itemBuilder: (context, index) {
              if (index.isOdd) {
                final msgIndex = (index ~/ 2);
                final msg = messages[messages.length - 1 - msgIndex];
                final showTimestamp = _shouldShowTimestamp(messages, msgIndex);
                if (showTimestamp) {
                  return _buildTimestamp(msg['timestamp']);
                }
                return const SizedBox.shrink();
              }

              final msgIndex = index ~/ 2;
              final message = messages[messages.length - 1 - msgIndex];
              return MessageBubble(
                key: ValueKey(message['messageId']),
                message: message,
                encryptionKey: widget.encryptionKey,
                currentUserId: widget.doctorId,
                otherUserName: widget.userName,
                formatMessageTime: _formatMessageTime,
              );
            },
          ),
        );
      },
    );
  }

  bool _shouldShowTimestamp(List<Map<String, dynamic>> messages, int index) {
    if (index == messages.length - 1) return true;

    final currentMsg = messages[messages.length - 1 - index];
    final nextMsg = messages[messages.length - 2 - index];

    final currentTime = (currentMsg['timestamp'] as Timestamp).toDate();
    final nextTime = (nextMsg['timestamp'] as Timestamp).toDate();

    return currentTime.difference(nextTime).inMinutes > 15;
  }

  Widget _buildTimestamp(Timestamp timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        _formatMessageTime(timestamp),
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: true,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (text) {
                    _isTyping.value = text.trim().isNotEmpty;
                    _chatService.updateTypingStatus(widget.chatId, widget.doctorId, _isTyping.value);
                  },
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder<bool>(
              valueListenable: _isTyping,
              builder: (context, isTyping, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: isTyping ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isTyping && !_isSending ? _sendMessage : null,
                      child: Center(
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: isTyping ? Colors.white : AppColors.textSecondary,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Start the conversation',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Send a message to begin chatting with ${widget.userName}',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Color> _getAvatarColors(String name) {
    const colorPairs = [
      [Color(0xFF3B82F6), Color(0xFF2563EB)],
      [Color(0xFFA855F7), Color(0xFF7C3AED)],
      [Color(0xFF22C55E), Color(0xFF16A34A)],
      [Color(0xFFF97316), Color(0xFFEA580C)],
      [Color(0xFFEC4899), Color(0xFFDB2777)],
      [Color(0xFF14B8A6), Color(0xFF0D9488)],
      [Color(0xFF6366F1), Color(0xFF4F46E5)],
      [Color(0xFFEF4444), Color(0xFFDC2626)],
    ];

    final index = name.hashCode % colorPairs.length;
    return colorPairs[index.abs()];
  }
}

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final String encryptionKey;
  final String currentUserId;
  final String otherUserName;
  final String Function(Timestamp) formatMessageTime;

  const MessageBubble({
    super.key,
    required this.message,
    required this.encryptionKey,
    required this.currentUserId,
    required this.otherUserName,
    required this.formatMessageTime,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message['senderId'] == currentUserId;
    String content;
    try {
      content = EncryptionService.decryptMessage(
        message['encryptedContent'] ?? '',
        encryptionKey,
      );
    } catch (e) {
      debugPrint('Decryption error: $e, Message: ${message['encryptedContent']}');
      content = 'Error decrypting message: $e';
    }

    final colors = _getAvatarColors(isMe ? 'Doctor' : otherUserName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                border: isMe ? null : Border.all(color: AppColors.border),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content,
                    style: GoogleFonts.inter(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatMessageTime(message['timestamp']),
                        style: GoogleFonts.inter(
                          color: isMe ? Colors.white70 : AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      if (isMe && message['isRead'] == true) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done_all_rounded, size: 12, color: Colors.white70),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('D', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Color> _getAvatarColors(String name) {
    const colorPairs = [
      [Color(0xFF3B82F6), Color(0xFF2563EB)],
      [Color(0xFFA855F7), Color(0xFF7C3AED)],
      [Color(0xFF22C55E), Color(0xFF16A34A)],
      [Color(0xFFF97316), Color(0xFFEA580C)],
      [Color(0xFFEC4899), Color(0xFFDB2777)],
      [Color(0xFF14B8A6), Color(0xFF0D9488)],
      [Color(0xFF6366F1), Color(0xFF4F46E5)],
      [Color(0xFFEF4444), Color(0xFFDC2626)],
    ];

    final index = name.hashCode % colorPairs.length;
    return colorPairs[index.abs()];
  }
}
