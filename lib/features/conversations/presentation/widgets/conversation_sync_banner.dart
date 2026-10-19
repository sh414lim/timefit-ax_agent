import 'package:flutter/material.dart';

import '../../application/conversation_list_controller.dart';

class ConversationSyncBanner extends StatelessWidget {
  const ConversationSyncBanner({required this.state, super.key});

  final ConversationListState state;

  @override
  Widget build(BuildContext context) {
    final String message = switch (state) {
      ConversationListState(lastRefreshFailed: true, isOffline: true) =>
        '오프라인입니다. 저장된 대화를 표시합니다.',
      ConversationListState(lastRefreshFailed: true) =>
        '새로고침하지 못했습니다. 저장된 대화를 표시합니다.',
      ConversationListState(isRefreshing: true) =>
        '저장된 대화를 표시하며 최신 내용을 확인하고 있습니다.',
      _ => '저장된 대화를 표시합니다.',
    };

    return Semantics(
      liveRegion: true,
      label: message,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(message)),
              if (state.isRefreshing)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
