import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../providers/auth_provider.dart' as auth;

class GroupInfoScreen extends StatefulWidget {
  final ChatModel chat;

  const GroupInfoScreen({Key? key, required this.chat}) : super(key: key);

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _groupNameController = TextEditingController();

  bool _isLoading = false;
  bool _isEditingName = false;
  List<UserModel> _members = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _groupNameController.text = widget.chat.groupName ?? '';
    _loadMembers();
    _checkIfAdmin();
  }

  void _checkIfAdmin() {
    final currentUser = Provider.of<auth.AuthProvider>(
      context,
      listen: false,
    ).currentUser;
    if (currentUser != null) {
      setState(() {
        _isAdmin = widget.chat.admins.contains(currentUser.uid);
      });
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);

    try {
      List<UserModel> members = [];
      for (String userId in widget.chat.participants) {
        UserModel? user = await _databaseService.getUser(userId);
        if (user != null) {
          members.add(user);
        }
      }

      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
      }
    }
  }

  Future<void> _updateGroupName() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      bool success = await _databaseService.updateGroupInfo(
        chatId: widget.chat.chatId,
        groupName: _groupNameController.text.trim(),
      );

      setState(() {
        _isLoading = false;
        _isEditingName = false;
      });

      if (success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Group name updated')));
        Navigator.pop(context, true); // Return true to indicate update
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating group name: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(String userId) async {
    final currentUser = Provider.of<auth.AuthProvider>(
      context,
      listen: false,
    ).currentUser;

    if (currentUser == null) return;

    // Cannot remove the creator
    if (userId == widget.chat.createdBy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove group creator')),
      );
      return;
    }

    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      bool success = await _databaseService.removeGroupMember(
        chatId: widget.chat.chatId,
        memberId: userId,
      );

      if (success) {
        await _loadMembers(); // Reload members list
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Member removed')));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing member: $e')));
      }
    }
  }

  Future<void> _addMembers() async {
    // Navigate to user selection screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AddMembersScreen(
          currentMembers: widget.chat.participants,
          chatId: widget.chat.chatId,
        ),
      ),
    );

    if (result == true) {
      await _loadMembers(); // Reload members
    }
  }

  Future<void> _leaveGroup() async {
    final currentUser = Provider.of<auth.AuthProvider>(
      context,
      listen: false,
    ).currentUser;

    if (currentUser == null) return;

    // Creator cannot leave
    if (currentUser.uid == widget.chat.createdBy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group creator cannot leave the group')),
      );
      return;
    }

    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      bool success = await _databaseService.removeGroupMember(
        chatId: widget.chat.chatId,
        memberId: currentUser.uid,
      );

      if (success && mounted) {
        Navigator.pop(context, true); // Go back to chat list
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('You left the group')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error leaving group: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<auth.AuthProvider>(context).currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Group Info',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          if (_isEditingName && _isAdmin)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.check_rounded, color: Colors.white),
                onPressed: _isLoading ? null : _updateGroupName,
              ),
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Group Header
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                        child: Column(
                          children: [
                            // Group Icon
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: widget.chat.groupImageUrl != null
                                    ? Image.network(
                                        widget.chat.groupImageUrl!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF1E88E5),
                                              Color(0xFF26C6DA),
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.group_rounded,
                                          size: 60,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Group Name
                            if (_isEditingName && _isAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: TextField(
                                  controller: _groupNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Group Name',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  autofocus: true,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      widget.chat.groupName ?? 'Unnamed Group',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (_isAdmin)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      decoration: const BoxDecoration(
                                        color: Colors.white24,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          setState(() => _isEditingName = true);
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 12),

                            // Participant count
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${widget.chat.participants.length} participants',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Add Members Button (only for admins)
                  if (_isAdmin)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E88E5).withOpacity(0.1),
                            const Color(0xFF26C6DA).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            color: Colors.white,
                          ),
                        ),
                        title: const Text(
                          'Add Members',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF1E88E5),
                        ),
                        onTap: _addMembers,
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Members List Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people_rounded,
                          color: Color(0xFF1E88E5),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Members (${_members.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Members List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final isCreator = member.uid == widget.chat.createdBy;
                      final isAdminMember = widget.chat.admins.contains(
                        member.uid,
                      );
                      final isCurrentUser = member.uid == currentUser?.uid;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: member.profileImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      member.profileImageUrl!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      member.username[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member.fullName ?? member.username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ),
                              if (isCurrentUser)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    ' (You)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                if (isCreator || isAdminMember)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF1E88E5),
                                          Color(0xFF26C6DA),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isCreator ? 'Creator' : 'Admin',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '@${member.username}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          trailing: _isAdmin && !isCurrentUser && !isCreator
                              ? Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _removeMember(member.uid),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Leave Group Button
                  if (currentUser?.uid != widget.chat.createdBy)
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.redAccent],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _leaveGroup,
                        icon: const Icon(Icons.exit_to_app_rounded),
                        label: const Text(
                          'Leave Group',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.all(16),
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
}

// Helper screen for adding members
class _AddMembersScreen extends StatefulWidget {
  final List<String> currentMembers;
  final String chatId;

  const _AddMembersScreen({required this.currentMembers, required this.chatId});

  @override
  State<_AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<_AddMembersScreen> {
  final DatabaseService _databaseService = DatabaseService();

  List<UserModel> _recentUsers = [];
  Set<String> _selectedUserIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentChatUsers();
  }

  Future<void> _loadRecentChatUsers() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = Provider.of<auth.AuthProvider>(
        context,
        listen: false,
      ).currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get user's chats
      final chatsSnapshot = await _databaseService
          .getUserChats(currentUser.uid)
          .first;

      // Extract unique user IDs from chats (excluding current members)
      Set<String> userIds = {};
      for (var chat in chatsSnapshot) {
        for (var participantId in chat.participants) {
          if (participantId != currentUser.uid &&
              !widget.currentMembers.contains(participantId)) {
            userIds.add(participantId);
          }
        }
      }

      // Load user details
      List<UserModel> users = [];
      for (String userId in userIds) {
        // Skip blocked users
        if (currentUser.blockedUsers.contains(userId)) continue;

        UserModel? user = await _databaseService.getUser(userId);
        if (user != null) {
          // Skip users who have blocked the current user
          if (user.blockedUsers.contains(currentUser.uid)) continue;
          users.add(user);
        }
      }

      setState(() {
        _recentUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      bool success = await _databaseService.addGroupMembers(
        chatId: widget.chatId,
        memberIds: _selectedUserIds.toList(),
      );

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Members added successfully')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding members: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Members'),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: _isLoading ? null : _addSelectedMembers,
              child: const Text('ADD', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Selected count
          if (_selectedUserIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.withOpacity(0.1),
              child: Text(
                '${_selectedUserIds.length} member${_selectedUserIds.length > 1 ? 's' : ''} selected',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Section header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Recent Chats (not in group)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recentUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_disabled,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All your recent chats are already in this group',
                          style: TextStyle(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _recentUsers.length,
                    itemBuilder: (context, index) {
                      final user = _recentUsers[index];
                      final isSelected = _selectedUserIds.contains(user.uid);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.profileImageUrl != null
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                          child: user.profileImageUrl == null
                              ? Text(user.username[0].toUpperCase())
                              : null,
                        ),
                        title: Text(user.fullName ?? user.username),
                        subtitle: Text('@${user.username}'),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedUserIds.add(user.uid);
                              } else {
                                _selectedUserIds.remove(user.uid);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedUserIds.remove(user.uid);
                            } else {
                              _selectedUserIds.add(user.uid);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
