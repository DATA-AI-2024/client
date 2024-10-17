import 'dart:io';

import 'package:daejeon_taxi/presentation/view/splash_page.dart';
import 'package:daejeon_taxi/res/key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    await NaverMapSdk.instance.initialize(
      clientId: naverMapClientId,
      onAuthFailed: (ex) {
        debugPrint('Naver map init failed');
        debugPrint(ex.toString());
      },
    );
  }
  runApp(
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}
