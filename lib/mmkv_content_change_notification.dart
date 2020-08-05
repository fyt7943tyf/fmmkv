import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mmkv/mmkv_util.dart';

abstract class MMKVContentChangeNotification {
  void onContentChangedByOuterProcess(String mmapID);
}
