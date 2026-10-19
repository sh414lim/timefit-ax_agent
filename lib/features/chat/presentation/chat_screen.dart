import 'package:flutter/material.dart';

import '../domain/chat_message.dart';
import 'widgets/message_list.dart';

enum ChatScreenStatus { ready, error, accessRevoked }

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    required this.title,
    required this.messages,
    this.status = ChatScreenStatus.ready,
    this.scrollController,
    super.key,
  });

  final String title;
  final Stream<List<ChatMessage>> messages;
  final ChatScreenStatus status;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (status == ChatScreenStatus.accessRevoked) {
      return const _ChatState(
        title: '대화에 접근할 수 없습니다',
        message: '대화 접근 권한이 변경되었습니다.',
      );
    }
    if (status == ChatScreenStatus.error) {
      return const _ChatState(
        title: '메시지를 표시하지 못했습니다',
        message: '잠시 후 다시 시도해 주세요.',
      );
    }
    return StreamBuilder<List<ChatMessage>>(
      stream: messages,
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
              messages: ordered,
              scrollController: scrollController,
            );
          },
    );
  }
}

List<ChatMessage> _ordered(List<ChatMessage> source) {
  final Map<int, ChatMessage> bySequence = <int, ChatMessage>{};
  for (final ChatMessage message in source) {
    bySequence[message.sequence] = message;
  }
  final List<ChatMessage> result = bySequence.values.toList()
    ..sort((ChatMessage a, ChatMessage b) => a.sequence.compareTo(b.sequence));
  return List<ChatMessage>.unmodifiable(result);
}

class _ChatState extends StatelessWidget {
  const _ChatState({required this.title, required this.message});

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
