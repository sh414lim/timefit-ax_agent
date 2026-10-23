import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/database/app_database.dart';
import '../core/database/local_repository_session.dart';
import '../features/chat/application/composer_controller.dart';
import '../features/chat/application/send_message.dart';
import '../features/chat/data/message_repository_impl.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/conversations/application/conversation_actions.dart';
import '../features/conversations/application/conversation_list_controller.dart';
import '../features/conversations/data/dev_local_conversation_repository.dart';
import '../features/conversations/domain/conversation_summary.dart';
import '../features/conversations/presentation/archived_conversation_screen.dart';
import '../features/conversations/presentation/conversation_list_screen.dart';
import '../features/conversations/presentation/conversation_menu.dart';

typedef DevChatDatabaseFactory = Future<AppDatabase> Function();
typedef DevChatDisposalObserver = void Function(Future<void> disposal);

Future<AppDatabase> openDevChatDatabase() async {
  final support = await getApplicationSupportDirectory();
  final namespace = Directory(
    path.join(support.path, 'timefit-native', 'dev-local-chat-v1'),
  );
  await namespace.create(recursive: true);
  return AppDatabase(
    NativeDatabase(File(path.join(namespace.path, 'chat.sqlite'))),
  );
}

/// Local development composition root. It owns one database and one local
/// repository session and deliberately starts no worker or remote adapter.
class DevChatShell extends StatefulWidget {
  const DevChatShell({
    this.databaseFactory = openDevChatDatabase,
    this.disposalObserver,
    super.key,
  });

  final DevChatDatabaseFactory databaseFactory;
  final DevChatDisposalObserver? disposalObserver;

  @override
  State<DevChatShell> createState() => _DevChatShellState();
}

