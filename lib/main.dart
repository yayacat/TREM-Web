import 'package:flutter/material.dart';
import 'package:trem_web/view/init.dart';
import 'package:overlay_support/overlay_support.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: MaterialApp(
        title: 'TREM Web',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const InitPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}