import 'dart:ffi';

import 'package:ffi/ffi.dart';

class MMKVUtil {
  static String ptr2String(Pointer<Utf8> ptr, {bool clear = true}) {
    String ans;
    if (ptr.address != 0) {
      ans = Utf8.fromUtf8(ptr);
      if (clear == true) {
        free(ptr);
      }
    }
    return ans;
  }
}