class _DevChatShellState extends State<DevChatShell> {
  AppDatabase? _database;
  LocalRepositorySession? _session;
  DevLocalConversationRepository? _conversationRepository;
  ConversationListController? _listController;
  ConversationActions? _conversationActions;
  MessageRepositoryImpl? _messageRepository;
  ComposerController? _composer;
  String? _selectedConversationId;
  Object? _initializationError;
  bool _creatingConversation = false;
  bool _showingArchive = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    AppDatabase? database;
    try {
      database = await widget.databaseFactory();
      if (_disposed) {
        await database.close();
        return;
      }
      final session = LocalRepositorySession.forDatabase(database);
      final conversationRepository = DevLocalConversationRepository(
        database: database,
        session: session,
      );
      final listController = ConversationListController(
        repository: conversationRepository,
        localOnly: true,
      );
      final conversationActions = ConversationActions(
        repository: conversationRepository,
      );
      conversationActions.addListener(_handleActionsState);
      final messageRepository = MessageRepositoryImpl(
        database: database,
        session: session,
      );
      setState(() {
        _database = database;
        _session = session;
        _conversationRepository = conversationRepository;
        _listController = listController;
        _conversationActions = conversationActions;
        _messageRepository = messageRepository;
      });
    } on Object catch (error) {
      if (database != null) await database.close();
      if (mounted) setState(() => _initializationError = error);
    }
  }

  Future<void> _createConversation() async {
    if (_creatingConversation) return;
    final repository = _conversationRepository;
    if (repository == null) return;
    setState(() => _creatingConversation = true);
    try {
      final id = await repository.createConversation();
      if (mounted) _openConversation(id);
    } on Object {
      if (mounted) {
        setState(() => _creatingConversation = false);
        _showLocalNotice('새 대화를 저장하지 못했습니다.');
      }
    }
  }

  void _openConversation(String conversationId) {
    _composer?.dispose();
    final database = _database!;
    final session = _session!;
    setState(() {
      _selectedConversationId = conversationId;
      _composer = ComposerController(
        conversationId: conversationId,
        submitter: SendMessage(
          database: database,
          clock: DateTime.now,
          session: session,
        ),
      );
    });
  }

  void _closeConversation() {
    _composer?.dispose();
    setState(() {
      _creatingConversation = false;
      _composer = null;
      _selectedConversationId = null;
    });
  }

  void _handleActionsState(ConversationActionsState _) {
    if (mounted) setState(() {});
  }

  Future<void> _handleConversationAction(
    ConversationSummary conversation,
    ConversationMenuAction action,
  ) async {
    switch (action) {
      case ConversationMenuAction.rename:
        await _renameConversation(conversation);
      case ConversationMenuAction.archive:
        await _archiveConversation(conversation);
    }
  }

  Future<void> _renameConversation(ConversationSummary conversation) async {
    String editedTitle = conversation.title;
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('대화 이름 변경'),
        content: TextFormField(
          initialValue: conversation.title,
          autofocus: true,
          maxLength: ConversationTitle.maximumCharacters,
          decoration: const InputDecoration(labelText: '대화 이름'),
          onChanged: (String value) => editedTitle = value,
          onFieldSubmitted: (String value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(editedTitle),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (title == null || !mounted) return;
    final bool succeeded = await _conversationActions!.rename(
      conversation.id,
      title,
    );
    if (!succeeded &&
        mounted &&
        _conversationActions!.state.errorMessage != null) {
      _showActionError();
    }
  }

  Future<void> _archiveConversation(ConversationSummary conversation) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('대화를 보관할까요?'),
            content: Text('“${conversation.title}” 대화를 보관 목록으로 이동합니다.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('보관'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final bool succeeded = await _conversationActions!.archive(conversation.id);
    if (!succeeded &&
        mounted &&
        _conversationActions!.state.errorMessage != null) {
      _showActionError();
    }
  }

  void _showActionError() {
    final ConversationActions actions = _conversationActions!;
    final String message = actions.state.errorMessage ?? '작업을 완료하지 못했습니다.';
    actions.clearError();
    _showLocalNotice(message);
  }

  void _showLocalNotice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _disposed = true;
    _composer?.dispose();
    _conversationActions?.removeListener(_handleActionsState);
    _conversationActions?.dispose();
    final controller = _listController;
    final session = _session;
    final database = _database;
    final disposal = () async {
      await controller?.dispose();
      await session?.dispose();
      await database?.close();
    }();
    widget.disposalObserver?.call(disposal);
    unawaited(disposal);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const _DevLocalModeBanner(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_initializationError != null) {
      return const _LocalState(
        title: '로컬 저장소를 열지 못했습니다',
        message: '앱을 다시 시작해 주세요.',
      );
    }
    final controller = _listController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final conversationId = _selectedConversationId;
    if (conversationId != null) {
      return Column(
        children: <Widget>[
          const Material(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('서버 미연결 · 이 기기에 대기 중'),
            ),
          ),
          Expanded(
            child: ChatScreen.repository(
              title: '로컬 대화',
              repository: _messageRepository!,
              conversationId: conversationId,
              composerController: _composer,
              onBack: _closeConversation,
            ),
          ),
        ],
      );
    }
    if (_showingArchive) {
      return ArchivedConversationScreen(
        conversations: _conversationRepository!.watchArchivedConversations(),
        onBack: () => setState(() => _showingArchive = false),
        onOpenConversation: _openConversation,
      );
    }
    return ConversationListScreen(
      controller: controller,
      onNewConversation: () => unawaited(_createConversation()),
      onOpenSettings: () => _showLocalNotice('설정은 로컬 개발 모드에서 비활성화되어 있습니다.'),
      onOpenArchive: () => setState(() => _showingArchive = true),
      onOpenConversation: _openConversation,
      onConversationAction: (conversation, action) =>
          unawaited(_handleConversationAction(conversation, action)),
      isConversationBusy: (String id) =>
          _conversationActions?.state.isBusy(id) ?? false,
    );
  }
}

class _DevLocalModeBanner extends StatelessWidget {
  const _DevLocalModeBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: const SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '개발용 로컬 모드 · 로그인/서버 연결 없음',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalState extends StatelessWidget {
  const _LocalState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}
