import 'package:flutter/material.dart';

import '../../domain/chat_message.dart';

class DeliveryBadge extends StatelessWidget {
  const DeliveryBadge({required this.state, super.key});

  final MessageDeliveryState state;

  String get label => switch (state) {
    MessageDeliveryState.pending => '전송 대기 중',
    MessageDeliveryState.uploading => '업로드 중',
    MessageDeliveryState.sending => '전송 중',
    MessageDeliveryState.sent => '전송됨',
    MessageDeliveryState.failed => '전송 실패, 재시도 필요',
  };

  @override
  Widget build(BuildContext context) {
    final bool failed = state == MessageDeliveryState.failed;
    return Semantics(
      label: label,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: failed
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
