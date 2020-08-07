import 'dart:async';
import 'dart:collection';
import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mmkv/mmkv_content_change_notification.dart';
import 'package:mmkv/mmkv_handler.dart';
import 'package:mmkv/mmkv_log_level.dart';
import 'package:mmkv/mmkv_recover_strategic.dart';
import 'package:mmkv/mmkv_util.dart';
import 'package:path_provider/path_provider.dart';

class StringList extends Struct {
  @Int64()
  int length;

  Pointer<Pointer<Utf8>> data;

  factory StringList.allocate(int length, Pointer<Pointer<Utf8>> data) =>
      allocate<StringList>().ref
        ..length = length
        ..data = data;
}

class ByteList extends Struct {
  @Int64()
  int length;

  Pointer<Uint8> data;

  factory ByteList.allocate(int length, Pointer<Uint8> data) =>
      allocate<ByteList>().ref
        ..length = length
        ..data = data;
}

class MMKV {
  static const int SINGLE_PROCESS_MODE = 0x1;
  static const int MULTI_PROCESS_MODE = 0x2;
  static const int _CONTEXT_MODE_MULTI_PROCESS = 0x4;
  static const int _ASHMEM_MODE = 0x8;
  static String _rootDir;
  static String get rootDir => _rootDir;
  static HashSet<int> _checkedHandleSet = HashSet();
  static HashMap<MMKVLogLevel, int> _logLevel2Index = HashMap.from({
    MMKVLogLevel.LevelDebug: 0,
    MMKVLogLevel.LevelInfo: 1,
    MMKVLogLevel.LevelWarning: 2,
    MMKVLogLevel.LevelError: 3,
    MMKVLogLevel.LevelNone: 4,
  });
  static List<MMKVLogLevel> _index2LogLevel = [
    MMKVLogLevel.LevelDebug,
    MMKVLogLevel.LevelInfo,
    MMKVLogLevel.LevelWarning,
    MMKVLogLevel.LevelError,
    MMKVLogLevel.LevelNone,
  ];
  static DynamicLibrary _mmkvLib;
  static void Function(Pointer<Utf8> rootDir, int level) _nativeInitialize;
  static void Function(int level) _nativeSetLogLevel;
  static void Function() _nativeOnExit;
  static int Function(Pointer<Utf8> mmapID, int mode, Pointer<Utf8> cryptKey,
      Pointer<Utf8> rootPath) _nativeGetMMKVWithID;
  static int Function(int handle) _nativeCheckProcessMode;
  static int Function(int mode, Pointer<Utf8> cryptKey) _nativeGetDefaultMMKV;
  static Pointer<Utf8> Function(int handle) _nativeCryptKey;
  static int Function(int handle, Pointer<Utf8> cryptKey) _nativeReKey;
  static void Function(int handle, Pointer<Utf8> cryptKey)
      _nativeCheckReSetCryptKey;
  static int Function() _nativePageSize;
  static Pointer<Utf8> Function(int handle) _nativeMmapID;
  static void Function(int handle) _nativeLock;
  static void Function(int handle) _nativeUnlock;
  static int Function(int handle) _nativeTryLock;
  static int Function(int handle, Pointer<Utf8> key, int value)
      _nativeEncodeBool;
  static int Function(int handle, Pointer<Utf8> key, int defaultValue)
      _nativeDecodeBool;
  static int Function(int handle, Pointer<Utf8> key, int value)
      _nativeEncodeInt;
  static int Function(int handle, Pointer<Utf8> key, int defaultValue)
      _nativeDecodeInt;
  static int Function(int handle, Pointer<Utf8> key, double value)
      _nativeEncodeDouble;
  static double Function(int handle, Pointer<Utf8> key, double defaultValue)
      _nativeDecodeDouble;
  static int Function(int handle, Pointer<Utf8> key, Pointer<Utf8> value)
      _nativeEncodeString;
  static Pointer<Utf8> Function(
          int handle, Pointer<Utf8> key, Pointer<Utf8> defaultValue)
      _nativeDecodeString;
  static int Function(int handle, Pointer<Utf8> key, Pointer<StringList> value)
      _nativeEncodeStringSet;
  static Pointer<StringList> Function(int handle, Pointer<Utf8> key)
      _nativeDecodeStringSet;
  static int Function(int handle, Pointer<Utf8> key, Pointer<ByteList> value)
      _nativeEncodeUint8List;
  static Pointer<ByteList> Function(int handle, Pointer<Utf8> key)
      _nativeDecodeUint8List;
  static int Function(int handle, Pointer<Utf8> key, int actualSize)
      _nativeValueSize;
  static int Function(int handle, Pointer<Utf8> key) _nativeContainsKey;
  static Pointer<StringList> Function(int handle) _nativeAllKeys;
  static int Function(int handle) _nativeCount;
  static int Function(int handle) _nativeTotalSize;
  static void Function(int handle, Pointer<Utf8> key) _nativeRemoveValueForKey;
  static void Function(int handle, Pointer<StringList> arrKeys)
      _nativeRemoveValuesForKeys;
  static void Function(int handle) _nativeClearAll;
  static void Function(int handle) _nativeTrim;
  static void Function(int handle) _nativeClose;
  static void Function(int handle) _nativeClearMemoryCache;
  static void Function(int handle, int sync) _nativeSync;
  static int Function(Pointer<Utf8> mmapID) _nativeIsFileValid;
  static int Function(
          Pointer<Utf8> mmapID, int fd, int metaFD, Pointer<Utf8> cryptKey)
      _nativeGetMMKVWithAshmemFD;
  static int Function(int handle) _nativeAshmemFD;
  static int Function(int handle) _nativeAshmemMetaFD;
  static void Function(
      int logReDirecting,
      int hasCallback,
      Pointer<NativeFunction<_nativeMmkvLogFunc>> mmkvLog,
      Pointer<NativeFunction<_nativeOnMMKVCRCCheckFailFunc>>
          onMMKVCRCCheckFailFunc,
      Pointer<NativeFunction<_nativeOnMMKVFileLengthErrorFunc>>
          onMMKVFileLengthErrorFunc) _nativeSetCallbackHandler;
  static void Function(
      int needsNotify,
      Pointer<NativeFunction<_nativeOnContentChangedByOuterProcessFunc>>
          onContentChangedByOuterProcess) _nativeSetWantsContentChangeNotify;
  static void Function(int handle) _nativeCheckContentChangedByOuterProcess;

