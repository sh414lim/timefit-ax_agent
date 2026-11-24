import 'package:flutter/material.dart';

import '../../../app/theme/timefit_ax_visual_tokens.dart';

import '../../home/presentation/widgets/timefit_loading_mark.dart';
import '../application/conversation_list_controller.dart';
import '../domain/conversation_summary.dart';
import 'conversation_menu.dart';
import 'widgets/conversation_list_row.dart';
import 'widgets/conversation_state_panel.dart';
import 'widgets/conversation_sync_banner.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({
    required this.controller,
    required this.onNewConversation,
    required this.onOpenSettings,
    required this.onOpenArchive,
    required this.onOpenConversation,
    this.onBack,
    this.loadOnMount = true,
    this.currentTime,
    this.searchController,
    this.selectedConversationId,
    this.onConversationAction,
    this.isConversationBusy,
    super.key,
  });

  final ConversationListController controller;
  final VoidCallback onNewConversation;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenArchive;
  final ValueChanged<String> onOpenConversation;
  final VoidCallback? onBack;
  final bool loadOnMount;
  final DateTime Function()? currentTime;
  final TextEditingController? searchController;
  final String? selectedConversationId;
  final void Function(ConversationSummary, ConversationMenuAction)?
  onConversationAction;
  final bool Function(String conversationId)? isConversationBusy;

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  late ConversationListState _state = widget.controller.state;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleStateChange);
    if (widget.loadOnMount) {
      widget.controller.load();
    }
  }

  @override
  void didUpdateWidget(ConversationListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleStateChange);
      _state = widget.controller.state;
      widget.controller.addListener(_handleStateChange);
      if (widget.loadOnMount) {
        widget.controller.load();
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange(ConversationListState state) {
    if (mounted) {
      setState(() => _state = state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branded = widget.searchController != null;
    final tokens = TimeFitAxVisualTokens.of(context);
    return Scaffold(
      backgroundColor: branded
          ? TimeFitAxVisualTokens.chatSurfaceOf(context)
          : null,
      appBar: AppBar(
        backgroundColor: branded
            ? TimeFitAxVisualTokens.chatChromeOf(context)
            : null,
        surfaceTintColor: branded ? Colors.transparent : null,
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        title: const Text('대화'),
        actions: <Widget>[
          if (widget.searchController != null)
            IconButton(
              tooltip: '새 채팅',
              onPressed: widget.onNewConversation,
              icon: const Icon(Icons.edit_square),
            ),
          Semantics(
            button: true,
            label: '설정 열기',
            excludeSemantics: true,
            child: branded
                ? IconButton(
                    onPressed: widget.onOpenSettings,
                    tooltip: '설정 열기',
                    icon: const Icon(Icons.settings_outlined),
                  )
                : TextButton(
                    onPressed: widget.onOpenSettings,
                    child: const Text('설정'),
                  ),
          ),
        ],
      ),
      floatingActionButton:
          widget.searchController != null ||
              _state.phase == ConversationListPhase.empty
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onNewConversation,
              label: const Text('새 대화'),
            ),
      body: SafeArea(
        child: widget.searchController == null
            ? _buildBody()
            : Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: TextField(
                      controller: widget.searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: '대화 제목 또는 메시지 검색',
                        filled: true,
                        fillColor: tokens.surface,
                        border: TimeFitAxVisualTokens.chatFieldBorder,
                        enabledBorder: TimeFitAxVisualTokens.chatFieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: tokens.primary),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.searchController!,
                      builder: (context, value, _) => _buildBody(value.text),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBody([String query = '']) {
    return switch (_state.phase) {
      ConversationListPhase.loading => const Center(
        child: TimeFitLoadingMark(label: '대화 목록을 불러오는 중'),
      ),
      ConversationListPhase.empty => RefreshIndicator(
        onRefresh: widget.controller.refresh,
        child: ConversationStatePanel(
          title: '아직 대화가 없습니다',
          compact: widget.searchController != null,
          message: '새 대화를 시작하면 이곳에서 다시 확인할 수 있습니다.',
          actionLabel: '새 대화 시작',
          onAction: widget.onNewConversation,
          secondaryActionLabel: '보관된 대화',
          onSecondaryAction: widget.onOpenArchive,
        ),
      ),
      ConversationListPhase.error => RefreshIndicator(
        onRefresh: widget.controller.refresh,
        child: ConversationStatePanel(
          title: _state.isOffline ? '오프라인 상태입니다' : '대화를 불러오지 못했습니다',
          message: _state.isOffline
              ? '네트워크 연결을 확인한 뒤 다시 시도해 주세요.'
              : '잠시 후 다시 시도해 주세요.',
          actionLabel: '다시 시도',
          onAction: widget.controller.load,
        ),
      ),
      ConversationListPhase.ready ||
      ConversationListPhase.stale => _buildConversationList(query),
    };
  }

  Widget _buildConversationList(String query) {
    final String normalized = query.trim().toLowerCase();
    final conversations = _state.conversations
        .where(
          (conversation) =>
              normalized.isEmpty ||
              conversation.title.toLowerCase().contains(normalized) ||
              conversation.displayPreview.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
    if (conversations.isEmpty && normalized.isNotEmpty) {
      return const Center(child: Text('검색 결과가 없습니다'));
    }
    final DateTime now = widget.currentTime?.call() ?? DateTime.now();
    final bool hasBanner = _state.phase == ConversationListPhase.stale;
    final int conversationOffset = hasBanner ? 1 : 0;
    return RefreshIndicator(
      onRefresh: widget.controller.refresh,
      child: ListView.separated(
        key: widget.searchController == null
            ? null
            : const PageStorageKey<String>('ax-conversations-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: conversations.length + conversationOffset + 1,
        separatorBuilder: (BuildContext context, int index) =>
            const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          if (hasBanner && index == 0) {
            return ConversationSyncBanner(state: _state);
          }
          if (index == conversations.length + conversationOffset) {
            return Semantics(
              button: true,
              label: '보관된 대화 열기',
              excludeSemantics: true,
              child: ListTile(
                minTileHeight: 56,
                title: const Text('보관된 대화'),
                onTap: widget.onOpenArchive,
              ),
            );
          }

          final ConversationSummary conversation =
              conversations[index - conversationOffset];
          return ConversationListRow(
            conversation: conversation,
            selected: conversation.id == widget.selectedConversationId,
            showAvatar: widget.searchController != null,
            updatedAtLabel: _formatUpdatedAt(conversation.updatedAt, now),
            onTap: () => widget.onOpenConversation(conversation.id),
            trailing: widget.onConversationAction == null
                ? null
                : ConversationMenu(
                    enabled:
                        !(widget.isConversationBusy?.call(conversation.id) ??
                            false),
                    onSelected: (ConversationMenuAction action) =>
                        widget.onConversationAction!(conversation, action),
                  ),
          );
        },
      ),
    );
  }
}

String _formatUpdatedAt(DateTime updatedAt, DateTime now) {
  final Duration difference = now.difference(updatedAt);
  if (difference < const Duration(minutes: 1)) {
    return '방금 전';
  }
  if (difference < const Duration(hours: 1)) {
    return '${difference.inMinutes}분 전';
  }
  if (difference < const Duration(days: 1)) {
    return '${difference.inHours}시간 전';
  }
  final String month = updatedAt.month.toString().padLeft(2, '0');
  final String day = updatedAt.day.toString().padLeft(2, '0');
  return '${updatedAt.year}.$month.$day';
}
