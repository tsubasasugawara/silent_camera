import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:external_path/external_path.dart';

Future<void> main() async {
  // runAppが実行される前に、cameraプラグインを初期化
  WidgetsFlutterBinding.ensureInitialized();

  // デバイスで使用可能なカメラの一覧を取得する
  final cameras = await availableCameras();

  // 利用可能なカメラの一覧から、指定のカメラを取得する
  final firstCamera = cameras.first;

  // ステータスバー、ナビゲーションバーを非表示
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({Key? key, required this.camera}) : super(key: key);
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Home(
        camera: camera,
      ),
    );
  }
}

class Home extends StatefulWidget {
  final CameraDescription camera;

  const Home({super.key, required this.camera});

  @override
  State<StatefulWidget> createState() => HomeState();
}

class HomeState extends State<Home> {
  // デバイスのカメラを制御するコントローラ
  late CameraController _cameraController;
  // コントローラーに設定されたカメラを初期化する関数
  late Future<void> _initializeCameraController;

// 現在のズームレベル
  var _zoomLevel = 0.0;
  double _maxZoomLevel = 0, _minZoomLevel = 0;

  //現在のExposure
  var _exposure = 0.0;
  double _maxExposure = 0, _minExposure = 0;

  // フラッシュモード
  var _flashModeNumber = 0;
  final _flashMode = [
    FlashMode.off,
    FlashMode.always,
    FlashMode.auto,
  ];
  final _flashModeIcons = [
    Icons.flash_off,
    Icons.flash_on,
    Icons.flash_auto,
  ];

  // フォーカスモード
  var _focusModeNumber = 0;
  final _focusMode = [
    FocusMode.auto,
    FocusMode.locked,
  ];
  final _focusModeIcons = [
    Icons.hdr_auto_sharp,
    Icons.center_focus_strong,
  ];

  // Exposureモード
  final _exposureMode = [
    ExposureMode.auto,
    ExposureMode.locked,
  ];

  @override
  void initState() {
    super.initState();

    // コントローラを初期化
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.max,
      enableAudio: false,
    );
    // コントローラーに設定されたカメラを初期化
    _initializeCameraController = Future<void>(() async {
      await _cameraController.initialize();

      _maxZoomLevel = await _cameraController.getMaxZoomLevel();
      _minZoomLevel = await _cameraController.getMinZoomLevel();
      _maxExposure = await _cameraController.getMaxExposureOffset();
      _minExposure = await _cameraController.getMinExposureOffset();

      _zoomLevel = 1.0;
      _exposure = (_maxExposure - _minExposure) / 2 + _minExposure;

      await _cameraController.setFlashMode(_flashMode[_flashModeNumber]);
      await _cameraController.setFocusMode(_focusMode[_focusModeNumber]);
      await _cameraController.setExposureMode(_exposureMode[_focusModeNumber]);
    });
  }

  @override
  void dispose() {
    // ウィジェットが破棄されたタイミングで、カメラのコントローラを破棄する
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FutureBuilderを実装
      body: FutureBuilder<void>(
        future: _initializeCameraController,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (p) async {
                    try {
                      if (_focusModeNumber == 1) {
                        var offset = Offset(
                          p.localPosition.dx /
                              MediaQuery.of(context).size.width,
                          p.localPosition.dy /
                              MediaQuery.of(context).size.height,
                        );
                        await _cameraController.setFocusPoint(offset);
                        await _cameraController.setExposurePoint(offset);
                      }
                    } catch (e) {
                      print(e);
                    }
                  },
                  child: CameraPreview(
                    _cameraController,
                    child: Container(
                      height: _cameraController.value.previewSize!.height,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // Exposure調整バー
                          Align(
                            alignment: Alignment(1, 0),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      _exposure.toStringAsFixed(1) + 'x',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  height:
                                      MediaQuery.of(context).size.height * 0.7,
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Slider(
                                      onChanged: (double value) {
                                        setState(
                                          () {
                                            _exposure = value;
                                            _cameraController
                                                .setExposureOffset(_exposure);
                                          },
                                        );
                                      },
                                      min: _minExposure,
                                      max: _maxExposure,
                                      value: _exposure,
                                      activeColor: Colors.white,
                                      inactiveColor: Colors.white,
                                      thumbColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ズーム調整バー
                          Container(
                            margin: EdgeInsets.only(top: 30),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    onChanged: (double value) {
                                      setState(
                                        () {
                                          _zoomLevel = value;
                                          _cameraController
                                              .setZoomLevel(_zoomLevel);
                                        },
                                      );
                                    },
                                    min: _minZoomLevel,
                                    max: _maxZoomLevel,
                                    value: _zoomLevel,
                                    activeColor: Colors.white,
                                    inactiveColor: Colors.white,
                                    thumbColor: Colors.white,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  margin: EdgeInsets.only(right: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      _zoomLevel.toStringAsFixed(1) + 'x',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // カメラの初期化中はインジケーターを表示
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      // 3つのボタン
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: CircleBorder(),
                  backgroundColor: Colors.white,
                  fixedSize: Size(55, 55),
                ),
                child: Icon(
                  _focusModeIcons[_focusModeNumber],
                  color: Colors.black,
                  size: 30,
                ),
                onPressed: () async {
                  print(_focusModeNumber);
                  setState(() {
                    _focusModeNumber =
                        (_focusModeNumber + 1) % _focusMode.length;
                  });
                  await _cameraController.initialize();
                  await _cameraController
                      .setFlashMode(_flashMode[_flashModeNumber]);
                  await _cameraController
                      .setFocusMode(_focusMode[_focusModeNumber]);
                  await _cameraController
                      .setExposureMode(_exposureMode[_focusModeNumber]);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: CircleBorder(),
                  backgroundColor: Colors.white,
                  fixedSize: Size(80, 80),
                ),
                child: Icon(
                  Icons.photo_camera,
                  color: Colors.black,
                  size: 50,
                ),
                onPressed: () async {
                  var status = await Permission.storage.request();
                  if (status.isDenied ||
                      status.isPermanentlyDenied ||
                      status.isRestricted) {
                    await openAppSettings();
                    return;
                  }
                  print(status);

                  var dir =
                      await ExternalPath.getExternalStoragePublicDirectory(
                          ExternalPath.DIRECTORY_PICTURES);

                  try {
                    // 画像を保存するパスを作成する
                    final path = join(
                      dir,
                      '${DateTime.now().millisecondsSinceEpoch}.jpg',
                    );

                    // カメラで画像を撮影する
                    XFile image = await _cameraController.takePicture();
                    await File(path).writeAsBytes(await image.readAsBytes());

                    await _cameraController.initialize();
                    await _cameraController
                        .setFlashMode(_flashMode[_flashModeNumber]);
                    await _cameraController
                        .setFocusMode(_focusMode[_focusModeNumber]);
                    await _cameraController
                        .setExposureMode(_exposureMode[_focusModeNumber]);
                  } catch (e) {
                    print(e);
                  }
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: CircleBorder(),
                  backgroundColor: Colors.white,
                  fixedSize: Size(55, 55),
                ),
                child: Icon(
                  _flashModeIcons[_flashModeNumber],
                  color: Colors.black,
                  size: 30,
                ),
                onPressed: () async {
                  setState(() {
                    _flashModeNumber =
                        (_flashModeNumber + 1) % _flashModeIcons.length;
                  });
                  await _cameraController
                      .setFlashMode(_flashMode[_flashModeNumber]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
