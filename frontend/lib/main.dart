import 'package:flutter/material.dart';

import 'app.dart';
import 'services/auth_service.dart';

export 'app.dart';
export 'pages/dashboard_page.dart';
export 'shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  runApp(const MyApp());
}