  static Future<String> initialize(
      {String rootDir, MMKVLogLevel logLevel}) async {
    if (rootDir == null) {
      rootDir =
          "${(await getApplicationDocumentsDirectory()).absolute.path}/mmkv";
    }
    if (logLevel == null) {
      logLevel =
          kReleaseMode ? MMKVLogLevel.LevelInfo : MMKVLogLevel.LevelDebug;
    }
    _mmkvLib = Platform.isAndroid
        ? DynamicLibrary.open("libfmmkv.so")
        : DynamicLibrary.process();
    _nativeInitialize = _mmkvLib
        .lookup<NativeFunction<_nativeInitializeFunc>>("fmmkv_initialize")
        .asFunction();
    _nativeSetLogLevel = _mmkvLib
        .lookup<NativeFunction<_nativeSetLogLevelFunc>>("fmmkv_setLogLevel")
        .asFunction();
    _nativeOnExit = _mmkvLib
        .lookup<NativeFunction<_nativeOnExitFunc>>("fmmkv_onExit")
        .asFunction();
    _nativeGetMMKVWithID = _mmkvLib
        .lookup<NativeFunction<_nativeGetMMKVWithIDFunc>>("fmmkv_getMMKVWithID")
        .asFunction();
    _nativeCheckProcessMode = _mmkvLib
        .lookup<NativeFunction<_nativeCheckProcessModeFunc>>(
            "fmmkv_checkProcessMode")
        .asFunction();
    _nativeGetDefaultMMKV = _mmkvLib
        .lookup<NativeFunction<_nativeGetDefaultMMKVFunc>>(
            "fmmkv_getDefaultMMKV")
        .asFunction();
    _nativeCryptKey = _mmkvLib
        .lookup<NativeFunction<_nativeCryptKeyFunc>>("fmmkv_cryptKey")
        .asFunction();
    _nativeReKey = _mmkvLib
        .lookup<NativeFunction<_nativeReKeyFunc>>("fmmkv_reKey")
        .asFunction();
    _nativeCheckReSetCryptKey = _mmkvLib
        .lookup<NativeFunction<_nativeCheckReSetCryptKeyFunc>>(
            "fmmkv_checkReSetCryptKey")
        .asFunction();
    _nativePageSize = _mmkvLib
        .lookup<NativeFunction<_nativePageSizeFunc>>("fmmkv_pageSize")
        .asFunction();
    _nativeMmapID = _mmkvLib
        .lookup<NativeFunction<_nativeMmapIDFunc>>("fmmkv_mmapId")
        .asFunction();
    _nativeLock = _mmkvLib
        .lookup<NativeFunction<_nativeLockFunc>>("fmmkv_lock")
        .asFunction();
    _nativeUnlock = _mmkvLib
        .lookup<NativeFunction<_nativeUnlockFunc>>("fmmkv_unlock")
        .asFunction();
    _nativeTryLock = _mmkvLib
        .lookup<NativeFunction<_nativeTryLockFunc>>("fmmkv_tryLock")
        .asFunction();
    _nativeEncodeBool = _mmkvLib
        .lookup<NativeFunction<_nativeEncodeBoolFunc>>("fmmkv_encodeBool")
        .asFunction();
    _nativeEncodeBool = _mmkvLib
        .lookup<NativeFunction<_nativeEncodeBoolFunc>>("fmmkv_encodeBool")
        .asFunction();
    _nativeDecodeBool = _mmkvLib
        .lookup<NativeFunction<_nativeDecodeBoolFunc>>("fmmkv_decodeBool")
        .asFunction();
    _nativeEncodeInt = _mmkvLib
        .lookup<NativeFunction<_nativeEncodeIntFunc>>("fmmkv_encodeInt")
        .asFunction();
    _nativeDecodeInt = _mmkvLib
        .lookup<NativeFunction<_nativeDecodeIntFunc>>("fmmkv_decodeInt")
        .asFunction();
    _nativeEncodeDouble = _mmkvLib
        .lookup<NativeFunction<_nativeEncodeDoubleFunc>>("fmmkv_encodeDouble")
        .asFunction();
    _nativeDecodeDouble = _mmkvLib
        .lookup<NativeFunction<_nativeDecodeDoubleFunc>>("fmmkv_decodeDouble")
        .asFunction();
    _nativeEncodeString = _mmkvLib
        .lookup<NativeFunction<_nativeEncodeStringFunc>>("fmmkv_encodeString")
        .asFunction();
    _nativeDecodeString = _mmkvLib
        .lookup<NativeFunction<_nativeDecodeStringFunc>>("fmmkv_decodeString")
        .asFunction();
    _nativeEncodeStringSet = _mmkvLib
        .lookup<NativeFunction<_nativeEncodeStringSetFunc>>(
            "fmmkv_encodeStringSet")
        .asFunction();
    _nativeDecodeStringSet = _mmkvLib
        .lookup<NativeFunction<_nativeDecodeStringSetFunc>>(
            "fmmkv_decodeStringSet")
        .asFunction();
    _nativeEncodeUint8List = _mmkvLib
        .lookup<NativeFunction<_nativeEncodeUint8ListFunc>>(
            "fmmkv_encodeUint8List")
        .asFunction();
    _nativeDecodeUint8List = _mmkvLib
        .lookup<NativeFunction<_nativeDecodeUint8ListFunc>>(
            "fmmkv_decodeUint8List")
        .asFunction();
    _nativeValueSize = _mmkvLib
        .lookup<NativeFunction<_nativeValueSizeFunc>>("fmmkv_valueSize")
        .asFunction();
    _nativeContainsKey = _mmkvLib
        .lookup<NativeFunction<_nativeContainsKeyFunc>>("fmmkv_containsKey")
        .asFunction();
    _nativeAllKeys = _mmkvLib
        .lookup<NativeFunction<_nativeAllKeysFunc>>("fmmkv_allKeys")
        .asFunction();
    _nativeCount = _mmkvLib
        .lookup<NativeFunction<_nativeCountFunc>>("fmmkv_count")
        .asFunction();
    _nativeTotalSize = _mmkvLib
        .lookup<NativeFunction<_nativeTotalSizeFunc>>("fmmkv_totalSize")
        .asFunction();
    _nativeRemoveValueForKey = _mmkvLib
        .lookup<NativeFunction<_nativeRemoveValueForKeyFunc>>(
            "fmmkv_removeValueForKey")
        .asFunction();
    _nativeRemoveValuesForKeys = _mmkvLib
        .lookup<NativeFunction<_nativeRemoveValueForKeysFunc>>(
            "fmmkv_removeValuesForKeys")
        .asFunction();
    _nativeClearAll = _mmkvLib
        .lookup<NativeFunction<_nativeClearAllFunc>>("fmmkv_clearAll")
        .asFunction();
    _nativeTrim = _mmkvLib
        .lookup<NativeFunction<_nativeTrimFunc>>("fmmkv_trim")
        .asFunction();
    _nativeClose = _mmkvLib
        .lookup<NativeFunction<_nativeCloseFunc>>("fmmkv_close")
        .asFunction();
    _nativeClearMemoryCache = _mmkvLib
        .lookup<NativeFunction<_nativeClearMemoryCacheFunc>>(
            "fmmkv_clearMemoryCache")
        .asFunction();
    _nativeSync = _mmkvLib
        .lookup<NativeFunction<_nativeSyncFunc>>("fmmkv_sync")
        .asFunction();
    _nativeIsFileValid = _mmkvLib
        .lookup<NativeFunction<_nativeIsFileValidFunc>>("fmmkv_isFileValid")
        .asFunction();
    _nativeGetMMKVWithAshmemFD = _mmkvLib
        .lookup<NativeFunction<_nativeGetMMKVWithAshmemFDFunc>>(
            "fmmkv_getMMKVWithAshmemFD")
        .asFunction();
    _nativeAshmemFD = _mmkvLib
        .lookup<NativeFunction<_nativeAshmemFDFunc>>("fmmkv_ashmemFD")
        .asFunction();
    _nativeAshmemMetaFD = _mmkvLib
        .lookup<NativeFunction<_nativeAshmemMetaFDFunc>>("fmmkv_ashmemMetaFD")
        .asFunction();
    _nativeSetCallbackHandler = _mmkvLib
        .lookup<NativeFunction<_nativeSetCallbackHandlerFunc>>(
            "fmmkv_setCallbackHandler")
        .asFunction();
    _nativeSetWantsContentChangeNotify = _mmkvLib
        .lookup<NativeFunction<_nativeSetWantsContentChangeNotifyFunc>>(
            "fmmkv_setWantsContentChangeNotify")
        .asFunction();
    _nativeCheckContentChangedByOuterProcess = _mmkvLib
        .lookup<NativeFunction<_nativeCheckContentChangedByOuterProcessFunc>>(
            "fmmkv_checkContentChangedByOuterProcess")
        .asFunction();
    _rootDir = rootDir;
    Pointer<Utf8> rootDirPtr = Utf8.toUtf8(_rootDir);
    _nativeInitialize(rootDirPtr, _logLevel2Int(logLevel));
    free(rootDirPtr);
    return rootDir;
  }

