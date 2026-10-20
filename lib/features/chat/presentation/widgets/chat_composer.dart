import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/composer_controller.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({required this.controller, super.key});

  final ComposerController controller;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.controller.draft,
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _syncText();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _syncText();
    if (mounted) setState(() {});
  }

  void _syncText() {
    if (_textController.text == widget.controller.draft) return;
    _textController.value = TextEditingValue(
      text: widget.controller.draft,
      selection: TextSelection.collapsed(
        offset: widget.controller.draft.length,
      ),
    );
  }

  void _submit() {
    unawaited(widget.controller.submit().catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    final ComposerController controller = widget.controller;
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 144),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    inputFormatters: const <TextInputFormatter>[
                      _RuneLengthLimitingFormatter(
                        ComposerController.maximumLength,
                      ),
                    ],
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: controller.updateDraft,
                    decoration: InputDecoration(
                      hintText: '메시지 입력',
                      border: const OutlineInputBorder(),
                      counterText: controller.showCounter
                          ? '${controller.characterCount}/${ComposerController.maximumLength}'
                          : '',
                      errorText: controller.lastError == null
                          ? null
                          : '메시지를 저장하지 못했습니다. 다시 시도해 주세요.',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: controller.isSubmitting ? '메시지 저장 중' : '메시지 보내기',
                child: IconButton.filled(
                  tooltip: '메시지 보내기',
                  onPressed: controller.canSubmit ? _submit : null,
                  icon: controller.isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _RuneLengthLimitingFormatter extends TextInputFormatter {
  const _RuneLengthLimitingFormatter(this.maximumLength);

  final int maximumLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    if (ComposerController.characterCountOf(newValue.text) <= maximumLength) {
      return newValue;
    }
    final String limited = ComposerController.truncateDraft(newValue.text);
    final int selectionOffset = newValue.selection.extentOffset.clamp(
      0,
      limited.length,
    );
    return TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }
}
