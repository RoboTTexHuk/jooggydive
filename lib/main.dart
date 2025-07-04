import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:app_tracking_transparency/app_tracking_transparency.dart'
    show AppTrackingTransparency, TrackingStatus;
import 'package:appsflyer_sdk/appsflyer_sdk.dart'
    show AppsFlyerOptions, AppsflyerSdk;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_circular_progress_indicator/flutter_circular_progress_indicator.dart'
    show CircularProgressInd;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:jooggydive/GameMENU.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/data/latest.dart' as tzData;
import 'package:timezone/timezone.dart' as tz;
import 'package:progress_bar_countdown/progress_bar_countdown.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_offline/flutter_offline.dart';

// ---- ДЛЯ ПРИМЕРА: можно убрать, если нет файла ----
import 'loadMypush.dart' show PushNotificationWebViewPage;

// --------- TOKEN CHANNEL SERVICE -------------
class TokenChannelService {
  static const MethodChannel _channel = MethodChannel('com.example.fcm/token');
  void listenToken(Function(String token) onToken) {
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'setToken') {
          final String token = call.arguments as String;
          onToken(token);
        }
      });
    } catch (e, stack) {
      print("TokenChannelService.listenToken error: $e\n$stack");
    }
  }
}

// --------- SINGLETON PATTERN: Service Locator -------------
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();

  factory ServiceLocator() => _instance;

  ServiceLocator._internal();

  final DeviceRepository deviceRepo = DeviceRepository();
  final AnalyticsViewModel analyticsVM = AnalyticsViewModel();
  final PushNotificationManager pushManager = PushNotificationManager();
}

// --------- REPOSITORY PATTERN: Device Info -------------
class DeviceRepository {
  Future<DeviceEntity> fetchDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String? deviceId, osType, osVersion;
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      deviceId = info.id;
      osType = "android";
      osVersion = info.version.release;
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      deviceId = info.identifierForVendor;
      osType = "ios";
      osVersion = info.systemVersion;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    final language = Platform.localeName.split('_')[0];
    final timezone = tz.local.name;
    return DeviceEntity(
      deviceId: deviceId ?? 'no_device',
      instanceId: "instance-${DateTime.now().millisecondsSinceEpoch}",
      osType: osType ?? 'unknown',
      osVersion: osVersion ?? 'unknown',
      appVersion: packageInfo.version,
      language: language,
      timezone: timezone,
      pushEnabled: true,
    );
  }
}

// --------- ENTITY PATTERN: Device Info -------------
class DeviceEntity {
  final String? deviceId;
  final String? instanceId;
  final String? osType;
  final String? osVersion;
  final String? appVersion;
  final String? language;
  final String? timezone;
  final bool pushEnabled;

  DeviceEntity({
    this.deviceId,
    this.instanceId,
    this.osType,
    this.osVersion,
    this.appVersion,
    this.language,
    this.timezone,
    required this.pushEnabled,
  });

  Map<String, dynamic> toJson({String? fcmToken}) => {
    "fcm_token": fcmToken ?? "no_fcm_token",
    "device_id": deviceId ?? 'no_device',
    "app_name": "Jooggydive",
    "instance_id": instanceId ?? 'no_instance',
    "platform": osType ?? 'no_type',
    "os_version": osVersion ?? 'no_os',
    "app_version": appVersion ?? 'no_app',
    "language": language ?? 'en',
    "timezone": timezone ?? 'UTC',
    "push_enabled": pushEnabled,
  };
}

// --------- VIEWMODEL: AppsFlyer -------------
class AnalyticsViewModel extends ChangeNotifier {
  AppsflyerSdk? _sdk;
  String appsFlyerId = "";
  String conversionData = "";

  void init(VoidCallback onUpdate) {
    final options = AppsFlyerOptions(
      afDevKey: "qsBLmy7dAXDQhowM8V3ca4",
      appId: "6746640362",
      showDebug: true,
    );
    _sdk = AppsflyerSdk(options);
    _sdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
    _sdk?.startSDK(
      onSuccess: () => print("AppsFlyer started"),
      onError: (int code, String msg) => print("AppsFlyer error $code $msg"),
    );
    _sdk?.onInstallConversionData((result) {
      conversionData = result.toString();
      onUpdate();
    });
    _sdk?.getAppsFlyerUID().then((val) {
      appsFlyerId = val.toString();
      onUpdate();
    });
  }
}