  static int _logLevel2Int(MMKVLogLevel logLevel) {
    int realLevel;
    switch (logLevel) {
      case MMKVLogLevel.LevelDebug:
        realLevel = 0;
        break;
      case MMKVLogLevel.LevelInfo:
        realLevel = 1;
        break;
      case MMKVLogLevel.LevelWarning:
        realLevel = 2;
        break;
      case MMKVLogLevel.LevelError:
        realLevel = 3;
        break;
      case MMKVLogLevel.LevelNone:
        realLevel = 4;
        break;
      default:
        realLevel = 1;
        break;
    }
    return realLevel;
  }

  static void setLogLevel(MMKVLogLevel level) {
    assert(level != null, "level cannot be null.");
    int realLevel = _logLevel2Int(level);
    _nativeSetLogLevel(realLevel);
  }

  static void onExit() {
    _nativeOnExit();
  }

  static MMKV mmkvWithID(
      {@required String mmapID,
      int mode = SINGLE_PROCESS_MODE,
      String cryptKey,
      String rootPath}) {
    assert(mmapID != null, "mmapID cannot be null.");
    assert(mode != null, "mode cannot be null.");
    if (rootDir == null) {
      throw "You should Call MMKV.initialize() first.";
    }
    Pointer<Utf8> mmapIdPtr = Utf8.toUtf8(mmapID);
    Pointer<Utf8> cryptKeyPtr =
        cryptKey == null ? Pointer.fromAddress(0) : Utf8.toUtf8(cryptKey);
    Pointer<Utf8> rootPathPtr =
        rootPath == null ? Pointer.fromAddress(0) : Utf8.toUtf8(rootPath);
    int handle =
        _nativeGetMMKVWithID(mmapIdPtr, mode, cryptKeyPtr, rootPathPtr);
    free(mmapIdPtr);
    free(cryptKeyPtr);
    free(rootPathPtr);
    return MMKV._checkProcessMode(handle, mmapID, mode);
  }

