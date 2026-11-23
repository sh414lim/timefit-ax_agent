import 'package:flutter/material.dart';

import '../app/dev_chat_shell.dart';
import '../app/theme/app_theme.dart';

// Explicit owner-only simulator entrypoint. Production and staging never
// construct the personal loopback transport.
void main() => runApp(const PersonalChatDevApp());

class PersonalChatDevApp extends StatelessWidget {
  const PersonalChatDevApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: true,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.system,
    title: 'TimeFit AX personal chat',
    home: const DevChatShell(personalChatOptIn: true),
  );
}