// --------- FACTORY PATTERN: PushNotificationManager -------------
class PushNotificationManager extends ChangeNotifier {
  String? _fcmToken;
  bool isLoading = true;
  final TokenChannelService _tokenChannelService = TokenChannelService();

  String? get fcmToken => _fcmToken;

  Future<void> fetchFcmToken({Function(String)? onToken}) async {
    try {
      _tokenChannelService.listenToken((token) {
        _fcmToken = token;
        isLoading = false;
        notifyListeners();
        if (onToken != null) onToken(token);
      });
      Future.delayed(const Duration(seconds: 8), () {
        if (isLoading) {
          isLoading = false;
          _fcmToken = "";
          notifyListeners();
          if (onToken != null) onToken("");
        }
      });
    } catch (e, stack) {
      print("PushNotificationManager.fetchFcmToken error: $e\n$stack");
      isLoading = false;
      _fcmToken = "";
      notifyListeners();
      if (onToken != null) onToken("");
    }
  }
}

// --------- PROVIDER PATTERN: Loader State Management -------------
class LoaderProvider extends ChangeNotifier {
  double progress = 0.0;

  void setProgress(double value) {
    progress = value;
    notifyListeners();
  }
}

// --------- ATT SCREEN -------------
class AttScreen extends StatefulWidget {
  const AttScreen({Key? key}) : super(key: key);

  @override
  State<AttScreen> createState() => _AttScreenState();
}