  static MMKV defaultMMKV({int mode = SINGLE_PROCESS_MODE, String cryptKey}) {
    assert(mode != null, "mode cannot be null.");
    if (rootDir == null) {
      throw "You should Call MMKV.initialize() first.";
    }
    Pointer<Utf8> cryptKeyPtr =
        cryptKey == null ? Pointer.fromAddress(0) : Utf8.toUtf8(cryptKey);
    int handle = _nativeGetDefaultMMKV(mode, cryptKeyPtr);
    free(cryptKeyPtr);
    return _checkProcessMode(handle, "DefaultMMKV", mode);
  }

  static MMKV _checkProcessMode(int handle, String mmapID, int mode) {
    if (handle == 0) {
      return null;
    }
    if (!_checkedHandleSet.contains(handle)) {
      if (_nativeCheckProcessMode(handle) != 1) {
        String message;
        if (mode == SINGLE_PROCESS_MODE) {
          message = "Opening a multi-process MMKV instance [" +
              mmapID +
              "] with SINGLE_PROCESS_MODE!";
        } else {
          message = "Opening a single-process MMKV instance [" +
              mmapID +
              "] with MULTI_PROCESS_MODE!";
        }
        throw message;
      }
      _checkedHandleSet.add(handle);
    }
    return MMKV._(handle);
  }

  String get cryptKey => MMKVUtil.ptr2String(_nativeCryptKey(nativeHandle));
  bool reKey(String cryptKey) {
    assert(cryptKey != null, "cryptKey cannot be null");
    Pointer<Utf8> cryptKeyPtr = Utf8.toUtf8(cryptKey);
    int ans = _nativeReKey(nativeHandle, cryptKeyPtr);
    free(cryptKeyPtr);
    return ans == 1;
  }

  void checkReSetCryptKey(String cryptKey) {
    assert(cryptKey != null, "cryptKey cannot be null");
    Pointer<Utf8> cryptKeyPtr = Utf8.toUtf8(cryptKey);
    _nativeCheckReSetCryptKey(nativeHandle, cryptKeyPtr);
    free(cryptKeyPtr);
  }

