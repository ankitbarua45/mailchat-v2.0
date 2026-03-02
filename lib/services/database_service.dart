import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Search users by username
  Future<List<UserModel>> searchUsers(
    String query,
    String currentUserId,
  ) async {
    try {
      QuerySnapshot snapshot;

      if (query.isEmpty) {
        // Get all users if query is empty
        snapshot = await _firestore.collection('users').limit(100).get();
      } else {
        snapshot = await _firestore
            .collection('users')
            .where('username', isGreaterThanOrEqualTo: query)
            .where('username', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(20)
            .get();
      }

      List<UserModel> users = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .where((user) => user.uid != currentUserId)
          .toList();

      return users;
    } catch (e) {
      return [];
    }
  }

  // Get or create chat between two users
  Future<String> getOrCreateChat(String userId1, String userId2) async {
    try {
      // Check if chat already exists
      QuerySnapshot existingChat = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId1)
          .get();

      for (var doc in existingChat.docs) {
        List<String> participants = List<String>.from(doc['participants']);
        if (participants.contains(userId2)) {
          return doc.id;
        }
      }

      // Create new chat
      String chatId = _uuid.v4();
      ChatModel newChat = ChatModel(
        chatId: chatId,
        participants: [userId1, userId2],
        lastMessage: '',
        lastMessageTime: DateTime.now(),
        lastMessageSenderId: '',
        unreadCount: {userId1: 0, userId2: 0},
      );

      await _firestore.collection('chats').doc(chatId).set(newChat.toMap());
      return chatId;
    } catch (e) {
      throw Exception('Failed to create chat');
    }
  }

  // Send message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    try {
      String messageId = _uuid.v4();
      DateTime now = DateTime.now();

      MessageModel newMessage = MessageModel(
        messageId: messageId,
        senderId: senderId,
        receiverId: receiverId,
        message: message,
        timestamp: now,
        isRead: false,
        chatId: chatId,
      );

      // Add message to messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(newMessage.toMap());

      // Update chat with last message
      DocumentSnapshot chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();
      Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
      Map<String, int> unreadCount = Map<String, int>.from(
        chatData['unreadCount'],
      );

      // Increment unread count for receiver
      unreadCount[receiverId] = (unreadCount[receiverId] ?? 0) + 1;

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': now.toIso8601String(),
        'lastMessageSenderId': senderId,
        'unreadCount': unreadCount,
      });
    } catch (e) {
      throw Exception('Failed to send message');
    }
  }

  // Get messages stream for a chat
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data()))
              .toList();
        });
  }

  // Get user's chats stream
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          List<ChatModel> chats = snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.data()))
              .toList();

          // Sort by last message time
          chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return chats;
        });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // Reset unread count for this user
      DocumentSnapshot chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();
      Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
      Map<String, int> unreadCount = Map<String, int>.from(
        chatData['unreadCount'],
      );
      unreadCount[userId] = 0;

      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount': unreadCount,
      });

      // Mark all messages from other user as read
      QuerySnapshot messages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in messages.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      // Fail silently
    }
  }

  // Get user by ID
  Future<UserModel?> getUser(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get user stream
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  // Update user profile
  Future<bool> updateUserProfile({
    required String userId,
    String? username,
    String? fullName,
    String? bio,
    String? profileImageUrl,
  }) async {
    try {
      Map<String, dynamic> updates = {};

      if (username != null) updates['username'] = username;
      if (fullName != null) updates['fullName'] = fullName;
      if (bio != null) updates['bio'] = bio;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }

      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(
    String username,
    String currentUserId,
  ) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      // Username is available if no docs found or the only doc is current user
      return query.docs.isEmpty ||
          (query.docs.length == 1 && query.docs.first.id == currentUserId);
    } catch (e) {
      return false;
    }
  }

  // Create group chat
  Future<String> createGroupChat({
    required String groupName,
    required List<String> memberIds,
    required String createdBy,
    String? groupImageUrl,
  }) async {
    try {
      String chatId = _uuid.v4();

      // Initialize unread count for all members
      Map<String, int> unreadCount = {};
      for (String memberId in memberIds) {
        unreadCount[memberId] = 0;
      }

      ChatModel newGroupChat = ChatModel(
        chatId: chatId,
        participants: memberIds,
        lastMessage: 'Group created',
        lastMessageTime: DateTime.now(),
        lastMessageSenderId: createdBy,
        unreadCount: unreadCount,
        isGroup: true,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
        createdBy: createdBy,
        admins: [createdBy], // Creator is admin by default
      );

      await _firestore
          .collection('chats')
          .doc(chatId)
          .set(newGroupChat.toMap());
      return chatId;
    } catch (e) {
      throw Exception('Failed to create group chat: $e');
    }
  }

  // Add members to group
  Future<bool> addGroupMembers({
    required String chatId,
    required List<String> memberIds,
  }) async {
    try {
      DocumentSnapshot chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return false;

      ChatModel chat = ChatModel.fromMap(
        chatDoc.data() as Map<String, dynamic>,
      );

      if (!chat.isGroup) return false;

      // Add new members to participants
      List<String> updatedParticipants = List.from(chat.participants);
      Map<String, int> updatedUnreadCount = Map.from(chat.unreadCount);

      for (String memberId in memberIds) {
        if (!updatedParticipants.contains(memberId)) {
          updatedParticipants.add(memberId);
          updatedUnreadCount[memberId] = 0;
        }
      }

      await _firestore.collection('chats').doc(chatId).update({
        'participants': updatedParticipants,
        'unreadCount': updatedUnreadCount,
      });

      return true;
    } catch (e) {
      print('Error adding group members: $e');
      return false;
    }
  }

  // Remove member from group
  Future<bool> removeGroupMember({
    required String chatId,
    required String memberId,
  }) async {
    try {
      DocumentSnapshot chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();

      if (!chatDoc.exists) return false;

      ChatModel chat = ChatModel.fromMap(
        chatDoc.data() as Map<String, dynamic>,
      );

      if (!chat.isGroup) return false;

      // Remove member from participants
      List<String> updatedParticipants = List.from(chat.participants);
      updatedParticipants.remove(memberId);

      Map<String, int> updatedUnreadCount = Map.from(chat.unreadCount);
      updatedUnreadCount.remove(memberId);

      // Remove from admins if present
      List<String> updatedAdmins = List.from(chat.admins);
      updatedAdmins.remove(memberId);

      await _firestore.collection('chats').doc(chatId).update({
        'participants': updatedParticipants,
        'unreadCount': updatedUnreadCount,
        'admins': updatedAdmins,
      });

      return true;
    } catch (e) {
      print('Error removing group member: $e');
      return false;
    }
  }

  // Update group info
  Future<bool> updateGroupInfo({
    required String chatId,
    String? groupName,
    String? groupImageUrl,
  }) async {
    try {
      Map<String, dynamic> updates = {};

      if (groupName != null) updates['groupName'] = groupName;
      if (groupImageUrl != null) updates['groupImageUrl'] = groupImageUrl;

      if (updates.isNotEmpty) {
        await _firestore.collection('chats').doc(chatId).update(updates);
      }

      return true;
    } catch (e) {
      print('Error updating group info: $e');
      return false;
    }
  }

  // Send group message
  Future<void> sendGroupMessage({
    required String chatId,
    required String senderId,
    required String message,
    required List<String> participants,
  }) async {
    try {
      String messageId = _uuid.v4();
      DateTime now = DateTime.now();

      // For group messages, receiverId is empty
      MessageModel newMessage = MessageModel(
        messageId: messageId,
        senderId: senderId,
        receiverId: '', // Empty for group messages
        message: message,
        timestamp: now,
        isRead: false,
        chatId: chatId,
      );

      // Add message to messages subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(newMessage.toMap());

      // Update chat with last message
      DocumentSnapshot chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get();
      Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
      Map<String, int> unreadCount = Map<String, int>.from(
        chatData['unreadCount'],
      );

      // Increment unread count for all participants except sender
      for (String participantId in participants) {
        if (participantId != senderId) {
          unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
        }
      }

      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': now.toIso8601String(),
        'lastMessageSenderId': senderId,
        'unreadCount': unreadCount,
      });
    } catch (e) {
      throw Exception('Failed to send group message: $e');
    }
  }

  // Block a user
  Future<bool> blockUser(String userId, String blockedUserId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'blockedUsers': FieldValue.arrayUnion([blockedUserId]),
      });
      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  // Unblock a user
  Future<bool> unblockUser(String userId, String blockedUserId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'blockedUsers': FieldValue.arrayRemove([blockedUserId]),
      });
      return true;
    } catch (e) {
      print('Error unblocking user: $e');
      return false;
    }
  }

  // Check if a user is blocked
  Future<bool> isUserBlocked(String userId, String checkUserId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        UserModel user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
        return user.blockedUsers.contains(checkUserId);
      }
      return false;
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
  }

  // Get blocked users
  Future<List<UserModel>> getBlockedUsers(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        UserModel user = UserModel.fromMap(doc.data() as Map<String, dynamic>);
        if (user.blockedUsers.isEmpty) {
          return [];
        }

        // Fetch blocked users data
        List<UserModel> blockedUsers = [];
        for (String blockedUserId in user.blockedUsers) {
          UserModel? blockedUser = await getUser(blockedUserId);
          if (blockedUser != null) {
            blockedUsers.add(blockedUser);
          }
        }
        return blockedUsers;
      }
      return [];
    } catch (e) {
      print('Error getting blocked users: $e');
      return [];
    }
  }
}
