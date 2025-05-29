import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 远程 vip_inject.js 的原始地址
const String remoteJsUrl =
    'https://raw.githubusercontent.com/ceeyang/flutter_iyf/main/assets/js/vip_inject.js';

/// 提取版本号的正则表达式
final RegExp versionReg = RegExp(r'@version\s+([0-9.]+)');

/// 加载本地 assets 脚本内容
Future<String> loadLocalJs() async {
  return await rootBundle.loadString('assets/js/vip_inject.js');
}

/// 获取本地 assets 脚本版本号
Future<String?> getLocalJsVersion() async {
  String js = await loadLocalJs();
  return versionReg.firstMatch(js)?.group(1);
}

/// 加载缓存的远程脚本内容
Future<String?> loadCachedJs() async {
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/vip_inject.js');
  if (await file.exists()) {
    return await file.readAsString();
  }
  return null;
}

/// 获取缓存的远程脚本版本号
Future<String?> getCachedJsVersion() async {
  String? js = await loadCachedJs();
  if (js == null) return null;
  return versionReg.firstMatch(js)?.group(1);
}

/// 下载远程脚本并缓存到本地
Future<String?> downloadAndCacheJs() async {
  try {
    final http.Response resp = await http.get(Uri.parse(remoteJsUrl));
    if (resp.statusCode == 200) {
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/vip_inject.js');
      await file.writeAsString(resp.body);
      return resp.body;
    }
  } catch (e) {
    // 网络异常可忽略
  }
  return null;
}

/// 版本号比较，remote > local 返回 true
bool isNewerVersion(String? remote, String? local) {
  if (remote == null || local == null) return false;
  List<int> r = remote.split('.').map(int.parse).toList();
  List<int> l = local.split('.').map(int.parse).toList();
  for (int i = 0; i < r.length && i < l.length; i++) {
    if (r[i] > l[i]) return true;
    if (r[i] < l[i]) return false;
  }
  return r.length > l.length;
}

/// 初始化并返回最终要注入的 vip_inject.js 内容
Future<String> initVipInjectJs() async {
  String localJs = await loadLocalJs();
  String? localVer = versionReg.firstMatch(localJs)?.group(1);

  // 先尝试加载缓存
  String? cachedJs = await loadCachedJs();
  String? cachedVer = versionReg.firstMatch(cachedJs ?? '')?.group(1);

  // 尝试下载远程
  String? remoteJs = await downloadAndCacheJs();
  String? remoteVer = versionReg.firstMatch(remoteJs ?? '')?.group(1);

  // 比较版本号，优先用高版本
  if (isNewerVersion(remoteVer, localVer)) {
    return remoteJs!;
  } else if (isNewerVersion(cachedVer, localVer)) {
    return cachedJs!;
  } else {
    return localJs;
  }
}
