import 'package:flutter/material.dart';

import '../domain/conversation_summary.dart';
import 'widgets/conversation_list_row.dart';

class ArchivedConversationScreen extends StatelessWidget {
  const ArchivedConversationScreen({
    required this.conversations,
    required this.onBack,
    required this.onOpenConversation,
    super.key,
  });

  final Stream<List<ConversationSummary>> conversations;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: const Text('보관된 대화'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ConversationSummary>>(
          stream: conversations,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<ConversationSummary>> snapshot,
              ) {
                if (snapshot.hasError) {
                  return const _ArchivedState(
                    title: '보관 목록을 불러오지 못했습니다',
                    message: '앱을 다시 시작해 주세요.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<ConversationSummary> items = snapshot.data!;
                if (items.isEmpty) {
                  return const _ArchivedState(
                    title: '보관된 대화가 없습니다',
                    message: '보관한 대화가 이곳에 표시됩니다.',
                  );
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final ConversationSummary conversation = items[index];
                    return ConversationListRow(
                      conversation: conversation,
                      updatedAtLabel: _formatDate(conversation.updatedAt),
                      onTap: () => onOpenConversation(conversation.id),
                    );
                  },
                );
              },
        ),
      ),
    );
  }
}

class _ArchivedState extends StatelessWidget {
  const _ArchivedState({required this.title, required this.message});

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
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year}.$month.$day';
}
