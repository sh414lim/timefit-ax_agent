import 'package:flutter/material.dart';

import '../application/conversation_list_controller.dart';
import '../domain/conversation_summary.dart';
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
    this.loadOnMount = true,
    this.currentTime,
    super.key,
  });

  final ConversationListController controller;
  final VoidCallback onNewConversation;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenArchive;
  final ValueChanged<String> onOpenConversation;
  final bool loadOnMount;
  final DateTime Function()? currentTime;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('대화'),
        actions: <Widget>[
          Semantics(
            button: true,
            label: '설정 열기',
            excludeSemantics: true,
            child: TextButton(
              onPressed: widget.onOpenSettings,
              child: const Text('설정'),
            ),
          ),
        ],
      ),
      floatingActionButton: _state.phase == ConversationListPhase.empty
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onNewConversation,
              label: const Text('새 대화'),
            ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return switch (_state.phase) {
      ConversationListPhase.loading => Center(
        child: Semantics(
          label: '대화 목록을 불러오는 중',
          child: const CircularProgressIndicator(),
        ),
      ),
      ConversationListPhase.empty => RefreshIndicator(
        onRefresh: widget.controller.refresh,
        child: ConversationStatePanel(
          title: '아직 대화가 없습니다',
          message: '새 대화를 시작하면 이곳에서 다시 확인할 수 있습니다.',
          actionLabel: '새 대화 시작',
          onAction: widget.onNewConversation,
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
      ConversationListPhase.stale => _buildConversationList(),
    };
  }

  Widget _buildConversationList() {
    final DateTime now = widget.currentTime?.call() ?? DateTime.now();
    final bool hasBanner = _state.phase == ConversationListPhase.stale;
    final int conversationOffset = hasBanner ? 1 : 0;
    return RefreshIndicator(
      onRefresh: widget.controller.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _state.conversations.length + conversationOffset + 1,
        separatorBuilder: (BuildContext context, int index) =>
            const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          if (hasBanner && index == 0) {
            return ConversationSyncBanner(state: _state);
          }
          if (index == _state.conversations.length + conversationOffset) {
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
              _state.conversations[index - conversationOffset];
          return ConversationListRow(
            conversation: conversation,
            updatedAtLabel: _formatUpdatedAt(conversation.updatedAt, now),
            onTap: () => widget.onOpenConversation(conversation.id),
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
