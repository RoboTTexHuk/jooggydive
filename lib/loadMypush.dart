import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart'
    show AppTrackingTransparency, TrackingStatus;
import 'package:appsflyer_sdk/appsflyer_sdk.dart'
    show AppsFlyerOptions, AppsflyerSdk;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/data/latest.dart' as tzd;
import 'package:timezone/timezone.dart' as tzu;

import 'package:url_launcher/url_launcher.dart' show canLaunchUrl, launchUrl;
import 'package:url_launcher/url_launcher_string.dart';

import 'main.dart' show FILT, FILTER;

// FCM Background Handler
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(RemoteMessage message) async {
  print("BG Message: ${message.messageId}");
  print("BG Data: ${message.data}");
  // You can handle background notification logic here if needed
}

class PushNotificationWebViewPage extends StatefulWidget {
  final String url;
  PushNotificationWebViewPage(this.url, {Key? key}) : super(key: key);

  @override
  State<PushNotificationWebViewPage> createState() =>
      _PushNotificationWebViewPageState(url);
}

class _PushNotificationWebViewPageState
    extends State<PushNotificationWebViewPage> {
  _PushNotificationWebViewPageState(this.initialUrl);

  late InAppWebViewController webViewController;
  String? trackingStatus;
  String? fcmToken;
  String? deviceId;
  String? instanceId;
  String? platformName;
  String? osVersion;
  String? appVersion;
  String? languageCode;
  String? timezone;
  bool pushEnabled = true;
  bool isLoading = false;
  var contentBlockerEnabled = true;
  final List<ContentBlocker> contentBlockers = [];
  String initialUrl;

  @override
  void initState() {
    super.initState();
    _setupContentBlockers();
    FirebaseMessaging.onBackgroundMessage(notificationBackgroundHandler);
    _initializeATT();
    _initializeAppsFlyer();
    _setupNotificationChannel();
    _initializeDeviceData();
    _initializeFCM();
    _setupChannels();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['uri'] != null) {
        _loadWebUrl(message.data['uri'].toString());
      } else {
        _reloadInitialUrl();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['uri'] != null) {
        _loadWebUrl(message.data['uri'].toString());
      } else {
        _reloadInitialUrl();
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      _initializeATT();
    });
    Future.delayed(const Duration(seconds: 6), () {
      _sendAnalyticsToWeb();
    });
  }

  void _setupContentBlockers() {
    for (final adUrlFilter in FILTER) {
      contentBlockers.add(ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: adUrlFilter),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ));
    }

    contentBlockers.add(ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: ".cookie",
        resourceType: [ContentBlockerTriggerResourceType.RAW],
      ),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.BLOCK,
        selector: ".notification",
      ),
    ));

    contentBlockers.add(ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: ".cookie",
        resourceType: [ContentBlockerTriggerResourceType.RAW],
      ),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.CSS_DISPLAY_NONE,
        selector: ".privacy-info",
      ),
    ));

    contentBlockers.add(ContentBlocker(
      trigger: ContentBlockerTrigger(urlFilter: ".*"),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.CSS_DISPLAY_NONE,
        selector: ".banner, .banners, .ads, .ad, .advert",
      ),
    ));
  }

  void _setupNotificationChannel() {
    MethodChannel('com.example.fcm/notification')
        .setMethodCallHandler((call) async {
      if (call.method == "onNotificationTap") {
        final Map<String, dynamic> data =
        Map<String, dynamic>.from(call.arguments);
        if (data["uri"] != null && !data["uri"].contains("Нет URI")) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    PushNotificationWebViewPage(data["uri"])),
                (route) => false,
          );
        }
      }
    });
  }

  void _loadWebUrl(String uri) async {
    if (webViewController != null) {
      await webViewController.loadUrl(
        urlRequest: URLRequest(url: WebUri(uri)),
      );
    }
  }

  void _reloadInitialUrl() async {
    Future.delayed(const Duration(seconds: 3), () {
      if (webViewController != null) {
        webViewController.loadUrl(
          urlRequest: URLRequest(url: WebUri(initialUrl)),
        );
      }
    });
  }

  Future<void> _initializeFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true);
    fcmToken = await messaging.getToken();
  }

  Future<void> _initializeATT() async {
    final TrackingStatus status =
    await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await Future.delayed(const Duration(milliseconds: 1000));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
    final uuid = await AppTrackingTransparency.getAdvertisingIdentifier();
    print("UUID: $uuid");
  }

  AppsflyerSdk? appsFlyerSdk;
  String appsFlyerId = "";
  String conversionData = "";

  void _initializeAppsFlyer() {
    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: "qsBLmy7dAXDQhowM8V3ca4",
      appId: "6745261464",
      showDebug: true,
    );
    appsFlyerSdk = AppsflyerSdk(options);
    appsFlyerSdk?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
    appsFlyerSdk?.startSDK(
      onSuccess: () => print("AppsFlyer OK"),
      onError: (int code, String msg) => print("AppsFlyer ERR $code $msg"),
    );
    appsFlyerSdk?.onInstallConversionData((result) {
      setState(() {
        conversionData = result.toString();
        appsFlyerId = result['payload']['af_status'].toString();
      });
    });
    appsFlyerSdk?.getAppsFlyerUID().then((value) {
      setState(() {
        appsFlyerId = value.toString();
      });
    });
  }

  Future<void> _sendAnalyticsToWeb() async {
    print("CONV DATA: $conversionData");
    final jsonData = {
      "content": {
        "af_data": "$conversionData",
        "af_id": "$appsFlyerId",
        "fb_app_name": "Oneraceright",
        "app_name": "Oneraceright",
        "deep": null,
        "bundle_identifier": "com.raceright.oneraceright",
        "app_version": "1.0.0",
        "apple_id": "6744022823",
        "device_id": deviceId ?? "default_device_id",
        "instance_id": instanceId ?? "default_instance_id",
        "platform": platformName ?? "unknown_platform",
        "os_version": osVersion ?? "default_os_version",
        "app_version": appVersion ?? "default_app_version",
        "language": languageCode ?? "en",
        "timezone": timezone ?? "UTC",
        "push_enabled": pushEnabled,
        "useruid": "$appsFlyerId",
      },
    };

    final jsonString = jsonEncode(jsonData);
    print("My json $jsonString");
    await webViewController.evaluateJavascript(
      source: "sendRawData(${jsonEncode(jsonString)});",
    );
  }

  Future<void> _initializeDeviceData() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        platformName = "android";
        osVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor;
        platformName = "ios";
        osVersion = iosInfo.systemVersion;
      }
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
      languageCode = Platform.localeName.split('_')[0];
      timezone = tzu.local.name;
      instanceId = "d67f89a0-1234-5678-9abc-def012345678";
    } catch (e) {
      debugPrint("Init error: $e");
    }
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              disableDefaultErrorPage: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              allowsPictureInPictureMediaPlayback: true,
              useOnDownloadStart: true,
              contentBlockers: contentBlockers,
              javaScriptCanOpenWindowsAutomatically: true,
            ),
            initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
            onWebViewCreated: (controller) {
              webViewController = controller;
              webViewController.addJavaScriptHandler(
                handlerName: 'onServerResponse',
                callback: (args) {
                  print("JS args: $args");
                  return args.reduce((curr, next) => curr + next);
                },
              );
            },
            onLoadStop: (controller, url) async {
              await controller.evaluateJavascript(
                source: "console.log('Hello from JS!');",
              );
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              return NavigationActionPolicy.ALLOW;
            },
          ),
          if (isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}