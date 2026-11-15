import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sysyphus/data/DAO/package_dao.dart';

class PackageSchema {
  Map<int, String> packageSchema = {};

  Future<void> getPackageDataByProfile(int profileId) async {
    debugPrint('SCHEMA 1');

    PackageDao dao = PackageDao();

    debugPrint('SCHEMA 2 - chamando DAO');

    List<Map<String, dynamic>> result =
        await dao.getProfilePackages(profileId);

    debugPrint('SCHEMA 3 - DAO retornou');
    debugPrint('$result');

    for (final item in result) {
      packageSchema[item['id'] as int] = item['name'] as String;
    }

    debugPrint('SCHEMA 4 - terminou');
  }
}