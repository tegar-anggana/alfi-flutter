import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran Audio Evaluator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _filePath;
  String? _fileName;
  String? _chosenSurah;
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;
  bool _processing = false;
  String? _result;
  String? _resultCompleteness;
  String? _resultSimilarity;
  final TextEditingController _ipController =
      TextEditingController(text: 'http://192.168.100.6:5000');
  String _ipAddress = 'http://192.168.100.6:5000';

  @override
  void initState() {
    super.initState();
    _player = FlutterSoundPlayer();
    _player!.openAudioSession();
  }

  @override
  void dispose() {
    _player!.closeAudioSession();
    _ipController.dispose();
    super.dispose();
  }

  void _pickFile() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
        _isPlaying = false;
      });
    }
  }

  void _playAudio() async {
    if (_filePath != null && !_isPlaying) {
      await _player!.startPlayer(fromURI: _filePath, codec: Codec.aacADTS);
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pauseAudio() async {
    if (_isPlaying) {
      await _player!.pausePlayer();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _stopAudio() async {
    if (_isPlaying) {
      await _player!.stopPlayer();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _processAudio() async {
    if (_filePath == null || _chosenSurah == null) return;

    setState(() {
      _processing = true; // Start loading indicator
    });

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_ipAddress/process_audio'),
    );
    request.fields['chosen_surah'] = _chosenSurah!;
    request.files.add(await http.MultipartFile.fromPath('file', _filePath!));

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonData = jsonDecode(responseData);
      setState(() {
        // _result = 'Completeness: ${jsonData['completeness_percentage']}%, '
        //     'Similarity: ${jsonData['avg_similarity']}%';
        _resultCompleteness = 'Completeness : ${jsonData['completeness_percentage']}';
        _resultSimilarity = 'Similarity : ${jsonData['avg_similarity']}';
      });
    } else {
      setState(() {
        _result = 'Failed to process audio';
      });
    }

    setState(() {
      _processing = false; // Stop loading indicator
    });
  }

  void _sendRequest() async {
    var response = await http.get(Uri.parse(_ipAddress));
    var body = response.body;
    if (response.statusCode == 200) {
      setState(() {
        _result = 'Server $_ipAddress berjalan, respon : $body';
      });
    } else {
      setState(() {
        _result = 'Failed to send request to $_ipAddress';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Audio Evaluator'),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 20),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'Server IP Address',
                ),
                onSubmitted: (value) {
                  setState(() {
                    _ipAddress = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickFile,
                child: const Text('Upload Audio File (mp3)'),
              ),
              const SizedBox(height: 20),
              if (_fileName != null) ...[
                Text('File terpilih: $_fileName'),
              ],
              const SizedBox(height: 20),
              if (_filePath != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: _playAudio,
                    ),
                    IconButton(
                      icon: const Icon(Icons.pause),
                      onPressed: _pauseAudio,
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed: _stopAudio,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _chosenSurah = value;
                    });
                  },
                  decoration: const InputDecoration(
                      labelText: 'Nama Surah (cont. Al-Ikhlas)'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _processing ? null : _processAudio,
                  child: _processing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, // Adjust thickness if needed
                          ),
                        )
                      : const Text('Process Audio'),
                ),
              ],
              const SizedBox(height: 20),
              if (_resultCompleteness != null) ...[
                Text(_resultCompleteness!),
              ],
              if (_resultSimilarity != null) ...[
                Text(_resultSimilarity!),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: _sendRequest,
                child: Text('Test keadaan server $_ipAddress'),
              ),
              if (_result != null) ...[
                Text(
                  _result!,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
