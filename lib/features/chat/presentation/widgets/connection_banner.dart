import 'package:flutter/material.dart';

import '../../application/chat_connection_controller.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    required this.state,
    required this.onRetry,
    super.key,
  });

  final ChatConnectionState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!state.showBanner) return const SizedBox.shrink();
    final message = _message(state);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: message,
      child: Material(
        color: colors.secondaryContainer,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
            child: Row(
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(
                    _icon(state.phase),
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onSecondaryContainer),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Semantics(
                  button: true,
                  label: state.isRetrying ? '실시간 연결 다시 시도 중' : '실시간 연결 다시 시도',
                  child: TextButton(
                    onPressed: state.isRetrying ? null : onRetry,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(state.isRetrying ? '시도 중' : '다시 시도'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _message(ChatConnectionState state) {
  final suffix = state.rpcAvailable
      ? ' 메시지는 계속 보낼 수 있습니다.'
      : ' 메시지 전송 연결도 확인해 주세요.';
  return switch (state.phase) {
    ChatConnectionPhase.joining => '실시간 연결이 지연되고 있습니다.$suffix',
    ChatConnectionPhase.disconnected => '실시간 연결이 끊겼습니다.$suffix',
    ChatConnectionPhase.polling => '실시간 연결 대신 새 메시지를 확인 중입니다.$suffix',
    ChatConnectionPhase.connected || ChatConnectionPhase.background => '',
  };
}

IconData _icon(ChatConnectionPhase phase) => switch (phase) {
  ChatConnectionPhase.polling => Icons.sync,
  ChatConnectionPhase.joining => Icons.cloud_sync_outlined,
  ChatConnectionPhase.disconnected => Icons.cloud_off_outlined,
  ChatConnectionPhase.connected ||
  ChatConnectionPhase.background => Icons.cloud_done_outlined,
};
