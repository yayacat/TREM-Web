import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:localstorage/localstorage.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  // ignore: non_constant_identifier_names
  Timer? _trem_eq_reconnectTimer;
  // ignore: non_constant_identifier_names
  Timer? _eew_reconnectTimer;
  // ignore: close_sinks
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
  final LocalStorage storage = LocalStorage('storage');
  var station_state = '';
  var station_average = 0.0;
  String now = "";
  // ignore: non_constant_identifier_names
  var trem_eq_description = "";
  var eew_description = "";
  FlutterTts flutterTts = FlutterTts();
  double volume = 2;
  double pitch = 1.0;
  double rate = 2;

  void openSocket() async {
    _websocket = WebSocketChannel.connect(Uri.parse(url));
    _socketStatus = SocketStatus.connected;
    if (_reconnectTimer != null) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    if (storage.getItem('UUID') == null){
      final ans = await getuuid('https://exptech.com.tw/api/v1/et/uuid');
      storage.setItem('UUID', ans);
    }
    final station = await get('https://raw.githubusercontent.com/ExpTechTW/API/master/Json/earthquake/station.json');
    print(storage.getItem('UUID'));
    _websocket!.sink.add(json.encode({
			"uuid"     : storage.getItem('UUID'),
			"function" : "subscriptionService",
			"value"    : ["eew-v1", "trem-rts-v2", "palert-v1", "report-v1", "trem-eew-v1", "trem-eq-v1"],
			"key"      : "",
		}));
    // 获取WebSocket的连接消息
    _websocket!.stream.listen((event) async {
      try {
        var data = json.decode(event);
        var type = data['type'];
        // print('data is 👉 $data');
        if (type == 'trem-rts') {
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
          station_state = '$add/$all';
          station_average = add/all * 1000;
          station_average = station_average.round() / 10;
          // toast('$add/$all');
          // toast('$raw');
        } else if (type == 'trem-eq') {
          if (_trem_eq_reconnectTimer != null) {
            _trem_eq_reconnectTimer?.cancel();
            _trem_eq_reconnectTimer = null;
          }
          if (trem_eq_description != ""){
            trem_eq_description = "";
          }
          // toast('$data');
          if (data['cancel']) {
            trem_eq_description += "取消\n";
          } else if (data['alert']) {
            trem_eq_description += "警報\n";
          } else {
            trem_eq_description += "預報\n";
          }
          final now = DateTime.fromMillisecondsSinceEpoch(data['time']).toString()
            .substring(0, 19)
            .replaceAll("-", "/");
          var stateStation = 0;
          trem_eq_description += '\n開始時間 > $now\n\n';
          data['list'].forEach((final String key, final value) {
            trem_eq_description += '${station[key]['Loc']} 最大震度 > ${IntensityI(value)}\n';
            stateStation++;
          });
          trem_eq_description += '\n第 ${data['number']} 報 | ${data['data_count']} 筆數據 ${data['final'] ? "(最終報)" : ""}\n';
		      trem_eq_description += '共 $stateStation 站觸發 | 全部 ${data['total_station']} 站\n';
          final Now = DateTime.fromMillisecondsSinceEpoch(data['timestamp']).toString()
            .substring(0, 19)
            .replaceAll("-", "/");
          trem_eq_description += '現在時間 > $Now';
          _trem_eq_reconnectTimer = Timer(const Duration(seconds: 60), () {
            trem_eq_description = "地震檢知未發報";
          });
        } else if (type != null && type.startsWith("eew") || type == "trem-eew") {
          if (_eew_reconnectTimer != null) {
            _eew_reconnectTimer?.cancel();
            _eew_reconnectTimer = null;
          }
          if (eew_description != ""){
            eew_description = "";
          }
          if (data['type'] == "trem-eew"){
            data['Unit'] = "NSSPE(無震源參數推算)";
          } else if (data['type'] == "eew-cwb"){
            data['Unit'] = "中央氣象局 (CWB)";
          } else if (data['type'] == "eew-fjdzj"){
            data['Unit'] = "福建省地震局 (FJDZJ)";
          } else if (data['type'] == "eew-scdzj"){
            data['Unit'] = "四川省地震局 (SCDZJ)";
          } else if (data['type'] == "eew-kma"){
            data['Unit'] = "기상청(KMA)";
          } else if (data['type'] == "eew-nied"){
            data['Unit'] = "防災科学技術研究所 (NIED)";
          } else if (data['type'] == "eew-jma"){
            data['Unit'] = "気象庁(JMA)";
          }
          final now = DateTime.fromMillisecondsSinceEpoch(data['time']).toString()
            .substring(0, 19)
            .replaceAll("-", "/");
          eew_description += '$now 左右發生顯著有感地震\n東經: ${data['lon']}\n北緯: ${data['lat']}\n深度: ${data['depth']}\n規模: ${data['scale']}\n第${data['number']}報\n發報單位: ${data['Unit']}\n慎防強烈搖晃，就近避難 [趴下、掩護、穩住]';
          // toast('$eew_description');
          Notification.requestPermission().then((String result){
            if(result != 'granted') {
              print('No notification permission granted!');
            } else {
              Notification(eew_description);
            }
          });
          _speak(eew_description);
          print(eew_description);
          _eew_reconnectTimer = Timer(const Duration(seconds: 60), () {
            eew_description = "強震即時警報未發報";
          });
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
      reconnect();
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
      if (_websocket != null) {
        _websocket!.sink.close();
      }
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

  get_station_state() {
    return station_state;
  }

  get_station_average() {
    return station_average;
  }

  gettimenow() {
    return now;
  }

  get_trem_eq_description() {
    return trem_eq_description;
  }

  get_eew_description() {
    return eew_description;
  }

  IntensityI(Intensity) {
    if (Intensity == 5) {
      return "5-";
    } else if (Intensity == 6) {
      return "5+";
    } else if (Intensity == 7) {
      return "6-";
    } else if (Intensity == 8) {
      return "6+";
    } else if (Intensity == 9) {
      return "7";
    } else {
      return Intensity;
    }
  }

  getNotification() {
    Notification.requestPermission().then((String result){
      if(result != 'granted') {
        print('No notification permission granted!');
      } else {
        Notification("允許通知成功");
      }
    });
  }

  Future _speak(eew_description) async {
    await flutterTts.setLanguage('zh-TW');
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setVolume(volume);
    await flutterTts.setPitch(pitch);

    if (eew_description.isNotEmpty) {
      await flutterTts.speak(eew_description);
    }
  }

  getUUID() {
    return storage.getItem('UUID');
  }
}