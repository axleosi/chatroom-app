import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatHomeScreen extends StatefulWidget {
  const ChatHomeScreen({super.key});

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  List<dynamic> friends = [];
  String message = '';
  bool isLoading = false;
  String searchQuery = '';
  List<dynamic> searchResults = [];
  TextEditingController searchController = TextEditingController();

  String? authToken;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    fetchUserAndFriends();
  }

  String capitalize(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }

  Future<void> fetchUserAndFriends() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('authToken');

    if (authToken == null) return;

    final headers = {'Authorization': 'Bearer $authToken'};

    try {
      final userRes = await http.get(
        Uri.parse('https://chatroom-app-yuao.onrender.com/api/me'),
        headers: headers,
      );
      final userData = json.decode(userRes.body);
      currentUserId = userData['_id'];

      await refreshFriends();
    } catch (e) {
      print('Error fetching user/friends: $e');
    }
  }

  Future<void> refreshFriends() async {
    final headers = {'Authorization': 'Bearer $authToken'};
    try {
      final res = await http.get(
        Uri.parse('https://chatroom-app-yuao.onrender.com/api/friend/list'),
        headers: headers,
      );
      final data = json.decode(res.body);
      setState(() => friends = data['friends']);
    } catch (e) {
      print('Failed to refresh friend list: $e');
    }
  }

  Future<void> handleSearch(String query) async {
    setState(() {
      searchQuery = query;
      message = '';
    });

    if (query.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    try {
      final headers = {'Authorization': 'Bearer $authToken'};
      final res = await http.get(
        Uri.parse('https://chatroom-app-yuao.onrender.com/api/friend/search?query=$query'),
        headers: headers,
      );
      final data = json.decode(res.body);
      setState(() => searchResults = data['results']);
    } catch (e) {
      print('Search error: $e');
    }
  }

  Future<void> handleAddFriend(String username) async {
    final headers = {
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
    };

    try {
      final res = await http.post(
        Uri.parse('https://chatroom-app-yuao.onrender.com/api/friend/add'),
        headers: headers,
        body: json.encode({'usernameToAdd': username}),
      );

      final data = json.decode(res.body);

      setState(() {
        message = data['message'];
        searchQuery = '';
        searchController.clear();
        searchResults = [];
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => message = '');
        }
      });

      await refreshFriends();
    } catch (e) {
      print('Add friend error: $e');
    }
  }

  Future<void> handleRemoveFriend(String username) async {
    final headers = {
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json'
    };

    try {
      await http.post(
        Uri.parse('https://chatroom-app-yuao.onrender.com/api/friend/remove'),
        headers: headers,
        body: json.encode({'usernameToRemove': username}),
      );
      await refreshFriends();
    } catch (e) {
      print('Remove friend error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with a Friend'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => false,
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.black)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: handleSearch,
            ),
            const SizedBox(height: 10),
            if (message.isNotEmpty)
              Text(message, style: const TextStyle(color: Colors.green)),
            if (searchResults.isNotEmpty)
              Column(
                children: searchResults
                    .map((user) => ListTile(
                          title: Text(capitalize(user['username'])),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                            ),
                            onPressed: () => handleAddFriend(user['username']),
                            child: const Text('Add', style: TextStyle(color: Colors.white)),
                          ),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Your Friends',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: friends.isEmpty
                  ? const Text('You have no friends yet.', style: TextStyle(color: Colors.grey))
                  : ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                              friend['avatarUrl'] ??
                                  'https://ui-avatars.com/api/?name=${Uri.encodeComponent(friend['username'])}',
                            ),
                          ),
                          title: Text(capitalize(friend['username'])),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/chat-room',
                            arguments: {'friendId': friend['_id']},
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => handleRemoveFriend(friend['username']),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
