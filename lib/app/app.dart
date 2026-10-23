import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/attachments/application/attachment_picker.dart';
import '../features/attachments/presentation/dev_local_attachment_preview_screen.dart';
import '../src/app_environment.dart';
import 'dev_chat_shell.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class TimeFitApp extends StatefulWidget {
  const TimeFitApp({
    required this.environment,
    this.devDatabaseFactory = openDevChatDatabase,
    this.devAttachmentRootFactory = openDevAttachmentRoot,
    this.devAttachmentPicker,
    this.devPreviewImageRenderer,
    this.devPreviewPdfRenderer,
    this.devDisposalObserver,
    super.key,
  });

  final AppEnvironment environment;
  final DevChatDatabaseFactory devDatabaseFactory;
  final DevAttachmentRootFactory devAttachmentRootFactory;
  final AttachmentPicker? devAttachmentPicker;
  final DevLocalFileRenderer? devPreviewImageRenderer;
  final DevLocalFileRenderer? devPreviewPdfRenderer;
  final DevChatDisposalObserver? devDisposalObserver;

  @override
  State<TimeFitApp> createState() => _TimeFitAppState();
}

class _TimeFitAppState extends State<TimeFitApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    if (widget.environment != AppEnvironment.dev) {
      _router = createTimeFitRouter(widget.environment);
    }
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.environment == AppEnvironment.dev) {
      return MaterialApp(
        debugShowCheckedModeBanner: true,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        title: widget.environment.displayName,
        home: DevChatShell(
          databaseFactory: widget.devDatabaseFactory,
          attachmentRootFactory: widget.devAttachmentRootFactory,
          attachmentPicker: widget.devAttachmentPicker,
          previewImageRenderer: widget.devPreviewImageRenderer,
          previewPdfRenderer: widget.devPreviewPdfRenderer,
          disposalObserver: widget.devDisposalObserver,
        ),
      );
    }
    return MaterialApp.router(
      debugShowCheckedModeBanner: widget.environment == AppEnvironment.dev,
      routerConfig: _router!,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      title: widget.environment.displayName,
    );
  }
}
