import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:trem_web/core/api.dart';

import 'global.dart';
import 'ntp.dart';

int trem_id = 0;
int eew_id = 0;

void OnData(Map _data, String Sender) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  var data = jsonDecode(_data["Data"]);
  if (data["time"] != null || data["timestamp"] != null) {
    data["UTC+8"] =
        DateTime.fromMillisecondsSinceEpoch(data["time"] ?? data["timestamp"])
            .toString()
            .substring(5, 16);
  }
  data["now"] = await Now(false);
  data["Now"] = DateTime.fromMillisecondsSinceEpoch(data["now"])
      .toString()
      .substring(11, 16);
  data["delay"] = double.parse(
      ((await Now(false) - data["timestamp"]) / 1000).toStringAsFixed(1));
  if (data["type"] == "trem-eew") {
    if (prefs.getBool('accept_trem') ?? false) {
      if (data["id"] != trem_id) {
        trem_id = data["id"];
        if (prefs.getBool('audio_trem') ?? false) {
          if (data["delay"] < 240) {
          }
        }
      }
    }
  } else if (data["type"] == "eew-cwb") {
    eew_data = data;
    if (prefs.getBool('accept_eew') ?? false) {
      var ans = await Earthquake(data);
      if (data["id"] != eew_id) {
        eew_id = data["id"];
        if (prefs.getBool('audio_eew') ?? false) {
          if (data["delay"] < 240) {
          }
        }
        if ((prefs.getBool('audio_intensity') ?? false) && ans[0] >= 4) {
          if (data["delay"] < 240) {
          }
        }
      }
      int num = (ans[2] as double).truncate();
      String Num = (num <= 0) ? "抵達 (預警盲區)" : "$num秒 後抵達";
      String intensity = (ans[0] <= 4 || ans[0] == 9)
          ? "${ans[0]}級".replaceAll("9", "7")
          : int_to_intensity(ans[0])
              .toString()
              .replaceAll("+", "強")
              .replaceAll("-", "弱");
    }
  } else if (data["type"] == "report") {
    if (data["location"].toString().contains("TREM") &&
        !(prefs.getBool('accept_report') ?? false)) return;
    String loc = data["location"]
        .toString()
        .substring(data["location"].toString().indexOf("(") + 1,
            data["location"].toString().indexOf(")"))
        .replaceAll("位於", "");
    if (data["location"].toString().startsWith("地震資訊")) {
    } else {
    }
  } else if (data["type"] == "palert-app") {
    if (prefs.getBool('accept_palert') ?? false) {
    }
  }
}
