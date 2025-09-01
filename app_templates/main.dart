import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

typedef XDA_Init_C = ffi.Int32 Function(ffi.Pointer<ffi.Utf8>);
typedef XDA_RAG_C = ffi.Pointer<ffi.Utf8> Function(ffi.Pointer<ffi.Utf8>);
typedef XDA_Free_C = ffi.Void Function(ffi.Pointer<ffi.Utf8>);

extension Utf8Utils on String {
  ffi.Pointer<ffi.Utf8> toUtf8() => ffi.Utf8.toUtf8(this);
}

class XDA {
  late ffi.DynamicLibrary _lib;
  late int Function(ffi.Pointer<ffi.Utf8>) _init;
  late ffi.Pointer<ffi.Utf8> Function(ffi.Pointer<ffi.Utf8>) _rag;
  late void Function(ffi.Pointer<ffi.Utf8>) _free;

  XDA() {
    final libName = Platform.isMacOS ? 'libxda.dylib' :
                    Platform.isWindows ? 'xda.dll' : 'libxda.so';
    _lib = ffi.DynamicLibrary.open(libName);
    _init = _lib.lookupFunction<XDA_Init_C, int Function(ffi.Pointer<ffi.Utf8>)>('XDA_Init');
    _rag = _lib.lookupFunction<XDA_RAG_C, ffi.Pointer<ffi.Utf8> Function(ffi.Pointer<ffi.Utf8>)>('XDA_RAG');
    _free = _lib.lookupFunction<XDA_Free_C, void Function(ffi.Pointer<ffi.Utf8>)>('XDA_Free');
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

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final xda = XDA();
  final ctrl = TextEditingController();
  String output = '';
  @override
  void initState() {
    super.initState();
    final dbPath = '${Directory.current.path}/data/xda.db';
    xda.init(dbPath);
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('XDesktopAgent (demo)')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Ask (RAG over local chunks)',
                ),
                onSubmitted: (_) => _run(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _run, child: const Text('Run RAG')),
              const SizedBox(height: 24),
              Expanded(child: SingleChildScrollView(child: Text(output)))
            ],
          ),
        ),
      ),
    );
  }

  void _run() {
    final q = ctrl.text.trim();
    if (q.isEmpty) return;
    final res = xda.rag(q);
    setState(() => output = res);
  }
}
