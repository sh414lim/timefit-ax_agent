import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoRouteTransitionMixin;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/database/app_database.dart';
import '../core/database/local_repository_session.dart';
import '../dev/personal_chat_client.dart';
import '../dev/personal_chat_outbox_executor.dart';
import '../features/account/presentation/account_preview.dart';
import '../features/attachments/application/attachment_picker.dart';
import '../features/attachments/application/dev_local_attachment_observability.dart';
import '../features/attachments/application/dev_local_attachment_preview_controller.dart';
import '../features/attachments/data/dev_local_attachment_drafts.dart';
import '../features/attachments/data/local_attachment_store.dart';
import '../features/attachments/domain/attachment_policy.dart';
import '../features/attachments/presentation/dev_local_attachment_preview_screen.dart';
import '../features/chat/application/composer_controller.dart';
import '../features/chat/application/drift_attachment_composer_source.dart';
import '../features/chat/application/outbox/outbox_worker.dart';
import '../features/chat/application/outbox/retry_policy.dart';
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
import '../features/home/presentation/widgets/timefit_loading_mark.dart';

import 'theme/timefit_ax_visual_tokens.dart';

typedef DevChatDatabaseFactory = Future<AppDatabase> Function();
typedef DevAttachmentRootFactory = Future<Directory> Function();
typedef DevChatDisposalObserver = void Function(Future<void> disposal);

Future<String?> showPersonalChatPairingDialog(BuildContext context) {
  var enteredPairing = '';
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Mac 개인 서버 연결'),
      content: TextField(
        autofocus: true,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'pairing.txt 값',
          helperText: '127.0.0.1:8790 · 이 실행 메모리에만 유지',
        ),
        onChanged: (value) => enteredPairing = value,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(enteredPairing.trim()),
          child: const Text('연결'),
        ),
      ],
    ),
  );
}

Future<AppDatabase> openDevChatDatabase() =>
    _openLocalChatDatabase('dev-local-chat-v1');

Future<AppDatabase> openStagingChatDatabase() =>
    _openLocalChatDatabase('staging-local-chat-v1');

Future<Directory> openDevAttachmentRoot() =>
    _openLocalAttachmentRoot('dev-local-chat-v1');

Future<Directory> openStagingAttachmentRoot() =>
    _openLocalAttachmentRoot('staging-local-chat-v1');

Future<Directory> _openLocalNamespace(String name) async {
  final support = await getApplicationSupportDirectory();
  final namespace = Directory(path.join(support.path, 'timefit-native', name));
  return namespace.create(recursive: true);
}

Future<AppDatabase> _openLocalChatDatabase(String name) async {
  final namespace = await _openLocalNamespace(name);
  return AppDatabase(
    NativeDatabase(File(path.join(namespace.path, 'chat.sqlite'))),
  );
}

Future<Directory> _openLocalAttachmentRoot(String name) async {
  final namespace = await _openLocalNamespace(name);
  return Directory(
    path.join(namespace.path, 'attachments'),
  ).create(recursive: true);
}

/// Non-production local chat composition root. Staging has a separate data
/// namespace and no opt-in, credential or adapter input for personal chat.
class DevChatShell extends StatefulWidget {
  const DevChatShell({
    this.databaseFactory = openDevChatDatabase,
    this.attachmentRootFactory = openDevAttachmentRoot,
    this.attachmentPicker,
    this.previewImageRenderer,
    this.previewPdfRenderer,
    this.attachmentObservability,
    this.disposalObserver,
    this.personalChatOptIn = false,
    this.personalChatApi,
    this.chatExperienceEnabled = false,
    super.key,
  }) : _staging = false;

  const DevChatShell.staging({this.disposalObserver, super.key})
    : databaseFactory = openStagingChatDatabase,
      attachmentRootFactory = openStagingAttachmentRoot,
      attachmentPicker = null,
      previewImageRenderer = null,
      previewPdfRenderer = null,
      attachmentObservability = null,
      _staging = true,
      personalChatOptIn = false,
      personalChatApi = null,
      chatExperienceEnabled = true;

