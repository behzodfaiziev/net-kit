import 'package:flutter/material.dart';
import 'package:net_kit/net_kit.dart';

import 'models/typicode_comment_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetKit Test App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CommentPage(),
    );
  }
}

class CommentPage extends StatefulWidget {
  const CommentPage({super.key});

  @override
  CommentPageState createState() => CommentPageState();
}

class CommentPageState extends State<CommentPage> {
  final INetKitManager _netKitManager =
      NetKitManager(baseUrl: 'https://jsonplaceholder.typicode.com');
  List<TypicodeCommentModel> _comments = [];

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final comments = await _netKitManager.requestList<TypicodeCommentModel>(
        path: '/comments',
        model: const TypicodeCommentModel(),
        method: RequestMethod.get,
      );
      setState(() {
        _comments = comments;
      });
    } catch (e) {
      /// Handle error
    }
  }

  void _showCreateCommentDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Comment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('nameField'),
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                key: const Key('emailField'),
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('submitButton'),
              onPressed: () {
                final newComment = TypicodeCommentModel(
                  name: nameController.text,
                  email: emailController.text,
                );
                setState(() {
                  _comments.add(newComment);
                });
                Navigator.of(context).pop();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NetKit Test'),
      ),
      body: _comments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                return ListTile(
                  key: Key('comment_${comment.id}'),
                  title: Text(comment.name ?? 'No Name'),
                  subtitle: Text(comment.email ?? 'No Email'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        key: const Key('createCommentButton'),
        onPressed: _showCreateCommentDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
