import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:intl/intl.dart';

class ChatRoomScreen extends StatefulWidget {
  final String friendId;

  const ChatRoomScreen({super.key, required this.friendId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  IO.Socket? socket;
  String? authToken;
  String? currentUserId;
  Map<String, dynamic>? friend;
  List<Map<String, dynamic>> messages = [];
  TextEditingController messageController = TextEditingController();
  bool isTyping = false;
  bool friendTyping = false;
  String lastSeen = '';

  @override
  void initState() {
    super.initState();
    initialize();
  }

  String capitalize(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('authToken');

    if (authToken == null) return;

    final userRes = await http.get(
      Uri.parse('http://192.168.8.111:5000/api/me'),
      headers: {'Authorization': 'Bearer $authToken'},
    );
    final userData = json.decode(userRes.body);
    currentUserId = userData['_id'];

    await fetchFriendInfo();
    await fetchMessages();

    connectSocket();
  }

  void connectSocket() {
    socket = IO.io(
      'http://192.168.8.111:5000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'userId': currentUserId})
          .disableAutoConnect()
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      socket!.emit('join', currentUserId);
    });

    socket!.on('receive_message', (data) {
      setState(() {
        messages.add({
          'sender': data['sender'],
          'content': data['content'],
        });
      });
    });

    socket!.on('typing', (_) {
      setState(() => friendTyping = true);
    });

    socket!.on('stopTyping', (_) {
      setState(() => friendTyping = false);
    });

    socket!.on('disconnected', (_) {
      fetchFriendInfo(); 
    });
  }

  Future<void> fetchMessages() async {
    final res = await http.get(
      Uri.parse(
          'http://192.168.8.111:5000/api/messages/${widget.friendId}'),
      headers: {'Authorization': 'Bearer $authToken'},
    );
    final data = json.decode(res.body);
    setState(() => messages = List<Map<String, dynamic>>.from(data['messages']));
  }

  Future<void> fetchFriendInfo() async {
    final res = await http.get(
      Uri.parse('http://192.168.8.111:5000/api/friend/${widget.friendId}'),
      headers: {'Authorization': 'Bearer $authToken'},
    );
    final data = json.decode(res.body);
    setState(() {
      friend = data['friend'];
      if (friend!['lastSeen'] != null) {
        lastSeen = timeAgo(friend!['lastSeen']);
      } else {
        lastSeen = 'Online';
      }
    });
  }

  String timeAgo(String timestamp) {
    final dt = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes == 1) return '1 minute ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours == 1) return '1 hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(dt);
  }

  void sendMessage() {
    final content = messageController.text.trim();
    if (content.isEmpty) return;

    socket!.emit('send_message', {
      'senderId': currentUserId,
      'receiverId': widget.friendId,
      'content': content,
    });

    setState(() {
      messages.add({
        'sender': currentUserId,
        'content': content,
      });
      messageController.clear();
      isTyping = false;
    });

    socket!.emit('stopTyping', {'to': widget.friendId});
  }

  @override
  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (friend == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              capitalize(friend!['username']),
              style: const TextStyle(fontSize: 18, color: Colors.black),
            ),
            Text(
              friendTyping ? 'typing...' : 'Last seen $lastSeen',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message['sender'] == currentUserId;

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.purple[200] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(message['content']),
                  ),
                );
              },
            ),
          ),
          if (friendTyping)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Typing...", style: TextStyle(color: Colors.grey)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    onChanged: (text) {
                      if (!isTyping && text.isNotEmpty) {
                        isTyping = true;
                        socket!.emit('typing', {'to': widget.friendId});
                      } else if (isTyping && text.isEmpty) {
                        isTyping = false;
                        socket!.emit('stopTyping', {'to': widget.friendId});
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.purple),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
