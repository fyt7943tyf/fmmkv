# fmmkv

This project aims to warp mmkv API in dart ffi.

It only supports Android Platform now.

##Quick Tutorial

```dart
  await MMKV.initialize();
  MMKV mmkv = MMKV.defaultMMKV();

  mmkv.encodeBool('boolKey', true);
  print('get bool value is ${mmkv.decodeBool('boolKey')}');
  
  int counter = mmkv.decodeInt('intKey') + 1;
  print('GetSetIntTest value is $counter ');
  mmkv.encodeInt('intKey', counter);
  
  String stringtest = mmkv.decodeString('stringKey') + '1';
  print('GetSetStringTest value is $stringtest');
  mmkv.encodeString('stringKey', stringtest);
```