  static int get pageSize => _nativePageSize();
  String get mmapId => MMKVUtil.ptr2String(_nativeMmapID(nativeHandle));

  void lock() => _nativeLock(nativeHandle);
  void unlock() => _nativeUnlock(nativeHandle);
  bool tryLock() => _nativeTryLock(nativeHandle) == 1;

  bool encodeBool(String key, bool value) {
    assert(key != null, "key cannot be null.");
    assert(value != null, "value cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    int ans = _nativeEncodeBool(nativeHandle, keyPtr, value ? 1 : 0);
    free(keyPtr);
    return ans == 1;
  }

  bool decodeBool(String key, {bool defaultValue = false}) {
    assert(key != null, "key cannot be null.");
    assert(defaultValue != null, "defaultValue cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    int ans = _nativeDecodeBool(nativeHandle, keyPtr, defaultValue ? 1 : 0);
    free(keyPtr);
    return ans == 1;
  }

  bool encodeInt(String key, int value) {
    assert(key != null, "key cannot be null.");
    assert(value != null, "value cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    int ans = _nativeEncodeInt(nativeHandle, keyPtr, value);
    free(keyPtr);
    return ans == 1;
  }

  int decodeInt(String key, {int defaultValue = 0}) {
    assert(key != null, "key cannot be null.");
    assert(defaultValue != null, "defaultValue cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    int ans = _nativeDecodeInt(nativeHandle, keyPtr, defaultValue);
    free(keyPtr);
    return ans;
  }

  bool encodeDouble(String key, double value) {
    assert(key != null, "key cannot be null.");
    assert(value != null, "value cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    int ans = _nativeEncodeDouble(nativeHandle, keyPtr, value);
    free(keyPtr);
    return ans == 1;
  }

  double decodeDouble(String key, {double defaultValue = 0}) {
    assert(key != null, "key cannot be null.");
    assert(defaultValue != null, "defaultValue cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    double ans = _nativeDecodeDouble(nativeHandle, keyPtr, defaultValue);
    free(keyPtr);
    return ans;
  }

  bool encodeString(String key, String value) {
    assert(key != null, "key cannot be null.");
    assert(value != null, "value cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    Pointer<Utf8> valuePtr = Utf8.toUtf8(value);
    int ans = _nativeEncodeString(nativeHandle, keyPtr, valuePtr);
    free(keyPtr);
    free(valuePtr);
    return ans == 1;
  }

  String decodeString(String key, {String defaultValue}) {
    assert(key != null, "key cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    Pointer<Utf8> defaultValuePtr = defaultValue == null
        ? Pointer.fromAddress(0)
        : Utf8.toUtf8(defaultValue);
    Pointer<Utf8> ans =
        _nativeDecodeString(nativeHandle, keyPtr, defaultValuePtr);
    free(keyPtr);
    if (defaultValuePtr.address != ans.address) {
      free(defaultValuePtr);
    }
    return MMKVUtil.ptr2String(ans);
  }

  bool encodeStringSet(String key, Set<String> value) {
    assert(key != null, "key cannot be null.");
    assert(value != null, "value cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    Pointer<StringList> valuePtr = allocate(count: 1);
    StringList valueRef = valuePtr.ref;
    valueRef.length = value.length;
    valueRef.data = allocate(count: value.length);
    {
      int i = 0;
      for (String v in value) {
        valueRef.data.elementAt(i).value = Utf8.toUtf8(v);
        i++;
      }
    }
    int ans = _nativeEncodeStringSet(nativeHandle, keyPtr, valuePtr);
    free(keyPtr);
    for (int i = 0; i < value.length; i++) {
      free(valueRef.data.elementAt(i).value);
    }
    free(valueRef.data);
    free(valuePtr);
    return ans == 1;
  }

  Set<String> decodeStringSet(String key, {Set<String> defaultValue}) {
    assert(key != null, "key cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    Pointer<StringList> result = _nativeDecodeStringSet(nativeHandle, keyPtr);
    free(keyPtr);
    if (result.address == 0) {
      free(result);
      return defaultValue;
    }
    StringList resultRef = result.ref;
    Set<String> a = HashSet();
    for (int i = 0; i < resultRef.length; i++) {
      a.add(MMKVUtil.ptr2String(resultRef.data.elementAt(i).value));
    }
    free(resultRef.data);
    free(result);
    return a;
  }

  bool encodeUint8List(String key, Uint8List value) {
    assert(key != null, "key cannot be null.");
    assert(value != null, "value cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    Pointer<ByteList> valuePtr = allocate(count: 1);
    ByteList valueRef = valuePtr.ref;
    valueRef.length = value.length;
    valueRef.data = allocate(count: value.length);
    Uint8List nativeList = valueRef.data.asTypedList(value.length);
    nativeList.setAll(0, value);
    int ans = _nativeEncodeUint8List(nativeHandle, keyPtr, valuePtr);
    free(keyPtr);
    free(valuePtr);
    return ans == 1;
  }

  Uint8List decodeUint8List(String key, {Uint8List defaultValue}) {
    assert(key != null, "key cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    Pointer<ByteList> ret = _nativeDecodeUint8List(nativeHandle, keyPtr);
    free(keyPtr);
    if (ret.address == 0) {
      return defaultValue;
    }
    ByteList retRef = ret.ref;
    Uint8List ans = Uint8List(retRef.length);
    Uint8List nativeList = retRef.data.asTypedList(retRef.length);
    ans.setAll(0, nativeList);
    free(retRef.data);
    free(ret);
    return ans;
  }

  int getValueSize(String key) {
    assert(key != null, "key cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    int valueSize = _nativeValueSize(nativeHandle, keyPtr, 0);
    free(keyPtr);
    return valueSize;
  }

  int getValueActualSize(String key) {
    assert(key != null, "key cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    int valueSize = _nativeValueSize(nativeHandle, keyPtr, 1);
    free(keyPtr);
    return valueSize;
  }

  bool containsKey(String key) {
    assert(key != null, "key cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    int ans = _nativeContainsKey(nativeHandle, keyPtr);
    free(keyPtr);
    return ans == 1;
  }

  List<String> get allKeys {
    Pointer<StringList> ans = _nativeAllKeys(nativeHandle);
    if (ans.address == 0) {
      return null;
    }
    StringList ansRef = ans.ref;
    List<String> data = List(ansRef.length);
    for (int i = 0; i < ansRef.length; i++) {
      data[i] = MMKVUtil.ptr2String(ansRef.data[i]);
    }
    free(ansRef.data);
    free(ans);
    return data;
  }

  int get count => _nativeCount(nativeHandle);
  int get totalSize => _nativeTotalSize(nativeHandle);

  void removeValueForKey(String key) {
    assert(key != null, "key cannot be null.");
    Pointer<Utf8> keyPtr = Utf8.toUtf8(key);
    _nativeRemoveValueForKey(nativeHandle, keyPtr);
    free(keyPtr);
  }

  void removeValuesForKeys(List<String> arrKeys) {
    assert(arrKeys != null, "arrKeys cannot be null.");
    Pointer<StringList> arrKeysPtr = allocate(count: 1);
    StringList arrKeysPtrRef = arrKeysPtr.ref;
    arrKeysPtrRef.length = arrKeys.length;
    arrKeysPtrRef.data = allocate(count: arrKeys.length);
    for (int i = 0; i < arrKeys.length; i++) {
      arrKeysPtrRef.data.elementAt(i).value = Utf8.toUtf8(arrKeys[i]);
    }
    _nativeRemoveValuesForKeys(nativeHandle, arrKeysPtr);
    for (int i = 0; i < arrKeys.length; i++) {
      free(arrKeysPtrRef.data.elementAt(i).value);
    }
    free(arrKeysPtrRef.data);
    free(arrKeysPtr);
  }

  void clearAll() => _nativeClearAll(nativeHandle);
  void trim() => _nativeTrim(nativeHandle);
  void close() => _nativeClose(nativeHandle);
  void clearMemoryCache() => _nativeClearMemoryCache(nativeHandle);
  void sync() => _nativeSync(nativeHandle, 1);
  void async() => _nativeSync(nativeHandle, 0);

  static bool isFileValid(String mmapID) {
    assert(String != null, "arrKeys cannot be null.");
    Pointer<Utf8> mmapIDPtr = Utf8.toUtf8(mmapID);
    int ans = _nativeIsFileValid(mmapIDPtr);
    free(mmapIDPtr);
    return ans == 1;
  }

  static MMKV mmkvWithAshmemFD(String mmapID, int fd, int metaFD,
      {String cryptKey}) {
    assert(mmapID != null, "mmapID cannot be null.");
    Pointer<Utf8> mmapIDPtr = Utf8.toUtf8(mmapID);
    Pointer<Utf8> cryptKeyPtr = Utf8.toUtf8(cryptKey);
    int handle = _nativeGetMMKVWithAshmemFD(mmapIDPtr, fd, metaFD, cryptKeyPtr);
    free(mmapIDPtr);
    free(cryptKeyPtr);
    return MMKV._(handle);
  }

  int get ashmemFD => _nativeAshmemFD(nativeHandle);
  int get ashmemMetaFD => _nativeAshmemMetaFD(nativeHandle);

  int nativeHandle;

  MMKV._(int handle) {
    nativeHandle = handle;
  }

  static MMKVHandler _gCallbackHandler;
  static bool _gWantLogReDirecting = false;

  static void registerHandler(MMKVHandler handler) {
    assert(handler != null, "handler cannot be null.");
    _gCallbackHandler = handler;
    if (_gCallbackHandler.wantLogRedirecting()) {
      _nativeSetCallbackHandler(
          1,
          1,
          Pointer.fromFunction<_nativeMmkvLogFunc>(_nativeMmkvLog),
          Pointer.fromFunction<_nativeOnMMKVCRCCheckFailFunc>(_nativeOnMMKVCRCCheckFail, 0),
          Pointer.fromFunction<_nativeOnMMKVFileLengthErrorFunc>(_nativeOnMMKVFileLengthError, 0));
      _gWantLogReDirecting = true;
    } else {
      _nativeSetCallbackHandler(
          0,
          1,
          Pointer.fromFunction<_nativeMmkvLogFunc>(_nativeMmkvLog),
          Pointer.fromFunction<_nativeOnMMKVCRCCheckFailFunc>(_nativeOnMMKVCRCCheckFail, 0),
          Pointer.fromFunction<_nativeOnMMKVFileLengthErrorFunc>(_nativeOnMMKVFileLengthError, 0));
      _gWantLogReDirecting = false;
    }
  }

  static void unregisterHandler() {
    _gCallbackHandler = null;
    _nativeSetCallbackHandler(0, 0, null, null, null);
    _gWantLogReDirecting = false;
  }

  static void _mmkvLogImp(int level, StackTrace stackTrace) {
    if (_gCallbackHandler != null && _gWantLogReDirecting) {
      _gCallbackHandler.mmkvLog(
          _index2LogLevel[level], "", -1, "", stackTrace.toString());
    } else {
      switch (_index2LogLevel[level]) {
        case MMKVLogLevel.LevelDebug:
          log(stackTrace.toString(), name: "MMKV", level: Level.SHOUT.value);
          break;
        case MMKVLogLevel.LevelInfo:
          log(stackTrace.toString(), name: "MMKV", level: Level.INFO.value);
          break;
        case MMKVLogLevel.LevelWarning:
          log(stackTrace.toString(), name: "MMKV", level: Level.WARNING.value);
          break;
        case MMKVLogLevel.LevelError:
          log(stackTrace.toString(), name: "MMKV", level: Level.SEVERE.value);
          break;
        case MMKVLogLevel.LevelNone:
          break;
      }
    }
  }

  static void _simpleLog(MMKVLogLevel level, String message) {
    StackTrace stackTrace = StackTrace.current;
    int i = _logLevel2Index[level];
    int intLevel = (i == null) ? 0 : i;
    _mmkvLogImp(intLevel, stackTrace);
  }

  static MMKVContentChangeNotification _gContentChangeNotify;
  static void registerContentChangeNotify(
      MMKVContentChangeNotification notify) {
    assert(notify != null, "notify cannot be null.");
    _gContentChangeNotify = notify;
    _nativeSetWantsContentChangeNotify(
        1, Pointer.fromFunction(_nativeOnContentChangedByOuterProcess));
  }

  static void unregisterContentChangeNotify() {
    _gContentChangeNotify = null;
    _nativeSetWantsContentChangeNotify(0, null);
  }

  void checkContentChangedByOuterProcess() =>
      _nativeCheckContentChangedByOuterProcess(nativeHandle);

  static int _nativeOnMMKVCRCCheckFail(Pointer<Utf8> mmapID) {
    String mmapIDString = MMKVUtil.ptr2String(mmapID);
    MMKVRecoverStrategic strategic =
        _gCallbackHandler.onMMKVCRCCheckFail(mmapIDString);
    if (strategic == MMKVRecoverStrategic.OnErrorDiscard) {
      return 0;
    }
    return 1;
  }

  static int _nativeOnMMKVFileLengthError(Pointer<Utf8> mmapID) {
    String mmapIDString = MMKVUtil.ptr2String(mmapID);
    MMKVRecoverStrategic strategic =
        _gCallbackHandler.onMMKVFileLengthError(mmapIDString);
    if (strategic == MMKVRecoverStrategic.OnErrorDiscard) {
      return 0;
    }
    return 1;
  }

  static void _nativeMmkvLog(int level, Pointer<Utf8> file, int line,
      Pointer<Utf8> function, Pointer<Utf8> message) {
    MMKVLogLevel mmkvLogLevel = _index2LogLevel[level];
    String fileString = MMKVUtil.ptr2String(file, clear: false);
    String functionString = MMKVUtil.ptr2String(function, clear: false);
    String messageString = MMKVUtil.ptr2String(message, clear: false);
    _gCallbackHandler.mmkvLog(
        mmkvLogLevel, fileString, line, functionString, messageString);
  }

  static void _nativeOnContentChangedByOuterProcess(Pointer<Utf8> mmapId) {
    String mmapIDString = MMKVUtil.ptr2String(mmapId);
    _gContentChangeNotify.onContentChangedByOuterProcess(mmapIDString);
  }
}

typedef _nativeInitializeFunc = Void Function(Pointer<Utf8>, Int32);
typedef _nativeSetLogLevelFunc = Void Function(Int32);
typedef _nativeOnExitFunc = Void Function();
typedef _nativeGetMMKVWithIDFunc = Int64 Function(
    Pointer<Utf8>, Int32, Pointer<Utf8>, Pointer<Utf8>);
typedef _nativeCheckProcessModeFunc = Int32 Function(Int64);
typedef _nativeGetDefaultMMKVFunc = Int64 Function(Int32, Pointer<Utf8>);
typedef _nativeCryptKeyFunc = Pointer<Utf8> Function(Int64);
typedef _nativeReKeyFunc = Int32 Function(Int64, Pointer<Utf8>);
typedef _nativeCheckReSetCryptKeyFunc = Void Function(Int64, Pointer<Utf8>);
typedef _nativePageSizeFunc = Int32 Function();
typedef _nativeMmapIDFunc = Pointer<Utf8> Function(Int64);
typedef _nativeLockFunc = Void Function(Int64);
typedef _nativeUnlockFunc = Void Function(Int64);
typedef _nativeTryLockFunc = Int32 Function(Int64);
typedef _nativeEncodeBoolFunc = Int32 Function(Int64, Pointer<Utf8>, Int32);
typedef _nativeDecodeBoolFunc = Int32 Function(Int64, Pointer<Utf8>, Int32);
typedef _nativeEncodeIntFunc = Int32 Function(Int64, Pointer<Utf8>, Int64);
typedef _nativeDecodeIntFunc = Int64 Function(Int64, Pointer<Utf8>, Int64);
typedef _nativeEncodeDoubleFunc = Int32 Function(Int64, Pointer<Utf8>, Double);
typedef _nativeDecodeDoubleFunc = Double Function(Int64, Pointer<Utf8>, Double);
typedef _nativeEncodeStringFunc = Int32 Function(
    Int64, Pointer<Utf8>, Pointer<Utf8>);
typedef _nativeDecodeStringFunc = Pointer<Utf8> Function(
    Int64, Pointer<Utf8>, Pointer<Utf8>);
typedef _nativeEncodeStringSetFunc = Int32 Function(
    Int64, Pointer<Utf8>, Pointer<StringList>);
typedef _nativeDecodeStringSetFunc = Pointer<StringList> Function(
    Int64, Pointer<Utf8>);
typedef _nativeEncodeUint8ListFunc = Int32 Function(
    Int64, Pointer<Utf8>, Pointer<ByteList>);
typedef _nativeDecodeUint8ListFunc = Pointer<ByteList> Function(
    Int64, Pointer<Utf8>);
typedef _nativeValueSizeFunc = Int32 Function(Int64, Pointer<Utf8>, Int32);
typedef _nativeContainsKeyFunc = Int32 Function(Int64, Pointer<Utf8>);
typedef _nativeAllKeysFunc = Pointer<StringList> Function(Int64);
typedef _nativeCountFunc = Int64 Function(Int64);
typedef _nativeTotalSizeFunc = Int64 Function(Int64);
typedef _nativeRemoveValueForKeyFunc = Void Function(Int64, Pointer<Utf8>);
typedef _nativeRemoveValueForKeysFunc = Void Function(
    Int64, Pointer<StringList>);
typedef _nativeClearAllFunc = Void Function(Int64);
typedef _nativeTrimFunc = Void Function(Int64);
typedef _nativeCloseFunc = Void Function(Int64);
typedef _nativeClearMemoryCacheFunc = Void Function(Int64);
typedef _nativeSyncFunc = Void Function(Int64, Int32);
typedef _nativeIsFileValidFunc = Int32 Function(Pointer<Utf8>);
typedef _nativeGetMMKVWithAshmemFDFunc = Int64 Function(
    Pointer<Utf8>, Int32, Int32, Pointer<Utf8>);
typedef _nativeAshmemFDFunc = Int32 Function(Int64);
typedef _nativeAshmemMetaFDFunc = Int32 Function(Int64);
typedef _nativeSetCallbackHandlerFunc = Void Function(
    Int32,
    Int32,
    Pointer<NativeFunction<_nativeMmkvLogFunc>>,
    Pointer<NativeFunction<_nativeOnMMKVCRCCheckFailFunc>>,
    Pointer<NativeFunction<_nativeOnMMKVFileLengthErrorFunc>>);
typedef _nativeMmkvLogFunc = Void Function(
    Int32, Pointer<Utf8>, Int32, Pointer<Utf8>, Pointer<Utf8>);
typedef _nativeOnMMKVCRCCheckFailFunc = Int32 Function(Pointer<Utf8>);
typedef _nativeOnMMKVFileLengthErrorFunc = Int32 Function(Pointer<Utf8>);
typedef _nativeSetWantsContentChangeNotifyFunc = Void Function(
    Int32 needsNotify,
    Pointer<NativeFunction<_nativeOnContentChangedByOuterProcessFunc>>);
typedef _nativeOnContentChangedByOuterProcessFunc = Void Function(
    Pointer<Utf8>);
typedef _nativeCheckContentChangedByOuterProcessFunc = Void Function(Int64);
