import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

typedef Navi_Init_C = ffi.Int32 Function(ffi.Pointer<ffi.Utf8>);
typedef Navi_RAG_C = ffi.Pointer<ffi.Utf8> Function(ffi.Pointer<ffi.Utf8>);
typedef Navi_Free_C = ffi.Void Function(ffi.Pointer<ffi.Utf8>);

extension Utf8Utils on String {
  ffi.Pointer<ffi.Utf8> toUtf8() => ffi.Utf8.toUtf8(this);
}

class NaviEngine {
  late ffi.DynamicLibrary _lib;
  late int Function(ffi.Pointer<ffi.Utf8>) _init;
  late ffi.Pointer<ffi.Utf8> Function(ffi.Pointer<ffi.Utf8>) _rag;
  late void Function(ffi.Pointer<ffi.Utf8>) _free;

  NaviEngine() {
    final libName = Platform.isMacOS
        ? 'libnavi_engine.dylib'
        : Platform.isWindows
            ? 'navi_engine.dll'
            : 'libnavi_engine.so';
    _lib = ffi.DynamicLibrary.open(libName);
    _init =
        _lib.lookupFunction<Navi_Init_C, int Function(ffi.Pointer<ffi.Utf8>)>(
            'Navi_Init');
    _rag = _lib.lookupFunction<Navi_RAG_C,
        ffi.Pointer<ffi.Utf8> Function(ffi.Pointer<ffi.Utf8>)>('Navi_RAG');
    _free = _lib.lookupFunction<Navi_Free_C, void Function(ffi.Pointer<ffi.Utf8>)>(
        'Navi_Free');
  }

  void init(String dbPath) {
    final cfg = jsonEncode({'db_path': dbPath});
    final p = cfg.toUtf8();
    _init(p);
    ffi.malloc.free(p);
  }

  String rag(String question) {
    final q = jsonEncode({'question': question}).toUtf8();
    final resPtr = _rag(q);
    ffi.malloc.free(q);
    final res = ffi.Utf8.fromUtf8(resPtr);
    _free(resPtr);
    return res;
  }
}

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static const _values = {
    'en': {
      'title': 'Navi Assistant',
      'tagline': 'Guiding your tasks, helping you get things done faster',
      'ask': 'Ask (RAG over local chunks)',
      'run': 'Run RAG',
    },
    'zh': {
      'title': 'Navi 助手',
      'tagline': 'Guiding your tasks, 快速帮你完成',
      'ask': '提问（基于本地片段检索）',
      'run': '运行 RAG',
    },
  };

  String get title => _values[locale.languageCode]!['title']!;
  String get tagline => _values[locale.languageCode]!['tagline']!;
  String get ask => _values[locale.languageCode]!['ask']!;
  String get run => _values[locale.languageCode]!['run']!;

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final engine = NaviEngine();
  final ctrl = TextEditingController();
  String output = '';

  @override
  void initState() {
    super.initState();
    final dbPath = '${Directory.current.path}/data/xda.db';
    engine.init(dbPath);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(loc.tagline),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(labelText: loc.ask),
              onSubmitted: (_) => _run(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _run, child: Text(loc.run)),
            const SizedBox(height: 24),
            Expanded(child: SingleChildScrollView(child: Text(output)))
          ],
        ),
      ),
    );
  }

  void _run() {
    final q = ctrl.text.trim();
    if (q.isEmpty) return;
    final res = engine.rag(q);
    setState(() => output = res);
  }
}
