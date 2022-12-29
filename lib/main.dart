import 'package:flutter/material.dart';
import 'package:trem_web/view/init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'TREM Web',
      home: InitPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