  final bool _staging;
  final DevChatDatabaseFactory databaseFactory;
  final DevAttachmentRootFactory attachmentRootFactory;
  final AttachmentPicker? attachmentPicker;
  final DevLocalFileRenderer? previewImageRenderer;
  final DevLocalFileRenderer? previewPdfRenderer;
  final DevLocalAttachmentObservability? attachmentObservability;
  final DevChatDisposalObserver? disposalObserver;
  final bool personalChatOptIn;
  final PersonalChatApi? personalChatApi;
  final bool chatExperienceEnabled;

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
  final TextEditingController _newDraftController = TextEditingController();
  final FocusNode _newDraftFocusNode = FocusNode();
  final TextEditingController _listSearchController = TextEditingController();
  final PageStorageBucket _listStorage = PageStorageBucket();
  final Map<String, String> _roomTextDrafts = <String, String>{};
  final _axNavigator = GlobalKey<NavigatorState>();
  bool _showingNewChat = false;
  bool _quietHomeSend = false;
  bool _axPopPending = false;
  bool _sendingFirst = false;
  int _firstDraftRevision = 0;
  String _lastHomeDraft = '';
  String _lastNewDraft = '';

  bool get _newExperience =>
      widget.chatExperienceEnabled && !widget.personalChatOptIn;

  void _trackDraftChange() {
    final home = _homeDraftController.text;
    final newChat = _newDraftController.text;
    if (home == _lastHomeDraft && newChat == _lastNewDraft) return;
    _lastHomeDraft = home;
    _lastNewDraft = newChat;
    _firstDraftRevision += 1;
  }

  AttachmentCancellation? _attachmentCancellation;
  OutboxWorker? _personalChatWorker;
  Timer? _personalChatTimer;
  String? _personalPairing;
  String? _personalConnectionError;
  bool _personalConnecting = false;
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
    _homeDraftController.addListener(_trackDraftChange);
    _newDraftController.addListener(_trackDraftChange);
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

  Future<void> _connectPersonalChat() async {
    if (!widget.personalChatOptIn ||
        _personalConnecting ||
        _database == null ||
        _session == null) {
      return;
    }
    final pairing = await showPersonalChatPairingDialog(context);
    if (pairing == null || !mounted) return;
    setState(() {
      _personalConnecting = true;
      _personalConnectionError = null;
    });
    try {
      await (widget.personalChatApi ?? const PersonalChatHttpClient()).history(
        pairing,
      );
      if (!mounted) return;
      _startPersonalChatWorker(pairing);
      setState(() {
        _personalPairing = pairing;
        _personalConnecting = false;
      });
      unawaited(_personalChatWorker!.wake());
    } on PersonalChatFailure catch (failure) {
      if (mounted) {
        setState(() {
          _personalConnecting = false;
          _personalConnectionError = failure.code;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _personalConnecting = false;
          _personalConnectionError = 'connection_failed';
        });
      }
    }
  }