class _AttScreenState extends State<AttScreen> {
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _checkATT();
  }

  Future<void> _checkATT() async {
    TrackingStatus status = TrackingStatus.notDetermined;
    try {
      status = await AppTrackingTransparency.trackingAuthorizationStatus;
    } catch (e) {
      status = TrackingStatus.notSupported;
    }
    setState(() {
      _status = status.toString();
    });
    if (status == TrackingStatus.authorized ||
        status == TrackingStatus.denied ||
        status == TrackingStatus.restricted ||
        status == TrackingStatus.notSupported) {
      _goNext();
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _requestATT() async {
    setState(() {
      _loading = true;
    });
    try {
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (e) {}
    _goNext();
  }

  void _goNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MyRootApp()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Allow tracking to receive personalized offers and advertisements. You can always change your choice in the settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _requestATT,
                child: const Text('Next'),
              ),
              const SizedBox(height: 24),
              if (_status.isNotEmpty)
                Text(
                  '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------- MAIN ENTRY -------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  tzData.initializeTimeZones();

  runApp(MaterialApp(
    home: AttScreen(),
  //  home: JooggyDiveHome(),
    debugShowCheckedModeBanner: false,
  ));
}

// --------- ROOT WIDGET -------------
class MyRootApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DeviceBootstrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --------- INIT PAGE WITH LOADER -------------
class DeviceBootstrapper extends StatefulWidget {
  @override
  State<DeviceBootstrapper> createState() => _DeviceBootstrapperState();
}

class _DeviceBootstrapperState extends State<DeviceBootstrapper> {
  final _pushManager = ServiceLocator().pushManager;
  final LoaderProvider _loaderProvider = LoaderProvider();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _initApp();
    _setupChannels();
  }
  void _setupChannels() {
    MethodChannel('com.example.fcm/notification').setMethodCallHandler(
          (call) async {
        if (call.method == "onNotificationTap") {
          final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
          if (data["uri"] != null && !data["uri"].contains("Нет URI")) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => PushNotificationWebViewPage(data["uri"]),
              ),
                  (route) => false,
            );
          }
        }
      },
    );}
  Future<void> _initApp() async {
    _loaderProvider.setProgress(0.1);

    final settings = await FirebaseMessaging.instance.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _pushManager.fetchFcmToken(onToken: (token) {
        _navigateOnce(token ?? "");
      });
    } else {
      _navigateOnce("");
    }
  }

  void _navigateOnce(String token) {
    if (!_navigated) {
      _navigated = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainWebContainer(
            fcmToken: token,
            loaderProvider: _loaderProvider,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loaderProvider,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox(
            width: 240,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressInd().normalCircular(
                    height: 80,
                    width: 80,
                    isSpining: true,
                    value: .01,
                    secondaryColor: const Color.fromARGB(255, 23, 82, 27),
                    secondaryWidth: 10,
                    backgroundShape: BoxShape.rectangle,
                    backgroundRadius: 10,
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.all(10),
                    valueColor: Colors.green[200],
                    backgroundBorder: Border.all(
                        color: const Color.fromARGB(255, 23, 82, 27), width: 3),
                    valueWidth: 6),
                const SizedBox(height: 16),
                const Text(
                  "Loading, please wait...",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------- MAIN WEBVIEW SCREEN c flutter_offline -------------
class MainWebContainer extends StatefulWidget {
  final String? fcmToken;
  final LoaderProvider loaderProvider;

  const MainWebContainer({
    super.key,
    required this.fcmToken,
    required this.loaderProvider,
  });

  @override
  State<MainWebContainer> createState() => _MainWebContainerState();
}

class _MainWebContainerState extends State<MainWebContainer> {
  late final DeviceEntity _deviceEntity;

  final _analyticsVM = ServiceLocator().analyticsVM;
  late final MainWebViewModel _webVM;
  final String _webUrl = "https://gameapi.seadiver.club";
  bool _initialized = false;
  final ProgressBarCountdownController controller = ProgressBarCountdownController();
  final List<ContentBlocker> contentBlockers = [];

  @override
  void initState() {
    super.initState();

    _blockContent();
    _webVM = MainWebViewModel();
    _initialize();
    _setupChannels();
  }

  void _setupChannels() {
    MethodChannel('com.example.fcm/notification').setMethodCallHandler(
          (call) async {
        if (call.method == "onNotificationTap") {
          final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments);
          if (data["uri"] != null && !data["uri"].contains("Нет URI")) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => PushNotificationWebViewPage(data["uri"]),
              ),
                  (route) => false,
            );
          }
        }
      },
    );
  }

  void _blockContent() {
    for (final adUrlFilter in FILTER) {
      contentBlockers.add(ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: adUrlFilter,
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.BLOCK,
          )));
    }

    contentBlockers.add(ContentBlocker(
      trigger: ContentBlockerTrigger(urlFilter: ".cookie", resourceType: [
        ContentBlockerTriggerResourceType.RAW
      ]),
      action: ContentBlockerAction(
          type: ContentBlockerActionType.BLOCK, selector: ".notification"),
    ));

    contentBlockers.add(ContentBlocker(
      trigger: ContentBlockerTrigger(urlFilter: ".cookie", resourceType: [
        ContentBlockerTriggerResourceType.RAW
      ]),
      action: ContentBlockerAction(
          type: ContentBlockerActionType.CSS_DISPLAY_NONE,
          selector: ".privacy-info"),
    ));
    contentBlockers.add(ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: ".*",
        ),
        action: ContentBlockerAction(
            type: ContentBlockerActionType.CSS_DISPLAY_NONE,
            selector: ".banner, .banners, .ads, .ad, .advert")));
  }

  Future<void> _initialize() async {
    _webVM.setLoading(true);
    _deviceEntity = await ServiceLocator().deviceRepo.fetchDeviceInfo();
    _analyticsVM.init(() {
      setState(() {});
    });
    await Future.delayed(const Duration(seconds: 1));
    _webVM.setLoading(false);
    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBuilder(
      connectivityBuilder: (
          BuildContext context,
          ConnectivityResult connectivity,
          Widget child,
          ) {
        final bool connected = connectivity != ConnectivityResult.none;
        return Stack(
          children: [
            if (_initialized && connected)
              SafeArea(
                child: InAppWebView(
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    disableDefaultErrorPage: true,
                    contentBlockers: contentBlockers,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    allowsPictureInPictureMediaPlayback: true,
                    useOnDownloadStart: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                  ),
                  initialUrlRequest: URLRequest(url: WebUri(_webUrl)),
                  onWebViewCreated: (controller) {
                    _webVM.webViewController = controller;

                    _webVM.webViewController?.addJavaScriptHandler(
                        handlerName: 'onServerResponse',
                        callback: (args) {
                          // Here you receive all the arguments from the JavaScript side
                          // that is a List<dynamic>
                          print("From the JavaScript side:");
                          print("ResRes"+args[0]['savedata'].toString());

                          if(args[0]['savedata'].toString()=="false"){

                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JooggyDiveHome(),
                              ),
                                  (route) => false,
                            );

                          }
                          return args.reduce((curr, next) => curr + next);


                        });
                  },
                  onLoadStart: (controller, url) {
                    _webVM.setLoading(true);
                    widget.loaderProvider.setProgress(0.3);
                  },
                  onLoadStop: (controller, url) async {
                    _webVM.setLoading(false);
                    widget.loaderProvider.setProgress(1.0);
                    await _webVM.injectDeviceData(_deviceEntity, widget.fcmToken);

                    await controller.evaluateJavascript(
                      source: """
            console.log('Hello from JavaScript!');
            console.error('This is an error log from JavaScript!');
          """,
                    );
                    Future.delayed(const Duration(seconds: 6), () {
                      _webVM.sendRawAnalyticsToWeb(
                        analyticsVM: _analyticsVM,
                        deviceEntity: _deviceEntity,
                        fcmToken: widget.fcmToken,
                      );
                    });
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    return NavigationActionPolicy.ALLOW;
                  },
                ),
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: connected
                  ? const SizedBox.shrink()
                  : Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Container(
                    color: Colors.redAccent,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.wifi_off, color: Colors.white, size: 30),
                        SizedBox(width: 12),
                        Text(
                          "No internet connection",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}

// --------- VIEWMODEL: WebView -------------
class MainWebViewModel extends ChangeNotifier {
  bool isLoading = false;
  InAppWebViewController? webViewController;

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  Future<void> injectDeviceData(DeviceEntity entity, String? fcmToken) async {
    final dataMap = entity.toJson(fcmToken: fcmToken);
    await webViewController?.evaluateJavascript(source: '''
      localStorage.setItem('app_data', JSON.stringify(${jsonEncode(dataMap)}));
    ''');
  }

  Future<void> sendRawAnalyticsToWeb({
    required AnalyticsViewModel analyticsVM,
    required DeviceEntity deviceEntity,
    String? fcmToken,
  }) async {
    final data = {
      "content": {
        "af_data": analyticsVM.conversionData,
        "af_id": analyticsVM.appsFlyerId,
        "fb_app_name": "Jooggydive",
        "app_name": "Jooggydive",
        "deep": null,
        "bundle_identifier": "com.jooggydive.ggydive.jooggydive",
        "app_version": "1.0.0",
        "apple_id": "6746640362",
        "fcm_token": fcmToken ?? "no_fcm_token",
        "device_id": deviceEntity.deviceId ?? "no_device",
        "instance_id": deviceEntity.instanceId ?? "no_instance",
        "platform": deviceEntity.osType ?? "no_type",
        "os_version": deviceEntity.osVersion ?? "no_os",
        "app_version": deviceEntity.appVersion ?? "no_app",
        "language": deviceEntity.language ?? "en",
        "timezone": deviceEntity.timezone ?? "UTC",
        "push_enabled": deviceEntity.pushEnabled,
        "useruid": analyticsVM.appsFlyerId,
      },
    };
    final jsonString = jsonEncode(data);
    print("lll jjj$jsonString");
    final result = await webViewController!.evaluateJavascript(
      source: "sendRawData(${jsonEncode(jsonString)});",
    );
    print('Ответ из JS: $result');
      try {
        final decoded = jsonDecode(result);
        print('Decoded result: $decoded');
      } catch (e) {
        print('Result is not JSON: $result');
      }

  //  return result?.toString();
  }
}

// --------- FCM BG Handler -------------
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage msg) async {
  print("BG Message: ${msg.messageId}");
  print("BG Data: ${msg.data}");
}
final FILTER = [
  ".*.doubleclick.net/.*",
  ".*.ads.pubmatic.com/.*",
  ".*.googlesyndication.com/.*",
  ".*.google-analytics.com/.*",
  ".*.adservice.google.*/.*",
  ".*.adbrite.com/.*",
  ".*.exponential.com/.*",
  ".*.quantserve.com/.*",
  ".*.scorecardresearch.com/.*",
  ".*.zedo.com/.*",
  ".*.adsafeprotected.com/.*",
  ".*.teads.tv/.*",
  ".*.outbrain.com/.*",
];