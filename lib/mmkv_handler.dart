import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mmkv/mmkv_log_level.dart';
import 'package:mmkv/mmkv_recover_strategic.dart';
import 'package:mmkv/mmkv_util.dart';

abstract class MMKVHandler {
  MMKVRecoverStrategic onMMKVCRCCheckFail(String mmapID);
  MMKVRecoverStrategic onMMKVFileLengthError(String mmapID);
  bool wantLogRedirecting();
  void mmkvLog(MMKVLogLevel level, String file, int line, String function,
      String message);
}