  void _startPersonalChatWorker(String pairing) {
    _personalChatTimer?.cancel();
    _personalChatWorker?.stop();
    final worker = OutboxWorker(
      dao: _database!.outboxDao,
      executor: PersonalChatOutboxExecutor(
        database: _database!,
        session: _session!,
        api: widget.personalChatApi ?? const PersonalChatHttpClient(),
        pairing: pairing,
        clock: DateTime.now,
      ),
      clock: DateTime.now,
      retryPolicy: RetryPolicy(() => 0.5),
      scope: 'dev-local-chat-v1:personal-loopback',
    );
    _personalChatWorker = worker;
    _personalChatTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(worker.wake()),
    );
  }

  void _beginConversation() {
    if (_axPopPending) return;
    if (!_newExperience) {
      unawaited(_createConversation());
      return;
    }
    if (_selectedConversationId != null) _closeConversation();
    _conversationGeneration += 1;
    setState(() => _showingNewChat = true);
  }

  void _closeNewChat() {
    _conversationGeneration += 1;
    _newDraftFocusNode.unfocus();
    setState(() => _showingNewChat = false);
  }

  Future<void> _sendFirst(TextEditingController controller) async {
    final body = controller.text;
    final database = _database;
    final session = _session;
    if (_sendingFirst ||
        database == null ||
        session == null ||
        body.trim().isEmpty ||
        ComposerController.characterCountOf(body) >
            ComposerController.maximumLength) {
      return;
    }
    final admission = ChatSessionOwnedSurfaces.admit(context);
    final generation = _conversationGeneration;
    final revision = _firstDraftRevision;
    bool current() =>
        mounted &&
        !_disposed &&
        admission.isAllowed &&
        generation == _conversationGeneration;
    if (!current()) return;
    setState(() => _sendingFirst = true);
    try {
      final command = await SendMessage(
        database: database,
        session: session,
        clock: DateTime.now,
      ).startConversation(bodyText: body, stillAdmitted: current);
      if (!current()) return;
      // A user edit during the save belongs to the newly opened room.
      if (revision == _firstDraftRevision) {
        controller.clear();
      } else {
        if (controller.text.isNotEmpty) {
          _roomTextDrafts[command.conversationId] = controller.text;
        }
        controller.clear();
      }
      FocusManager.instance.primaryFocus?.unfocus();
      // Promote the existing composer page instead of pushing another route.
      _quietHomeSend = controller == _homeDraftController;
      _openConversation(command.conversationId, fresh: true);
    } on Object {
      if (current()) _showLocalNotice('메시지를 저장하지 못했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted && !_disposed) setState(() => _sendingFirst = false);
    }
  }

  void _rememberCurrentDraft() {
    final id = _selectedConversationId;
    final composer = _composer;
    if (!_newExperience || id == null || composer == null) return;
    final draft = composer.draftForNavigation;
    if (draft.isEmpty) {
      _roomTextDrafts.remove(id);
    } else {
      _roomTextDrafts[id] = draft;
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

  void _openConversation(String conversationId, {bool fresh = false}) {
    if (_axPopPending || _selectedConversationId == conversationId) return;
    unawaited(_prepareConversation(conversationId, fresh: fresh));
  }

  Future<void> _prepareConversation(
    String conversationId, {
    required bool fresh,
  }) async {
    _rememberCurrentDraft();
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
        (fresh
            ? null
            : await drafts.findDraftClientMessageId(conversationId)) ??
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
      )..updateDraft(_roomTextDrafts[conversationId] ?? '');
    });
  }

  void _closeConversation() {
    _rememberCurrentDraft();
    _conversationGeneration += 1;
    _attachmentCancellation?.cancel();
    _attachmentCancellation = null;
    _composer?.dispose();
    setState(() {
      _creatingConversation = false;
      _composer = null;
      _selectedConversationId = null;
      _showingNewChat = false;
      _quietHomeSend = false;
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
    _personalChatTimer?.cancel();
    _personalChatWorker?.stop();
    _personalPairing = null;
    _composer?.dispose();
    _homeDraftController.dispose();
    _homeDraftFocusNode.dispose();
    _newDraftFocusNode.dispose();
    _newDraftController.dispose();
    _listSearchController.dispose();
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
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final size = MediaQuery.sizeOf(context);
    final bool compactKeyboardLayout =
        viewInsets.bottom > 0 &&
        (size.width > size.height || size.height - viewInsets.bottom < 400);
    if (_newExperience &&
        _initializationError == null &&
        _listController != null) {
      return _buildAxNavigator(compactKeyboardLayout, size.width >= 900);
    }
    final bool showingSourceHome =
        _initializationError == null &&
        _listController != null &&
        _selectedConversationId == null &&
        !_showingArchive &&
        !_showingConversationList &&
        !_showingNewChat;
    final showModeBanner = !showingSourceHome || widget.personalChatOptIn;
    final shell = Scaffold(
      body: Column(
        children: <Widget>[
          if (showModeBanner)
            _DevLocalModeBanner(
              staging: widget._staging,
              compact: compactKeyboardLayout,
              includesWaitingStatus:
                  compactKeyboardLayout && _selectedConversationId != null,
              personalChatOptIn: widget.personalChatOptIn,
              personalConnected: _personalPairing != null,
              personalConnecting: _personalConnecting,
              connectionError: _personalConnectionError,
              onConnect: () => unawaited(_connectPersonalChat()),
            ),
          Expanded(
            // The banner already includes the window's top safe area.
            child: Builder(
              builder: (bodyContext) => MediaQuery.removePadding(
                context: bodyContext,
                removeTop: showModeBanner,
                child: _buildContent(compactKeyboardLayout),
              ),
            ),
          ),
        ],
      ),
    );
    return shell;
  }

  void _requestAxBack({bool dismissKeyboardFirst = false}) {
    if (_axPopPending) return;
    if (View.of(context).viewInsets.bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (dismissKeyboardFirst) return;
    }
    unawaited(_axNavigator.currentState?.maybePop<void>());
  }

  void _removeAxPage(Page<Object?> page) {
    if (!mounted || _disposed) return;
    _axPopPending = false;
    switch (page.name) {
      case 'ax-compose':
        if (_selectedConversationId != null) {
          _closeConversation();
        } else if (_showingNewChat) {
          _closeNewChat();
        }
      case 'ax-archive':
        if (_showingArchive) setState(() => _showingArchive = false);
      case 'ax-list':
        if (_showingConversationList)
          setState(() => _showingConversationList = false);
    }
  }

  Widget _buildAxNavigator(bool compact, bool wide) {
    final bool split = wide && _showingConversationList && !_showingArchive;
    final bool ios = Theme.of(context).platform == TargetPlatform.iOS;
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    final bool flow = _selectedConversationId != null || _showingNewChat;
    final controller = _listController!;
    Widget list({required bool sidebar}) {
      return PageStorage(
        bucket: _listStorage,
        child: _buildConversationList(
          controller,
          onBack: sidebar
              ? () {
                  if (_selectedConversationId != null) _closeConversation();
                  if (_showingNewChat) _closeNewChat();
                  setState(() => _showingConversationList = false);
                }
              : _requestAxBack,
          activeConversationId: split ? _selectedConversationId : null,
        ),
      );
    }

    Page<void> page(String name, Widget child, {bool quiet = false}) =>
        _AxShellPage(
          key: ValueKey<String>(name),
          name: name,
          child: child,
          ios: ios,
          reduceMotion: reduce || split,
          quietForward: quiet,
          onPopInvoked: (popped, _) {
            // An interactive drag does not invalidate a save unless it commits.
            if (!popped) return;
            final stillOwnsPage = switch (name) {
              'ax-compose' =>
                _selectedConversationId != null || _showingNewChat,
              'ax-archive' => _showingArchive,
              'ax-list' => _showingConversationList,
              _ => false,
            };
            if (!stillOwnsPage) return; // Parent already removed it.
            _axPopPending = true;
            if (name == 'ax-compose') _conversationGeneration += 1;
          },
        );
    final navigator = NavigatorPopHandler<void>(
      onPopWithResult: (_) => _requestAxBack(dismissKeyboardFirst: true),
      child: Navigator(
        key: _axNavigator,
        onDidRemovePage: _removeAxPage,
        pages: [
          page(
            'ax-home',
            widget._staging
                ? _modeSurface(compact, _buildHome(controller))
                : _buildHome(controller),
          ),
          if (_showingConversationList)
            page(
              'ax-list',
              split
                  ? const Scaffold(
                      body: Center(child: Text('대화를 선택하거나 새 채팅을 시작하세요.')),
                    )
                  : _modeSurface(compact, list(sidebar: false)),
            ),
          if (_showingArchive)
            page(
              'ax-archive',
              _modeSurface(compact, _buildArchive(_requestAxBack)),
            ),
          if (flow)
            page(
              'ax-compose',
              _modeSurface(
                compact,
                _selectedConversationId == null
                    ? _buildDraft(_requestAxBack)
                    : _buildRoom(
                        _selectedConversationId!,
                        compact,
                        _requestAxBack,
                      ),
                includesWaitingStatus:
                    compact && _selectedConversationId != null,
              ),
              quiet: _quietHomeSend,
            ),
        ],
      ),
    );
    // Keep the Navigator at the same element position across rotate/resize.
    // One shell handles the keyboard inset for both panes. Nested Scaffolds
    // receive the adjusted MediaQuery instead of subtracting it a second time.
    return Scaffold(
      body: Row(
        children: [
          if (split) ...[
            SizedBox(
              width: 336,
              child: _modeSurface(compact, list(sidebar: true)),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            key: const ValueKey<String>('ax-navigation-pane'),
            child: navigator,
          ),
        ],
      ),
    );
  }

  Widget _modeSurface(
    bool compact,
    Widget child, {
    bool includesWaitingStatus = false,
  }) => Material(
    child: Column(
      children: [
        _DevLocalModeBanner(
          staging: widget._staging,
          compact: compact,
          includesWaitingStatus: includesWaitingStatus,
          personalChatOptIn: false,
          personalConnected: false,
          personalConnecting: false,
          connectionError: null,
          onConnect: () {},
        ),
        Expanded(
          child: Builder(
            builder: (context) => MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _personalPairing != null) {
      unawaited(_personalChatWorker?.wake());
    }
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
      return const Center(child: TimeFitLoadingMark(label: '로컬 저장소를 불러오는 중'));
    }
    final conversationId = _selectedConversationId;
    if (conversationId != null) {
      return _buildRoom(
        conversationId,
        compactKeyboardLayout,
        _closeConversation,
      );
    }
    if (_showingArchive) {
      return _buildArchive(() => setState(() => _showingArchive = false));
    }
    if (!_showingConversationList) return _buildHome(controller);
    return _buildConversationList(
      controller,
      onBack: () => setState(() => _showingConversationList = false),
    );
  }

  Widget _buildRoom(
    String conversationId,
    bool compactKeyboardLayout,
    VoidCallback onBack,
  ) {
    final composer = _composer;
    return Column(
      children: <Widget>[
        Expanded(
          child: ChatScreen.repository(
            title: '로컬 대화',
            axBranding: _newExperience,
            repository: _messageRepository!,
            conversationId: conversationId,
            composerController: composer,
            onBack: onBack,
            localModeLabel: !compactKeyboardLayout
                ? _personalPairing == null
                      ? '서버 미연결 · 이 기기에 대기 중'
                      : 'Mac 개인 서버 연결됨 · Outbox 전송 중'
                : null,
            onAddAttachment: _personalPairing == null
                ? () => unawaited(_chooseAttachments())
                : null,
            onRemoveQueuedAttachment: _removeQueuedAttachment,
            onOpenAttachment: _openLocalAttachmentPreview,
            isSelectingAttachments: _selectingAttachments,
            compactKeyboardLayout: compactKeyboardLayout,
            savesLocallyOnly: _personalPairing == null,
          ),
        ),
      ],
    );
  }

  Widget _buildDraft(VoidCallback onBack) => TimeFitNewChatHome(
    controller: _newDraftController,
    focusNode: _newDraftFocusNode,
    onBack: onBack,
    onSend: () => unawaited(_sendFirst(_newDraftController)),
    sendEnabled: !_sendingFirst,
  );

  Widget _buildArchive(VoidCallback onBack) => ArchivedConversationScreen(
    conversations: _conversationRepository!.watchArchivedConversations(),
    onBack: onBack,
    onOpenConversation: _openConversation,
  );

  void _openConversationList() {
    if (_axPopPending) return;
    if (_newExperience) _conversationGeneration += 1;
    setState(() => _showingConversationList = true);
  }

  void _openArchive() {
    if (_axPopPending) return;
    if (_newExperience) {
      if (_selectedConversationId != null) _closeConversation();
      if (_showingNewChat) _closeNewChat();
      _conversationGeneration += 1;
    }
    setState(() => _showingArchive = true);
  }

  Widget _buildHome(ConversationListController controller) {
    return DemoHomeScreen(
      conversationController: controller,
      onOpenConversation: _openConversation,
      onOpenConversationList: _openConversationList,
      onOpenArchive: _openArchive,
      onNewConversation: _beginConversation,
      onSend: _newExperience
          ? () => unawaited(_sendFirst(_homeDraftController))
          : null,
      sendEnabled: !_sendingFirst,
      draftController: _homeDraftController,
      draftFocusNode: _homeDraftFocusNode,
    );
  }

  Widget _buildConversationList(
    ConversationListController controller, {
    required VoidCallback onBack,
    String? activeConversationId,
  }) {
    return ConversationListScreen(
      controller: controller,
      searchController: _newExperience ? _listSearchController : null,
      loadOnMount: false,
      onBack: onBack,
      selectedConversationId: activeConversationId,
      onNewConversation: _beginConversation,
      onOpenSettings: () {
        if (!_newExperience) {
          _showLocalNotice('설정은 로컬 개발 모드에서 비활성화되어 있습니다.');
          return;
        }
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const AxAccountPreviewPage(),
            ),
          ),
        );
      },
      onOpenArchive: _openArchive,
      onOpenConversation: _openConversation,
      onConversationAction: (conversation, action) =>
          unawaited(_handleConversationAction(conversation, action)),
      isConversationBusy: (String id) =>
          _conversationActions?.state.isBusy(id) ?? false,
    );
  }
}

/// Stable page identity across a first-send promotion and width changes.
class _AxShellPage extends Page<void> {
  const _AxShellPage({
    required this.child,
    required this.ios,
    required this.reduceMotion,
    required this.quietForward,
    required super.key,
    required super.name,
    super.onPopInvoked,
  });

  final Widget child;
  final bool ios;
  final bool reduceMotion;
  final bool quietForward;

  @override
  Route<void> createRoute(BuildContext context) =>
      ios ? _AxCupertinoRoute(this) : _AxMaterialRoute(this);
}

class _AxCupertinoRoute extends PageRoute<void>
    with CupertinoRouteTransitionMixin<void> {
  _AxCupertinoRoute(_AxShellPage page) : super(settings: page);
  _AxShellPage get page => settings as _AxShellPage;

  @override
  String? get title => page.name;
  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration => page.reduceMotion || page.quietForward
      ? Duration.zero
      : super.transitionDuration;
  @override
  Duration get reverseTransitionDuration =>
      page.reduceMotion ? Duration.zero : super.transitionDuration;
  @override
  bool get popGestureEnabled =>
      page.reduceMotion ? false : super.popGestureEnabled;

  @override
  Widget buildContent(BuildContext context) => page.child;
}

class _AxMaterialRoute extends PageRoute<void>
    with MaterialRouteTransitionMixin<void> {
  _AxMaterialRoute(_AxShellPage page) : super(settings: page);
  _AxShellPage get page => settings as _AxShellPage;

  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration => page.reduceMotion || page.quietForward
      ? Duration.zero
      : super.transitionDuration;
  @override
  Duration get reverseTransitionDuration =>
      page.reduceMotion ? Duration.zero : super.reverseTransitionDuration;

  @override
  Widget buildContent(BuildContext context) => page.child;
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
    required this.staging,
    required this.compact,
    required this.includesWaitingStatus,
    required this.personalChatOptIn,
    required this.personalConnected,
    required this.personalConnecting,
    required this.connectionError,
    required this.onConnect,
  });

  final bool staging;
  final bool compact;
  final bool includesWaitingStatus;
  final bool personalChatOptIn;
  final bool personalConnected;
  final bool personalConnecting;
  final String? connectionError;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: personalChatOptIn
          ? Theme.of(context).colorScheme.tertiaryContainer
          : TimeFitAxVisualTokens.chatChromeOf(context),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 0 : 8,
            ),
            child: personalChatOptIn
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          personalConnected
                              ? '개발용 · Mac 개인 서버 연결됨'
                              : connectionError == null
                              ? '개발용 · pairing 필요 · 이 기기에 대기 중'
                              : '개발용 · 연결 실패 · 자동 재전송 없음',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (personalConnecting)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        TextButton(
                          onPressed: personalConnected ? null : onConnect,
                          child: Text(personalConnected ? '연결됨' : 'Mac 서버 연결'),
                        ),
                    ],
                  )
                : Text(
                    staging
                        ? includesWaitingStatus
                              ? '스테이징 로컬 · 이 기기에 대기 중'
                              : '스테이징 로컬 모드 · 로그인/서버 연결 없음'
                        : includesWaitingStatus
                        ? '개발 로컬 · 로그인/서버 없음 · 이 기기에 대기 중'
                        : '개발용 로컬 모드 · 로그인/서버 연결 없음',
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: TimeFitAxVisualTokens.of(context).secondaryText,
                    ),
                    maxLines: compact ? 1 : null,
                    overflow: compact
                        ? TextOverflow.ellipsis
                        : TextOverflow.clip,
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
