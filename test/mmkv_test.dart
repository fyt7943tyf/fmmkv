import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mmkv/mmkv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MMKV mmkv;
  const String KeyNotExist = "Key_Not_Exist";
  setUp(() async {
    await MMKV.initialize();
    mmkv = MMKV.mmkvWithID(
        mmapID: "unitTest",
        mode: MMKV.SINGLE_PROCESS_MODE,
        cryptKey: "UnitTestCryptKey");
  });

  tearDown(() {
    //mmkv.clearAll();
  });

  test('testBool', () {
    bool ret = mmkv.encodeBool("bool", true);
    expect(ret, true);

    bool value = mmkv.decodeBool("bool");
    expect(value, true);

    value = mmkv.decodeBool(KeyNotExist);
    expect(value, false);

    value = mmkv.decodeBool(KeyNotExist, defaultValue: true);
    expect(value, true);
  });
}
