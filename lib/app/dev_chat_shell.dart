import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/database/app_database.dart';
import '../core/database/local_repository_session.dart';
import '../features/attachments/application/attachment_picker.dart';
import '../features/attachments/application/dev_local_attachment_observability.dart';
import '../features/attachments/application/dev_local_attachment_preview_controller.dart';
import '../features/attachments/data/dev_local_attachment_drafts.dart';
import '../features/attachments/data/local_attachment_store.dart';
import '../features/attachments/domain/attachment_policy.dart';
import '../features/attachments/presentation/dev_local_attachment_preview_screen.dart';
import '../features/chat/application/composer_controller.dart';
import '../features/chat/application/drift_attachment_composer_source.dart';
import '../features/chat/application/send_message.dart';
import '../features/chat/data/message_repository_impl.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/chat/presentation/chat_session_gate.dart';
import '../features/conversations/application/conversation_actions.dart';
import '../features/conversations/application/conversation_list_controller.dart';
import '../features/conversations/data/dev_local_conversation_repository.dart';
import '../features/conversations/domain/conversation_summary.dart';
import '../features/conversations/presentation/archived_conversation_screen.dart';
import '../features/conversations/presentation/conversation_list_screen.dart';
import '../features/conversations/presentation/conversation_menu.dart';
import '../features/home/presentation/home_screen.dart';

typedef DevChatDatabaseFactory = Future<AppDatabase> Function();
typedef DevAttachmentRootFactory = Future<Directory> Function();
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

Future<Directory> openDevAttachmentRoot() async {
  final Directory support = await getApplicationSupportDirectory();
  final Directory root = Directory(
    path.join(
      support.path,
      'timefit-native',
      'dev-local-chat-v1',
      'attachments',
    ),
  );
  await root.create(recursive: true);
  return root;
}

/// Local development composition root. It owns one database and one local
/// repository session and deliberately starts no worker or remote adapter.
class DevChatShell extends StatefulWidget {
  const DevChatShell({
    this.databaseFactory = openDevChatDatabase,
    this.attachmentRootFactory = openDevAttachmentRoot,
    this.attachmentPicker,
    this.previewImageRenderer,
    this.previewPdfRenderer,
    this.attachmentObservability,
    this.disposalObserver,
    super.key,
  });

  final DevChatDatabaseFactory databaseFactory;
  final DevAttachmentRootFactory attachmentRootFactory;
  final AttachmentPicker? attachmentPicker;
  final DevLocalFileRenderer? previewImageRenderer;
  final DevLocalFileRenderer? previewPdfRenderer;
  final DevLocalAttachmentObservability? attachmentObservability;
  final DevChatDisposalObserver? disposalObserver;

  @override
  State<DevChatShell> createState() => _DevChatShellState();
}

