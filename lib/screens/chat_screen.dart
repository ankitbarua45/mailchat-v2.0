import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import 'group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel? otherUser; // Nullable for group chats
  final ChatModel? chat; // For group chat info

  const ChatScreen({
    super.key,
    required this.chatId,
    this.otherUser,
    this.chat,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final DatabaseService _databaseService = DatabaseService();
  Map<String, UserModel> _userCache = {}; // Cache for group member info
  bool _isGroupChat = false;

  @override
  void initState() {
    super.initState();
    _isGroupChat = widget.chat?.isGroup ?? false;
    _markMessagesAsRead();
    if (_isGroupChat) {
      _loadGroupMembers();
    }
  }

  Future<void> _loadGroupMembers() async {
    if (widget.chat == null) return;

    for (String userId in widget.chat!.participants) {
      UserModel? user = await _databaseService.getUser(userId);
      if (user != null) {
        setState(() {
          _userCache[userId] = user;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid ?? '';
    await _databaseService.markMessagesAsRead(widget.chatId, currentUserId);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid ?? '';
    final messageText = _messageController.text.trim();

    _messageController.clear();

    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      if (_isGroupChat && widget.chat != null) {
        // Send group message
        await _databaseService.sendGroupMessage(
          chatId: widget.chatId,
          senderId: currentUserId,
          message: messageText,
          participants: widget.chat!.participants,
        );
      } else {
        // Send one-to-one message
        await _databaseService.sendMessage(
          chatId: widget.chatId,
          senderId: currentUserId,
          receiverId: widget.otherUser!.uid,
          message: messageText,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(timestamp)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(timestamp);
    }
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    // Get sender name for group messages
    String? senderName;
    if (_isGroupChat && !isMe) {
      UserModel? sender = _userCache[message.senderId];
      senderName = sender?.fullName ?? sender?.username ?? 'Unknown';
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isMe ? 0.15 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show sender name for group messages
            if (senderName != null) ...[
              Text(
                senderName,
                style: const TextStyle(
                  color: Color(0xFF1E88E5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              message.message,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF2C3E50),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withOpacity(0.85)
                        : Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 16,
                    color: message.isRead
                        ? Colors.white
                        : Colors.white.withOpacity(0.85),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isGroupChat
            ? Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chat?.groupName ?? 'Group Chat',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          '${widget.chat?.participants.length ?? 0} participants',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : StreamBuilder<UserModel?>(
                stream: _databaseService.getUserStream(widget.otherUser!.uid),
                builder: (context, snapshot) {
                  final user = snapshot.data ?? widget.otherUser!;
                  return Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                user.username[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (user.isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.username,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            Text(
                              user.isOnline
                                  ? 'Online'
                                  : user.lastSeen != null
                                  ? 'Last seen ${_formatTimestamp(user.lastSeen!)}'
                                  : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                color: user.isOnline
                                    ? Colors.green
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
        actions: _isGroupChat && widget.chat != null
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF2C3E50),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GroupInfoScreen(chat: widget.chat!),
                        ),
                      );
                    },
                  ),
                ),
              ]
            : widget.otherUser != null
            ? [
                StreamBuilder<UserModel?>(
                  stream: _databaseService.getUserStream(currentUserId),
                  builder: (context, snapshot) {
                    final currentUser = snapshot.data;
                    final isBlocked =
                        currentUser?.blockedUsers.contains(
                          widget.otherUser!.uid,
                        ) ??
                        false;

                    return PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Color(0xFF2C3E50),
                      ),
                      offset: const Offset(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(
                                isBlocked
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.block_rounded,
                                color: isBlocked
                                    ? Colors.green
                                    : Colors.red[700],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isBlocked ? 'Unblock User' : 'Block User',
                                style: TextStyle(
                                  color: isBlocked
                                      ? Colors.green
                                      : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'block') {
                          if (isBlocked) {
                            // Unblock user
                            bool success = await _databaseService.unblockUser(
                              currentUserId,
                              widget.otherUser!.uid,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'User unblocked successfully'
                                        : 'Failed to unblock user',
                                  ),
                                  backgroundColor: success
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              );
                            }
                          } else {
                            // Block user
                            bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text('Block User?'),
                                content: Text(
                                  'Are you sure you want to block ${widget.otherUser!.username}? You won\'t receive messages from them.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[700],
                                    ),
                                    child: const Text('Block'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              bool success = await _databaseService.blockUser(
                                currentUserId,
                                widget.otherUser!.uid,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'User blocked successfully'
                                          : 'Failed to block user',
                                    ),
                                    backgroundColor: success
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        }
                      },
                    );
                  },
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _databaseService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Something went wrong',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to start the conversation',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                // Group messages by date
                Map<String, List<MessageModel>> messagesByDate = {};
                for (var message in messages) {
                  String dateKey = DateFormat(
                    'yyyy-MM-dd',
                  ).format(message.timestamp);
                  if (!messagesByDate.containsKey(dateKey)) {
                    messagesByDate[dateKey] = [];
                  }
                  messagesByDate[dateKey]!.add(message);
                }

                List<Widget> messageWidgets = [];
                List<String> sortedDates = messagesByDate.keys.toList()
                  ..sort(
                    (a, b) => a.compareTo(b),
                  ); // Chronological order (oldest first)

                for (String dateKey in sortedDates) {
                  // Date divider removed for cleaner UI
                  // messageWidgets.add(_buildDateDivider(date));

                  List<MessageModel> dateMessages = messagesByDate[dateKey]!;
                  // Sort messages within date chronologically (oldest first)
                  dateMessages.sort(
                    (a, b) => a.timestamp.compareTo(b.timestamp),
                  );

                  for (var message in dateMessages) {
                    bool isMe = message.senderId == currentUserId;
                    messageWidgets.add(_buildMessageBubble(message, isMe));
                  }
                }

                // Auto-scroll to bottom after messages load
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: messageWidgets,
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E88E5).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
