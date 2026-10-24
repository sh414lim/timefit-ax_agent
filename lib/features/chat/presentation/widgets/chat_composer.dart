import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/composer_controller.dart';
import 'attachment_chip.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.controller,
    this.onAddAttachment,
    this.onRemoveQueuedAttachment,
    this.onOpenAttachment,
    this.isSelectingAttachments = false,
    this.compactKeyboardLayout = false,
    this.savesLocallyOnly = false,
    super.key,
  });

  final ComposerController controller;
  final VoidCallback? onAddAttachment;
  final Future<void> Function(String localId)? onRemoveQueuedAttachment;
  final void Function(String localId)? onOpenAttachment;
  final bool isSelectingAttachments;
  final bool compactKeyboardLayout;
  final bool savesLocallyOnly;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.controller.draft,
  );
  final FocusNode _focusNode = FocusNode();
  var _controllerGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controllerGeneration += 1;
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

  Future<void> _removeFailedAttachment(String localId) async {
    final ComposerController controller = widget.controller;
    final int controllerGeneration = _controllerGeneration;
    try {
      await controller.removeFailedAttachment(localId);
    } on Object {
      return;
    }
    if (mounted &&
        identical(widget.controller, controller) &&
        _controllerGeneration == controllerGeneration) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _removeQueuedAttachment(String localId) async {
    final Future<void> Function(String localId)? remove =
        widget.onRemoveQueuedAttachment;
    if (remove == null) return;
    final ComposerController controller = widget.controller;
    final int controllerGeneration = _controllerGeneration;
    try {
      await remove(localId);
    } on Object {
      return;
    }
    if (mounted &&
        identical(widget.controller, controller) &&
        _controllerGeneration == controllerGeneration) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ComposerController controller = widget.controller;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    // A five-line field cannot fit between the app chrome and the landscape
    // software keyboard on compact phones. Keep the draft intact and let the
    // field scroll internally until the keyboard is dismissed or the device
    // returns to portrait.
    final bool useCompactInput =
        widget.compactKeyboardLayout ||
        (mediaQuery.orientation == Orientation.landscape &&
            View.of(context).viewInsets.bottom > 0);
    final TextPainter inputLinePainter = TextPainter(
      text: TextSpan(
        text: ' ',
        style:
            Theme.of(context).textTheme.titleMedium ??
            DefaultTextStyle.of(context).style,
      ),
      textDirection: Directionality.of(context),
      textScaler: mediaQuery.textScaler,
      maxLines: 1,
    )..layout();
    final double scaledCompactHeight =
        inputLinePainter.preferredLineHeight + 16;
    inputLinePainter.dispose();
    final double compactInputHeight = scaledCompactHeight < 48
        ? 48
        : scaledCompactHeight;
    final List<ComposerAttachment> visibleAttachments = <ComposerAttachment>[
      ...controller.attachments.where(
        (attachment) => attachment.state == ComposerAttachmentState.failed,
      ),
      ...controller.attachments.where(
        (attachment) => attachment.state != ComposerAttachmentState.failed,
      ),
    ];
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            useCompactInput ? 4 : 8,
            8,
            useCompactInput ? 4 : 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.onRemoveQueuedAttachment != null &&
                  controller.attachments.any(
                    (ComposerAttachment attachment) =>
                        attachment.state == ComposerAttachmentState.queued,
                  )) ...<Widget>[
                const Text(
                  '이 기기에 저장됨 · 서버 미업로드',
                  key: ValueKey<String>('local-attachment-status'),
                ),
                const SizedBox(height: 6),
              ],
              if (controller.attachments.isNotEmpty) ...<Widget>[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (final attachment in visibleAttachments)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ComposerAttachmentChip(
                            attachment: attachment,
                            onOpen: widget.onOpenAttachment == null
                                ? null
                                : () => widget.onOpenAttachment!(
                                    attachment.localId,
                                  ),
                            onRemoveFailed: () => unawaited(
                              _removeFailedAttachment(attachment.localId),
                            ),
                            onRemoveQueued:
                                widget.onRemoveQueuedAttachment == null
                                ? null
                                : () => unawaited(
                                    _removeQueuedAttachment(attachment.localId),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                key: const ValueKey<String>('composer-input-row'),
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (widget.onAddAttachment != null) ...<Widget>[
                    Semantics(
                      button: true,
                      label: widget.isSelectingAttachments
                          ? '첨부 선택 중'
                          : '첨부 추가',
                      child: IconButton.outlined(
                        tooltip: '첨부 추가',
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        onPressed: widget.isSelectingAttachments
                            ? null
                            : widget.onAddAttachment,
                        icon: widget.isSelectingAttachments
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.attach_file),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: useCompactInput ? compactInputHeight : 144,
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: useCompactInput ? null : 5,
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
                          isDense: useCompactInput,
                          contentPadding: useCompactInput
                              ? const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                )
                              : null,
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
                    label: controller.isSubmitting
                        ? '메시지 저장 중'
                        : widget.savesLocallyOnly
                        ? '메시지 저장'
                        : '메시지 보내기',
                    child: IconButton.filled(
                      tooltip: widget.savesLocallyOnly ? '메시지 저장' : '메시지 보내기',
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      onPressed:
                          controller.canSubmit && !widget.isSelectingAttachments
                          ? _submit
                          : null,
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
