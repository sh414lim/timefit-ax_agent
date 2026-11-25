import 'package:flutter/material.dart';

import '../../../app/theme/timefit_conversation_visual.dart';
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
    final visual = TimeFitConversationVisual.of(context);
    return Scaffold(
      backgroundColor: branded ? visual.canvas : null,
      appBar: AppBar(
        backgroundColor: branded ? visual.canvas : null,
        foregroundColor: branded ? visual.ink : null,
        surfaceTintColor: branded ? Colors.transparent : null,
        titleSpacing: branded ? 20 : null,
        centerTitle: branded ? false : null,
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        title: Text(
          '대화',
          style: branded ? visual.text(24, weight: FontWeight.w700) : null,
        ),
        actions: <Widget>[
          if (widget.searchController != null)
            IconButton(
              tooltip: '새 채팅',
              onPressed: widget.onNewConversation,
              icon: const Icon(Icons.edit_outlined),
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
            : ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.searchController!,
                builder: (context, value, _) => Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                      child: TextField(
                        controller: widget.searchController,
                        textInputAction: TextInputAction.search,
                        cursorColor: visual.accent,
                        style: visual.text(16),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: visual.muted,
                          ),
                          suffixIcon: value.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '검색어 지우기',
                                  onPressed: widget.searchController!.clear,
                                  icon: Icon(
                                    Icons.cancel_rounded,
                                    color: visual.muted,
                                    size: 20,
                                  ),
                                ),
                          hintText: '대화 제목 또는 메시지 검색',
                          hintStyle: visual.text(16, color: visual.muted),
                          hintMaxLines: 1,
                          filled: true,
                          fillColor: visual.fill,
                          border: visual.fieldBorder,
                          enabledBorder: visual.fieldBorder,
                          focusedBorder: visual.fieldBorder.copyWith(
                            borderSide: BorderSide(color: visual.accent),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(child: _buildBody(value.text)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBody([String query = '']) {
    if (_state.phase == ConversationListPhase.empty &&
        query.trim().isNotEmpty) {
      return _noResults();
    }
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

  Widget _noResults() => ConversationStatePanel(
    compact: true,
    title: '검색 결과가 없습니다',
    message: '다른 대화 제목이나 메시지를 검색해 보세요.',
    actionLabel: '검색 초기화',
    onAction: widget.searchController!.clear,
    secondaryActionLabel: '보관된 대화',
    onSecondaryAction: widget.onOpenArchive,
    icon: Icons.search_rounded,
  );

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
      return _noResults();
    }
    final DateTime now = widget.currentTime?.call() ?? DateTime.now();
    final visual = TimeFitConversationVisual.of(context);
    final branded = widget.searchController != null;
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
        separatorBuilder: (BuildContext context, int index) => branded
            ? Divider(height: 1, indent: 20, endIndent: 20, color: visual.line)
            : const Divider(height: 1),
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
                contentPadding: branded
                    ? const EdgeInsets.symmetric(horizontal: 20)
                    : null,
                leading: branded
                    ? Icon(Icons.inventory_2_outlined, color: visual.secondary)
                    : null,
                trailing: branded
                    ? Icon(Icons.chevron_right_rounded, color: visual.muted)
                    : null,
                title: Text(
                  '보관된 대화',
                  style: branded
                      ? visual.text(15, weight: FontWeight.w600)
                      : null,
                ),
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
