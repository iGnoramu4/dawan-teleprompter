import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

/// 导入文件的行编码识别：优先 UTF-8，失败后退回 GBK（§4.1 S-04）。
String decodeTextBytes(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    try {
      return gbk.decode(bytes);
    } on FormatException {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}
