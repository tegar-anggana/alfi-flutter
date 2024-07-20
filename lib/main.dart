import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_alfi/recorder_audio/audio_player.dart';
import 'package:mobile_alfi/recorder_audio/audio_recorder.dart';

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
  // record thing
  bool showPlayer = false;
  String? audioPath;
  // end

  String? _filePath;
  String? _fileName;
  bool _processing = false;
  String? _result;
  String? _resultCompleteness;
  String? _resultSimilarity;
  int _selectedOption = 1; // 0: Upload, 1: Record
  final TextEditingController _ipController =
      TextEditingController(text: 'http://192.168.100.6:5000');
  String _ipAddress = 'http://192.168.100.6:5000';

  List<String> _surahOptions = [];
  String? _selectedSurahOption;


  @override
  void initState() {
    showPlayer = false;
    super.initState();
    _fetchOptions();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _fetchOptions() async {
    final response = await http.get(Uri.parse('$_ipAddress/surahs'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        _surahOptions = List<String>.from(data);
      });
    } else {
      // Handle the error
      print('Failed to load options');
    }
  }


  void _pickFile() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      setState(() {
        audioPath = result.files.single.path;
        showPlayer = true;
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  void _onStopRecording(path) async {
    if (kDebugMode) print('Recorded file path: $path');
    setState(() {
      audioPath = path;
      showPlayer = true;
      _filePath = audioPath;
      _fileName = audioPath!.split('/').last;
    });
  }

  void _processAudio() async {
    if (_filePath == null || _selectedSurahOption == null) return;

    setState(() {
      _processing = true; // Start loading indicator
    });

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_ipAddress/upload'),
    );
    request.fields['surah'] = _selectedSurahOption!;
    request.files.add(await http.MultipartFile.fromPath('file', _filePath!));

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonData = jsonDecode(responseData);
      setState(() {
        _resultCompleteness =
            'Persentase Kelengkapan : ${jsonData['persentase_kelengkapan']}';
        _resultSimilarity = 'Status Lulus : ${jsonData['status_kelulusan']}';
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
            children: [
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
              const Text(
                'Persiapan Audio',
                textAlign: TextAlign.start,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedOption = 0;
                        showPlayer = false; // Reset player when switching mode
                        _filePath = null;
                        _fileName = null;
                      });
                    },
                    child: Row(
                      children: [
                        Radio<int>(
                          value: 0,
                          groupValue: _selectedOption,
                          onChanged: (int? value) {
                            setState(() {
                              _selectedOption = value!;
                              showPlayer =
                                  false; // Reset player when switching mode
                              _filePath = null;
                              _fileName = null;
                            });
                          },
                        ),
                        const Text('Upload Audio'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedOption = 1;
                        showPlayer = false; // Reset player when switching mode
                        _filePath = null;
                        _fileName = null;
                      });
                    },
                    child: Row(
                      children: [
                        Radio<int>(
                          value: 1,
                          groupValue: _selectedOption,
                          onChanged: (int? value) {
                            setState(() {
                              _selectedOption = value!;
                              showPlayer =
                                  false; // Reset player when switching mode
                              _filePath = null;
                              _fileName = null;
                            });
                          },
                        ),
                        const Text('Record Audio'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _selectedOption == 1
                  ? Center(
                      child: showPlayer
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 25),
                              child: AudioPlayer(
                                source: audioPath!,
                                onDelete: () {
                                  setState(() => showPlayer = false);
                                },
                              ),
                            )
                          : Recorder(
                              onStop: (path) {
                                _onStopRecording(path);
                              },
                            ),
                    )
                  : Column(
                      children: [
                        ElevatedButton(
                          onPressed: _pickFile,
                          child: const Text('Upload Audio File (mp3 / wav)'),
                        ),
                        const SizedBox(height: 20),
                        showPlayer
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 25),
                                child: AudioPlayer(
                                  source: audioPath!,
                                  onDelete: () {
                                    setState(() => showPlayer = false);
                                  },
                                ),
                              )
                            : const Text('')
                      ],
                    ),
              const SizedBox(height: 20),
              if (_fileName != null) ...[
                Text('File terpilih: $_fileName'),
              ],
              const SizedBox(height: 20),
              if (_filePath != null) ...[
                const SizedBox(height: 20),
                const Text(
                  'Pilih Surah',
                  textAlign: TextAlign.start,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                DropdownButton(
                  value: _selectedSurahOption,
                  hint: const Text('Pilih Surah'),
                  items: _surahOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSurahOption = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                // TextField(
                //   onChanged: (value) {
                //     setState(() {
                //       _chosenSurah = value;
                //     });
                //   },
                //   decoration: const InputDecoration(
                //       labelText: 'Nama Surah (cont. Al-Ikhlas)'),
                // ),
                const SizedBox(height: 20),
                const Text(
                  'Cek Hasil',
                  textAlign: TextAlign.start,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                FilledButton(
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
                const SizedBox(height: 20),
                if (_resultCompleteness != null) ...[
                  Text(_resultCompleteness!),
                ],
                if (_resultSimilarity != null) ...[
                  Text(_resultSimilarity!),
                ],
                const SizedBox(height: 20),
              ],
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
