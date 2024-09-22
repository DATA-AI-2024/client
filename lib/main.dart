import 'package:daejeon_taxi/packages/index.dart';
import 'package:daejeon_taxi/presentation/index.dart';
import 'package:daejeon_taxi/res/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(
    clientId: naverMapClientId,
    onAuthFailed: (ex) {
      debugPrint('Naver map init failed');
      debugPrint(ex.toString());
    },
  );
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
