import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WA {
  static const bg = Color(0xFF0B141A);
  static const header = Color(0xFF1F2C34);
  static const bubbleMe = Color(0xFF005C4B);
  static const bubbleThem = Color(0xFF202C33);
  static const text = Color(0xFFE9EDEF);
  static const textDim = Color(0xFF8696A0);
  static const accent = Color(0xFF25D366);
  static const inputBg = Color(0xFF2A3942);
  static const tickRead = Color(0xFF53BDEB);
}

class Message {
  final String from;
  final String text;
  final DateTime ts;
  final bool read;
  Message({required this.from, required this.text, required this.ts, this.read = false});
}

void main() => runApp(const ChatApp());

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: WA.bg,
        colorScheme: const ColorScheme.dark(primary: WA.accent, surface: WA.header),
      ),
      home: const ChatScreen(
        serverUrl: String.fromEnvironment('SERVER', defaultValue: 'ws://10.0.2.2:8765'),
        username: String.fromEnvironment('USERNAME', defaultValue: 'rio'),
        partner: String.fromEnvironment('PARTNER', defaultValue: 'siti'),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String serverUrl;
  final String username;
  final String partner;
  const ChatScreen({super.key, required this.serverUrl, required this.username, required this.partner});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  WebSocketChannel? _channel;
  final List<Message> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _partnerOnline = false;
  bool _partnerTyping = false;
  bool _connected = false;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _input.dispose();
    _scroll.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }

  void _connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(widget.serverUrl));
      _channel!.stream.listen(_onMessage, onDone: _onDone, onError: _onError);
      _channel!.sink.add(jsonEncode({'type': 'auth', 'username': widget.username}));
      setState(() => _connected = true);
    } catch (_) {
      setState(() => _connected = false);
    }
  }

  void _onMessage(dynamic raw) {
    final data = jsonDecode(raw as String);
    final t = data['type'];

    if (t == 'history') {
      setState(() {
        _messages.clear();
        for (final m in data['messages']) {
          _messages.add(Message(
            from: m['sender'],
            text: m['text'],
            ts: DateTime.parse(m['timestamp']).toLocal(),
            read: m['read'] == 1 || m['read'] == true,
          ));
        }
      });
      _scrollDown();
    } else if (t == 'message') {
      setState(() {
        _messages.add(Message(
          from: data['from'],
          text: data['text'],
          ts: DateTime.parse(data['timestamp']).toLocal(),
        ));
      });
      _scrollDown();
      if (data['from'] != widget.username) _sendRead();
    } else if (t == 'status') {
      if (data['user'] == widget.partner) {
        setState(() {
          _partnerOnline = data['online'] == true;
          if (!_partnerOnline) _partnerTyping = false;
        });
      }
    } else if (t == 'online_users') {
      setState(() => _partnerOnline = (data['users'] as List).contains(widget.partner));
    } else if (t == 'typing') {
      if (data['user'] == widget.partner) {
        setState(() => _partnerTyping = data['typing'] == true);
      }
    }
  }

  void _onDone() => setState(() => _connected = false);
  void _onError(Object e) => setState(() => _connected = false);

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _channel == null) return;
    _input.clear();
    _channel!.sink.add(jsonEncode({'type': 'message', 'text': text, 'kind': 'text'}));
    _channel!.sink.add(jsonEncode({'type': 'typing', 'typing': false}));
  }

  void _sendRead() => _channel?.sink.add(jsonEncode({'type': 'read'}));

  void _onTyping(String v) {
    _typingDebounce?.cancel();
    _channel?.sink.add(jsonEncode({'type': 'typing', 'typing': v.isNotEmpty}));
    if (v.isNotEmpty) {
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        _channel?.sink.add(jsonEncode({'type': 'typing', 'typing': false}));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WA.bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildChatList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final initial = widget.partner.isNotEmpty ? widget.partner[0].toUpperCase() : '?';
    final colors = [Colors.purple, Colors.red, Colors.green, Colors.orange,
                    Colors.blue, Colors.pink, Colors.teal];
    final color = colors[widget.partner.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length];
    final status = _partnerTyping
        ? 'sedang mengetik...'
        : (_partnerOnline ? 'online' : 'offline');

    return AppBar(
      backgroundColor: WA.header,
      elevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: WA.text), onPressed: () {}),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 18,
            child: Text(initial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.partner,
                  style: const TextStyle(color: WA.text, fontSize: 16, fontWeight: FontWeight.w500)),
              Text(status,
                  style: TextStyle(
                      color: _partnerTyping ? WA.accent : WA.textDim, fontSize: 12)),
            ],
          ),
        ],
      ),
      actions: const [
        Padding(padding: EdgeInsets.all(12), child: Icon(Icons.videocam, color: WA.text)),
        Padding(padding: EdgeInsets.all(12), child: Icon(Icons.call, color: WA.text)),
        Padding(padding: EdgeInsets.all(12), child: Icon(Icons.more_vert, color: WA.text)),
      ],
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        return _BubbleRow(message: m, isMe: m.from == widget.username);
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: WA.header,
      padding: EdgeInsets.only(
          left: 8, right: 8, top: 6, bottom: 6 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: WA.inputBg, borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: TextField(
                controller: _input,
                onChanged: _onTyping,
                onSubmitted: (_) => _send(),
                style: const TextStyle(color: WA.text),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Ketik pesan...',
                  hintStyle: TextStyle(color: WA.textDim),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: WA.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _send,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleRow extends StatelessWidget {
  final Message message;
  final bool isMe;
  const _BubbleRow({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final h = message.ts.hour.toString().padLeft(2, '0');
    final m = message.ts.minute.toString().padLeft(2, '0');
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: isMe ? WA.bubbleMe : WA.bubbleThem,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(message.text, style: const TextStyle(color: WA.text, fontSize: 15)),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$h:$m', style: const TextStyle(color: WA.textDim, fontSize: 11)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(message.read ? Icons.done_all : Icons.done, size: 14,
                      color: message.read ? WA.tickRead : WA.textDim),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
