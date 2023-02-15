import 'dart:async';
import 'dart:convert';

import 'package:trem_web/core/event.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:localstorage/localstorage.dart';
// import 'package:firebase_core/firebase_core.dart' as firebase;
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:overlay_support/overlay_support.dart';

import '../core/http_get.dart';
import '../core/ntp.dart';

enum SocketStatus {
  connected,
  error,
  closed,
}

class WebSocketUtils {
  final String url;
  Timer? _reconnectTimer;
  // ignore: close_sinks
  final StreamController<SocketStatus> _controller = StreamController<SocketStatus>();
  SocketStatus _socketStatus = SocketStatus.closed;

  SocketStatus get socketStatus => _socketStatus;

  // 初始化
  WebSocketUtils(
    this.url
  ) {
    openSocket();
  }

  WebSocketChannel? _websocket;
  // Function? onOpen;
  // Function? onMessage;
  // Function? onError;

  // void initWebSocket(
  //     {Function? onOpen, Function? onMessage, Function? onError}) {
  //   this.onOpen = onOpen;
  //   this.onMessage = onMessage;
  //   this.onError = onError;
  //   // 连接 -> 接收消息
  //   openSocket();
  // }
  var stationaddall = '';
  String now = "";

  void openSocket() async {
    _websocket = WebSocketChannel.connect(Uri.parse(url));
    _socketStatus = SocketStatus.connected;
    if (_reconnectTimer != null) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    final LocalStorage storage = LocalStorage('storage');
    final ans = await get('https://exptech.com.tw/api/v1/et/uuid');
    final station = await get('https://raw.githubusercontent.com/ExpTechTW/API/master/Json/earthquake/station.json');
    storage.setItem('UUID', ans);
    _websocket!.sink.add(json.encode({
			"uuid"     : storage.getItem('UUID'),
			"function" : "subscriptionService",
			"value"    : ["eew-v1", "trem-rts-v2", "palert-v1", "report-v1", "trem-eew-v1"],
			"key"      : "",
		}));
    // 获取WebSocket的连接消息
    _websocket!.stream.listen((event) async {
      try {
        var data = json.decode(event);
        // print('data is 👉 $data');
        if (data['type'] == 'trem-rts') {
          var raw = data['raw'];
          var add = 0;
          var all = 0;
          station.forEach((final String key, final value) {
            // print(key.split("-")[2]);
            // print(raw[key.split("-")[2]]);
            if (raw[key.split("-")[2]] != null) {
              add++;
            }
            all++;
          });
          now = DateTime.fromMillisecondsSinceEpoch(await Now(false))
            .toString()
            .substring(0, 19)
            .replaceAll("-", "/");
          stationaddall = '$add/$all';
          // toast('$add/$all');
          // toast('$raw');
        }
      } catch (err) {
        print('err is 👉 $err');
      }
      // finally {
      //   if (onMessage != null) onMessage!(event);
      // }
    }, onError: (err) {
      print('err is 👉 $err');
      _socketStatus = SocketStatus.error;
      reconnect();
    }, onDone: () {
      _socketStatus = SocketStatus.closed;
      print('close websocket');
    });
  }

  // 发送消息
  void sendMessage(String message) {
    if (_websocket != null) {
      _websocket!.sink.add(message);
    }
  }

  // 关闭连接
  void closeSocket() {
    if (_websocket != null) {
      _websocket!.sink.close();
    }
  }

  // 断线重连
  void reconnect() {
    _reconnectTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      openSocket();
      print('重新连接中');
    });
  }

  // 手动销毁controller与socket，帮助回收内存
  dispose() {
    closeSocket();
  }

  getstream() {
    return _websocket!.stream;
  }

  getstation() {
    return stationaddall;
  }

  gettimenow() {
    return now;
  }
}