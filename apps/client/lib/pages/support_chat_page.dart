import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../app_config.dart';
import '../services/auth_service.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _service = AuthService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = const [];
  String? _conversationId;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _online = false;
  PlatformFile? _attachment;
  Timer? _refreshTimer;
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialMessage ?? '';
    _openChat();
  }

  Future<void> _openChat() async {
    try {
      final id = await _service.openSupportConversation();
      _online = await _service.supportOnline();
      _conversationId = id;
      await _refresh();
      _connectRealtime();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _refresh(silent: true),
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectRealtime() async {
    final session = await AuthService().restoreSession();
    if (session == null || session.accessToken.isEmpty) return;
    final socket = io.io(
      '${AppConfig.apiBaseUrl}/support',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setAuth({'token': session.accessToken})
          .disableAutoConnect()
          .build(),
    );
    socket.on('support-update', (value) {
      if (value is Map && value['conversationId'] == _conversationId) {
        _refresh(silent: true);
      }
    });
    socket.connect();
    _socket = socket;
  }

  Future<void> _refresh({bool silent = false}) async {
    final id = _conversationId;
    if (id == null) return;
    try {
      final messages = await _service.fetchSupportMessages(id);
      await _service.markSupportConversationRead(id);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on AuthException catch (error) {
      if (!silent && mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _send() async {
    final id = _conversationId;
    final content = _controller.text.trim();
    if (id == null || (content.isEmpty && _attachment == null) || _sending)
      return;
    setState(() => _sending = true);
    try {
      await _service.sendSupportMessage(
        id,
        content,
        attachmentName: _attachment?.name,
        attachmentType: _attachment?.extension == 'pdf'
            ? 'application/pdf'
            : 'image/${_attachment?.extension ?? 'jpeg'}',
        attachmentBase64: _attachment?.bytes == null
            ? null
            : base64Encode(_attachment!.bytes!),
      );
      _controller.clear();
      _attachment = null;
      await _refresh();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    if ((result.files.first.size) > 8 * 1024 * 1024) {
      setState(() => _error = 'Attachment must be 8 MB or smaller');
      return;
    }
    setState(() => _attachment = result.files.first);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _socket?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Online Customer Service'),
            Text(
              _online ? 'Online' : 'Leave a message',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _online ? Colors.green : null,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Chat with online customer service to add money.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final mine = message['senderType'] == 'CLIENT';
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 290),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? AppConfig.primaryColor
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            [
                              if ((message['content']?.toString() ?? '')
                                  .isNotEmpty)
                                message['content'].toString(),
                              if (message['attachmentName'] != null)
                                '📎 ${message['attachmentName']}',
                            ].join('\n'),
                            style: TextStyle(
                              color: mine
                                  ? Colors.white
                                  : const Color(0xFF172033),
                              height: 1.35,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppConfig.borderColor)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sending ? null : _pickAttachment,
                    icon: Icon(
                      _attachment == null
                          ? Icons.attach_file_rounded
                          : Icons.task_alt_rounded,
                    ),
                    tooltip: _attachment?.name ?? 'Attach image or PDF',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Message online customer service',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
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