class _DevChatShellState extends State<DevChatShell>
    with WidgetsBindingObserver {
  AppDatabase? _database;
  LocalRepositorySession? _session;
  DevLocalConversationRepository? _conversationRepository;
  ConversationListController? _listController;
  ConversationActions? _conversationActions;
  MessageRepositoryImpl? _messageRepository;
  ComposerController? _composer;
  DevLocalAttachmentDrafts? _attachmentDrafts;
  Directory? _attachmentRoot;
  late final AttachmentPicker _attachmentPicker =
      widget.attachmentPicker ?? NativeAttachmentPicker();
  final Map<String, String> _draftClientMessageIds = <String, String>{};
  final TextEditingController _homeDraftController = TextEditingController();
  final FocusNode _homeDraftFocusNode = FocusNode();
  AttachmentCancellation? _attachmentCancellation;
  String? _selectedConversationId;
  Object? _initializationError;
  bool _creatingConversation = false;
  bool _showingArchive = false;
  bool _showingConversationList = false;
  bool _selectingAttachments = false;
  bool _disposed = false;
  int _conversationGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      final Directory attachmentRoot = await widget.attachmentRootFactory();
      if (_disposed) {
        await database.close();
        return;
      }
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
      final attachmentDrafts = DevLocalAttachmentDrafts(
        database: database,
        session: session,
        store: LocalAttachmentStore(privateRoot: attachmentRoot),
        observability: widget.attachmentObservability,
      );
      setState(() {
        _database = database;
        _session = session;
        _conversationRepository = conversationRepository;
        _listController = listController;
        _conversationActions = conversationActions;
        _messageRepository = messageRepository;
        _attachmentDrafts = attachmentDrafts;
        _attachmentRoot = attachmentRoot;
      });
      unawaited(listController.load());
    } on Object catch (error) {
      if (database != null) await database.close();
      if (mounted) setState(() => _initializationError = error);
    }
  }

  Future<void> _createConversation() async {
    if (_creatingConversation) return;
    final ChatSessionOwnedSurfaceAdmission admission =
        ChatSessionOwnedSurfaces.admit(context);
    if (!admission.isAllowed) return;
    final repository = _conversationRepository;
    if (repository == null) return;
    setState(() => _creatingConversation = true);
    try {
      if (!admission.isAllowed) return;
      final id = await repository.createConversation();
      if (mounted && admission.isAllowed) _openConversation(id);
    } on Object {
      if (mounted && admission.isAllowed) {
        setState(() => _creatingConversation = false);
        _showLocalNotice('새 대화를 저장하지 못했습니다.');
      }
    }
  }

  void _openConversation(String conversationId) {
    unawaited(_prepareConversation(conversationId));
  }

  Future<void> _prepareConversation(String conversationId) async {
    final int generation = ++_conversationGeneration;
    _attachmentCancellation?.cancel();
    _composer?.dispose();
    final database = _database!;
    final session = _session!;
    setState(() {
      _selectedConversationId = conversationId;
      _composer = null;
      _selectingAttachments = false;
    });
    final DevLocalAttachmentDrafts drafts = _attachmentDrafts!;
    final String clientMessageId =
        _draftClientMessageIds[conversationId] ??
        await drafts.findDraftClientMessageId(conversationId) ??
        drafts.newDraftClientMessageId();
    if (!mounted ||
        generation != _conversationGeneration ||
        _selectedConversationId != conversationId) {
      return;
    }
    final ChatSessionOwnedSurfaceAdmission admission =
        ChatSessionOwnedSurfaces.admit(context);
    if (!admission.isAllowed) return;
    _draftClientMessageIds[conversationId] = clientMessageId;
    setState(() {
      _composer = ComposerController(
        conversationId: conversationId,
        attachmentClientMessageId: clientMessageId,
        attachmentSource: DriftAttachmentComposerSource(
          database: database,
          clock: DateTime.now,
          session: session,
        ),
        submitter: SendMessage(
          database: database,
          clock: DateTime.now,
          session: session,
        ),
        mutationAdmission: () => admission.isAllowed,
      );
    });
  }

  void _closeConversation() {
    _conversationGeneration += 1;
    _attachmentCancellation?.cancel();
    _attachmentCancellation = null;
    _composer?.dispose();
    setState(() {
      _creatingConversation = false;
      _composer = null;
      _selectedConversationId = null;
      _selectingAttachments = false;
    });
  }

  Future<void> _chooseAttachments() async {
    if (_selectingAttachments || _composer == null) return;
    final ChatSessionOwnedSurfaceAdmission admission =
        ChatSessionOwnedSurfaces.admit(context);
    if (!admission.isAllowed) return;
    final AttachmentPickerKind? kind = await admission
        .openBottomSheet<AttachmentPickerKind>(
          context: context,
          builder: (BuildContext context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('이미지 선택'),
                  subtitle: const Text('JPEG, PNG, WebP'),
                  onTap: () =>
                      Navigator.of(context).pop(AttachmentPickerKind.images),
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: const Text('파일 선택'),
                  subtitle: const Text('JPEG, PNG, WebP, PDF'),
                  onTap: () =>
                      Navigator.of(context).pop(AttachmentPickerKind.files),
                ),
              ],
            ),
          ),
        );
    if (kind == null || !mounted || _composer == null || !admission.isAllowed) {
      return;
    }

    final int generation = _conversationGeneration;
    final String conversationId = _selectedConversationId!;
    final String clientMessageId = _composer!.attachmentClientMessageId!;
    final AttachmentCancellation cancellation = AttachmentCancellation();
    _attachmentCancellation?.cancel();
    _attachmentCancellation = cancellation;
    final VoidCallback removeAdmissionInvalidation = admission.onInvalidated(
      cancellation.cancel,
    );
    setState(() => _selectingAttachments = true);
    try {
      final inputs = await _attachmentPicker.pick(kind);
      if (!mounted ||
          generation != _conversationGeneration ||
          _selectedConversationId != conversationId ||
          cancellation != _attachmentCancellation ||
          !admission.isAllowed) {
        return;
      }
      await _attachmentDrafts!.add(
        conversationId: conversationId,
        clientMessageId: clientMessageId,
        inputs: inputs,
        cancellation: cancellation,
      );
    } on AttachmentException catch (error) {
      if (mounted &&
          generation == _conversationGeneration &&
          admission.isAllowed &&
          error.failure != AttachmentFailure.cancelled) {
        _showLocalNotice(_attachmentFailureMessage(error.failure));
      }
    } on Object {
      if (mounted &&
          generation == _conversationGeneration &&
          admission.isAllowed) {
        _showLocalNotice('첨부를 로컬에 준비하지 못했습니다.');
      }
    } finally {
      removeAdmissionInvalidation();
      if (mounted &&
          generation == _conversationGeneration &&
          identical(_attachmentCancellation, cancellation)) {
        setState(() => _selectingAttachments = false);
        _attachmentCancellation = null;
      }
    }
  }

  Future<void> _removeQueuedAttachment(String localId) async {
    final ChatSessionOwnedSurfaceAdmission admission =
        ChatSessionOwnedSurfaces.admit(context);
    if (!admission.isAllowed) return;
    final int generation = _conversationGeneration;
    final String? conversationId = _selectedConversationId;
    final String? clientMessageId = _composer?.attachmentClientMessageId;
    if (conversationId == null || clientMessageId == null) return;
    try {
      if (!admission.isAllowed) return;
      await _attachmentDrafts!.remove(
        conversationId: conversationId,
        clientMessageId: clientMessageId,
        localId: localId,
      );
    } on Object {
      if (mounted &&
          generation == _conversationGeneration &&
          admission.isAllowed) {
        _showLocalNotice('로컬 첨부를 제거하지 못했습니다.');
      }
    }
  }

  void _openLocalAttachmentPreview(String localId) {
    final ChatSessionOwnedSurfaceAdmission admission =
        ChatSessionOwnedSurfaces.admit(context);
    if (!admission.isAllowed) return;
    final String? conversationId = _selectedConversationId;
    final AppDatabase? database = _database;
    final LocalRepositorySession? session = _session;
    final Directory? privateRoot = _attachmentRoot;
    if (conversationId == null ||
        database == null ||
        session == null ||
        privateRoot == null) {
      return;
    }
    final controller = DevLocalAttachmentPreviewController(
      database: database,
      session: session,
      privateRoot: privateRoot,
      conversationId: conversationId,
      localId: localId,
      observability: widget.attachmentObservability,
    );
    unawaited(
      admission.pushRoute<void>(
        context: context,
        route: MaterialPageRoute<void>(
          builder: (_) => DevLocalAttachmentPreviewScreen(
            controller: controller,
            imageRenderer: widget.previewImageRenderer,
            pdfRenderer: widget.previewPdfRenderer,
          ),
        ),
      ),
    );
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
    final ChatSessionOwnedSurfaceAdmission admission =
        ChatSessionOwnedSurfaces.admit(context);
    if (!admission.isAllowed) return;
    String editedTitle = conversation.title;
    final String? title = await admission.openDialog<String>(
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
    if (title == null || !mounted || !admission.isAllowed) return;
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
    final ChatSessionOwnedSurfaceAdmission admission =
        ChatSessionOwnedSurfaces.admit(context);
    if (!admission.isAllowed) return;
    final bool confirmed =
        await admission.openDialog<bool>(
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
    if (!confirmed || !mounted || !admission.isAllowed) return;
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
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _attachmentCancellation?.cancel();
    _composer?.dispose();
    _homeDraftController.dispose();
    _homeDraftFocusNode.dispose();
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
    final bool compactKeyboardLayout =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        View.of(context).viewInsets.bottom > 0;
    final bool showingSourceHome =
        _initializationError == null &&
        _listController != null &&
        _selectedConversationId == null &&
        !_showingArchive &&
        !_showingConversationList;
    return Scaffold(
      body: Column(
        children: <Widget>[
          if (!showingSourceHome)
            _DevLocalModeBanner(
              compact: compactKeyboardLayout,
              includesWaitingStatus:
                  compactKeyboardLayout && _selectedConversationId != null,
            ),
          Expanded(child: _buildContent(compactKeyboardLayout)),
        ],
      ),
    );
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  Widget _buildContent(bool compactKeyboardLayout) {
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
      final ComposerController? composer = _composer;
      return Column(
        children: <Widget>[
          if (!compactKeyboardLayout)
            const Material(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '서버 미연결 · 이 기기에 대기 중',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          Expanded(
            child: composer == null
                ? const Center(child: CircularProgressIndicator())
                : ChatScreen.repository(
                    title: '로컬 대화',
                    repository: _messageRepository!,
                    conversationId: conversationId,
                    composerController: composer,
                    onBack: _closeConversation,
                    onAddAttachment: () => unawaited(_chooseAttachments()),
                    onRemoveQueuedAttachment: _removeQueuedAttachment,
                    onOpenAttachment: _openLocalAttachmentPreview,
                    isSelectingAttachments: _selectingAttachments,
                    compactKeyboardLayout: compactKeyboardLayout,
                    savesLocallyOnly: true,
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
    if (!_showingConversationList) {
      return DemoHomeScreen(
        conversationController: controller,
        onOpenConversation: _openConversation,
        onOpenConversationList: () =>
            setState(() => _showingConversationList = true),
        onOpenArchive: () => setState(() => _showingArchive = true),
        onNewConversation: () => unawaited(_createConversation()),
        draftController: _homeDraftController,
        draftFocusNode: _homeDraftFocusNode,
      );
    }
    return ConversationListScreen(
      controller: controller,
      loadOnMount: false,
      onBack: () => setState(() => _showingConversationList = false),
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

String _attachmentFailureMessage(AttachmentFailure failure) =>
    switch (failure) {
      AttachmentFailure.invalidCount => '첨부는 메시지당 최대 5개까지 선택할 수 있습니다.',
      AttachmentFailure.invalidSize => '첨부는 1 byte에서 20 MiB까지 허용됩니다.',
      AttachmentFailure.unsupportedType ||
      AttachmentFailure.mimeMismatch => 'JPEG, PNG, WebP, PDF 파일만 허용됩니다.',
      AttachmentFailure.unsafeName ||
      AttachmentFailure.unsafePath => '안전하지 않은 첨부 파일입니다.',
      AttachmentFailure.cancelled => '첨부 준비가 취소됐습니다.',
    };

class _DevLocalModeBanner extends StatelessWidget {
  const _DevLocalModeBanner({
    required this.compact,
    required this.includesWaitingStatus,
  });

  final bool compact;
  final bool includesWaitingStatus;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 0 : 8,
            ),
            child: Text(
              includesWaitingStatus
                  ? '개발 로컬 · 로그인/서버 없음 · 이 기기에 대기 중'
                  : '개발용 로컬 모드 · 로그인/서버 연결 없음',
              textAlign: TextAlign.center,
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.clip,
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
