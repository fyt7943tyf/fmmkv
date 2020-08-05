import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:ffi/ffi.dart';
import 'package:mmkv/mmkv.dart';
import 'package:mmkv/mmkv_content_change_notification.dart';
import 'package:mmkv/mmkv_handler.dart';
import 'package:mmkv/mmkv_log_level.dart';
import 'package:mmkv/mmkv_recover_strategic.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  MMKV mmkv;
  static const String KeyNotExist = "Key_Not_Exist";
  static const double Delta = 0.000001;

  @override
  void initState() {
    super.initState();
    test();
  }

  void testBool() {
    bool ret = mmkv.encodeBool("bool", true);
    assert(ret, "true");

    bool value = mmkv.decodeBool("bool");
    assert(value, "true");

    value = mmkv.decodeBool(KeyNotExist);
    assert(!value, "false");

    value = mmkv.decodeBool(KeyNotExist, defaultValue: true);
    assert(value, "true");
    print("testBool OK.");
  }

  void testInt() {
    bool ret = mmkv.encodeInt("int", 2147483647);
    assert(ret, true);

    int value = mmkv.decodeInt("int");
    assert(value == 2147483647, 2147483647);

    value = mmkv.decodeInt(KeyNotExist);
    assert(value == 0, 0);

    value = mmkv.decodeInt(KeyNotExist, defaultValue: -1);
    assert(value == -1, -1);
    print("testInt OK.");
  }

  void testLong() {
    bool ret = mmkv.encodeInt("long", 9223372036854775807);
    assert(ret, true);

    int value = mmkv.decodeInt("long");
    assert(value == 9223372036854775807, 9223372036854775807);

    value = mmkv.decodeInt(KeyNotExist);
    assert(value == 0, 0);

    value = mmkv.decodeInt(KeyNotExist, defaultValue: -1);
    assert(value == -1, -1);
    print("testLong OK.");
  }

  void testDouble() {
    bool ret = mmkv.encodeDouble("double", double.maxFinite);
    assert(ret, true);

    double value = mmkv.decodeDouble("double");
    assert((value - double.maxFinite) < Delta, Delta);

    value = mmkv.decodeDouble(KeyNotExist);
    assert((value) < Delta, Delta);

    value = mmkv.decodeDouble(KeyNotExist, defaultValue: -1);
    assert((value - (-1)) < Delta, Delta);
    print("testDouble OK.");
  }

  void testString() {
    String str = "Hello 2018 world cup 世界杯";
    bool ret = mmkv.encodeString("string", str);
    assert(ret, true);

    String value = mmkv.decodeString("string");
    assert(value == str, str);

    value = mmkv.decodeString(KeyNotExist);
    assert(value == null, null);

    value = mmkv.decodeString(KeyNotExist, defaultValue: "Empty");
    assert(value == "Empty", "Empty");
    print("testString OK.");
  }

  void testStringSet() {
    HashSet<String> set = HashSet();
    set.add("W");
    set.add("e");
    set.add("C");
    set.add("h");
    set.add("a");
    set.add("t");
    bool ret = mmkv.encodeStringSet("string_set", set);
    assert(ret, true);
    HashSet<String> value = mmkv.decodeStringSet("string_set");
    List valueList = value.toList()..sort();
    List setList = set.toList()..sort();
    assert(valueList.length == setList.length, set);
    for (int i = 0; i < valueList.length; i++) {
      assert(valueList[i] == setList[i], set);
    }

    value = mmkv.decodeStringSet(KeyNotExist);
    assert(value == null, null);

    set = HashSet<String>();
    set.add("W");
    value = mmkv.decodeStringSet(KeyNotExist, defaultValue: set);
    valueList = value.toList()..sort();
    setList = set.toList()..sort();
    assert(valueList.length == setList.length, set);
    for (int i = 0; i < valueList.length; i++) {
      assert(valueList[i] == setList[i], set);
    }
    print("testStringSet OK.");
  }

  void testBytes() {
    Uint8List bytes = Uint8List.fromList([109, 109, 107, 118]);
    bool ret = mmkv.encodeUint8List("bytes", bytes);
    assert(ret, true);

    Uint8List value = mmkv.decodeUint8List("bytes");
    assert(value.length == bytes.length, bytes);
    for (int i = 0; i < value.length; i++) {
      assert(value[i] == bytes[i], bytes);
    }
    print("testBytes OK.");
  }

  void testRemove() {
    bool ret = mmkv.encodeBool("bool_1", true);
    ret &= mmkv.encodeInt("int_1", 0);
    ret &= mmkv.encodeInt("long_1", 0);
    ret &= mmkv.encodeDouble("float_1", 1.175494351e-38);
    ret &= mmkv.encodeDouble("double_1", double.minPositive);
    ret &= mmkv.encodeString("string_1", "hello");

    HashSet<String> set = new HashSet();
    set.add("W");
    set.add("e");
    set.add("C");
    set.add("h");
    set.add("a");
    set.add("t");
    ret &= mmkv.encodeStringSet("string_set_1", set);

    Uint8List bytes = Uint8List.fromList([109, 109, 107, 118]);
    ret &= mmkv.encodeUint8List("bytes_1", bytes);
    assert(ret, true);

    {
      int count = mmkv.count;

      mmkv.removeValueForKey("bool_1");
      mmkv.removeValuesForKeys(["int_1", "long_1"]);

      int newCount = mmkv.count;
      assert(count == newCount + 3, newCount + 3);
    }

    bool bValue = mmkv.decodeBool("bool_1");
    assert(!bValue, false);

    int iValue = mmkv.decodeInt("int_1");
    assert(iValue == 0, 0);

    int lValue = mmkv.decodeInt("long_1");
    assert(lValue == 0, 0);

    double fValue = mmkv.decodeDouble("float_1");
    assert((fValue - 1.175494351e-38) < Delta, Delta);

    double dValue = mmkv.decodeDouble("double_1");
    assert((dValue - double.minPositive) < Delta, Delta);

    String sValue = mmkv.decodeString("string_1");
    assert(sValue == "hello", "hello");

    HashSet<String> hashSet = mmkv.decodeStringSet("string_set_1");
    List setList = set.toList()..sort();
    List hashSetList = hashSet.toList()..sort();
    assert(setList.length == hashSetList.length, set);
    for (int i = 0; i < setList.length; i++) {
      assert(setList[i] == hashSetList[i], set);
    }

    Uint8List byteValue = mmkv.decodeUint8List("bytes_1");
    assert(byteValue.length == bytes.length, bytes);
    for (int i = 0; i < byteValue.length; i++) {
      assert(byteValue[i] == bytes[i], bytes);
    }
    print("testRemove OK.");
  }

  Future test() async {
    await MMKV.initialize();
    mmkv = MMKV.mmkvWithID(
        mmapID: "unitTest",
        mode: MMKV.SINGLE_PROCESS_MODE,
        cryptKey: "UnitTestCryptKey");
    A a = A();
    B b = B();
    MMKV.registerContentChangeNotify(a);
    MMKV.registerHandler(b);
    testBool();
    testInt();
    testLong();
    testDouble();
    testString();
    testStringSet();
    testBytes();
    testRemove();
    mmkv.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(),
      ),
    );
  }
}

class A extends MMKVContentChangeNotification {
  @override
  void onContentChangedByOuterProcess(String mmapID) {
    print(mmapID);
  }
}

class B extends MMKVHandler {
  @override
  void mmkvLog(MMKVLogLevel level, String file, int line, String function,
      String message) {
    print("$level $file $line $function $message");
  }

  @override
  MMKVRecoverStrategic onMMKVCRCCheckFail(String mmapID) {
    print("$mmapID");
    return MMKVRecoverStrategic.OnErrorDiscard;
  }

  @override
  MMKVRecoverStrategic onMMKVFileLengthError(String mmapID) {
    print("$mmapID");
    return MMKVRecoverStrategic.OnErrorRecover;
  }

  @override
  bool wantLogRedirecting() {
    return true;
  }
}
