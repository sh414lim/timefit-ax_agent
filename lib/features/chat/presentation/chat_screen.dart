import 'package:flutter/material.dart';

import '../application/chat_connection_controller.dart';
import '../application/composer_controller.dart';
import '../application/history_controller.dart';
import '../domain/chat_message.dart';
import '../domain/repositories/message_repository.dart';
import 'widgets/chat_composer.dart';
import 'widgets/connection_banner.dart';
import 'widgets/message_list.dart';

enum ChatScreenStatus { ready, error, accessRevoked }

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.title,
    required this.messages,
    this.conversationId,
    this.status = ChatScreenStatus.ready,
    this.scrollController,
    this.composerController,
    this.historyController,
    this.onBack,
    this.onAddAttachment,
    this.onRemoveQueuedAttachment,
    this.onOpenAttachment,
    this.isSelectingAttachments = false,
    this.compactKeyboardLayout = false,
    this.savesLocallyOnly = false,
    this.connectionController,
    super.key,
  }) : repository = null;

  const ChatScreen.repository({
    required this.title,
    required MessageRepository this.repository,
    required String this.conversationId,
    this.status = ChatScreenStatus.ready,
    this.scrollController,
    this.composerController,
    this.historyController,
    this.onBack,
    this.onAddAttachment,
    this.onRemoveQueuedAttachment,
    this.onOpenAttachment,
    this.isSelectingAttachments = false,
    this.compactKeyboardLayout = false,
    this.savesLocallyOnly = false,
    this.connectionController,
    super.key,
  }) : messages = null;

  final String title;
  final Stream<List<ChatMessage>>? messages;
  final MessageRepository? repository;
  final String? conversationId;
  final ChatScreenStatus status;
  final ScrollController? scrollController;
  final ComposerController? composerController;
  final HistoryController? historyController;
  final VoidCallback? onBack;
  final VoidCallback? onAddAttachment;
  final Future<void> Function(String localId)? onRemoveQueuedAttachment;
  final void Function(String localId)? onOpenAttachment;
  final bool isSelectingAttachments;
  final bool compactKeyboardLayout;
  final bool savesLocallyOnly;
  final ChatConnectionController? connectionController;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Stream<List<ChatMessage>> _messages = _resolveMessages();
  HistoryController? _historyController;
  ChatConnectionController? _connectionController;

  @override
  void initState() {
    super.initState();
    _bindHistoryController();
    _bindConnectionController();
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages != widget.messages ||
        oldWidget.repository != widget.repository ||
        oldWidget.conversationId != widget.conversationId) {
      _messages = _resolveMessages();
    }
    if (oldWidget.historyController != widget.historyController) {
      _bindHistoryController();
    }
    if (oldWidget.connectionController != widget.connectionController) {
      _bindConnectionController();
    }
  }

  void _bindHistoryController() {
    _historyController?.removeListener(_handleHistoryState);
    _historyController = widget.historyController;
    _historyController?.addListener(_handleHistoryState);
  }

  void _handleHistoryState(HistoryState _) {
    if (mounted) setState(() {});
  }

  void _bindConnectionController() {
    _connectionController?.removeListener(_handleConnectionState);
    _connectionController = widget.connectionController;
    _connectionController?.addListener(_handleConnectionState);
  }

  void _handleConnectionState(ChatConnectionState _) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _historyController?.removeListener(_handleHistoryState);
    _connectionController?.removeListener(_handleConnectionState);
    super.dispose();
  }

  Stream<List<ChatMessage>> _resolveMessages() {
    if (widget.messages case final Stream<List<ChatMessage>> messages) {
      return messages;
    }
    return widget.repository!.watchCachedMessages(widget.conversationId!);
  }

  @override
  Widget build(BuildContext context) {
    final ComposerController? composer = _matchingComposer;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: widget.compactKeyboardLayout ? 48 : null,
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (_connectionController case final controller?)
              ConnectionBanner(
                state: controller.state,
                onRetry: () => controller.retry(),
              ),
            Expanded(child: _buildBody()),
            if (widget.status == ChatScreenStatus.ready && composer != null)
              ChatComposer(
                controller: composer,
                onAddAttachment: widget.onAddAttachment,
                onRemoveQueuedAttachment: widget.onRemoveQueuedAttachment,
                onOpenAttachment: widget.onOpenAttachment,
                isSelectingAttachments: widget.isSelectingAttachments,
                compactKeyboardLayout: widget.compactKeyboardLayout,
                savesLocallyOnly: widget.savesLocallyOnly,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.status == ChatScreenStatus.accessRevoked) {
      return const _ChatState(
        title: '대화에 접근할 수 없습니다',
        message: '대화 접근 권한이 변경되었습니다.',
      );
    }
    if (widget.status == ChatScreenStatus.error) {
      return const _ChatState(
        title: '메시지를 표시하지 못했습니다',
        message: '잠시 후 다시 시도해 주세요.',
      );
    }
    return StreamBuilder<List<ChatMessage>>(
      stream: _messages,
      builder:
          (BuildContext context, AsyncSnapshot<List<ChatMessage>> snapshot) {
            if (snapshot.hasError) {
              return const _ChatState(
                title: '메시지를 표시하지 못했습니다',
                message: '저장된 메시지 스트림을 확인해 주세요.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<ChatMessage> ordered = _ordered(snapshot.requireData);
            if (ordered.isEmpty) {
              return const _ChatState(
                title: '아직 메시지가 없습니다',
                message: '이 대화의 첫 메시지를 기다리고 있습니다.',
              );
            }
            return MessageList(
              key: ValueKey<String>(
                'message-list-${widget.conversationId ?? 'direct'}',
              ),
              messages: ordered,
              scrollController: widget.scrollController,
              onRetry: _matchingComposer?.retry,
              historyState: _matchingHistory?.state,
              onTopDistance: _matchingHistory?.onTopDistance,
              onHistoryRetry: _matchingHistory?.retry,
            );
          },
    );
  }

  ComposerController? get _matchingComposer {
    final ComposerController? composer = widget.composerController;
    return composer != null && widget.conversationId == composer.conversationId
        ? composer
        : null;
  }

  HistoryController? get _matchingHistory {
    final HistoryController? history = widget.historyController;
    return history != null &&
            widget.conversationId == history.state.conversationId
        ? history
        : null;
  }
}

List<ChatMessage> _ordered(List<ChatMessage> source) {
  final Map<String, ChatMessage> byClientIdentity = <String, ChatMessage>{};
  for (final ChatMessage message in source) {
    byClientIdentity[message.clientMessageId] = message;
  }
  final Map<int, ChatMessage> canonicalBySequence = <int, ChatMessage>{};
  final List<ChatMessage> pending = <ChatMessage>[];
  for (final ChatMessage message in byClientIdentity.values) {
    if (message.sequence case final int sequence) {
      canonicalBySequence[sequence] = message;
    } else {
      // The Drift stream owns durable local insertion order. Client timestamps
      // are display-only and must never reorder pending messages.
      pending.add(message);
    }
  }
  final List<ChatMessage> canonical = canonicalBySequence.values.toList()
    ..sort(
      (ChatMessage a, ChatMessage b) => a.sequence!.compareTo(b.sequence!),
    );
  return List<ChatMessage>.unmodifiable(<ChatMessage>[
    ...canonical,
    ...pending,
  ]);
}

class _ChatState extends StatelessWidget {
  const _ChatState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
