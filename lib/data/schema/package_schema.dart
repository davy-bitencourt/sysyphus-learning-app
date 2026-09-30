import 'package:Sysyphus/data/DAO/package_dao.dart';

class PackageSchema {
  Map<int, String> package_schema = {};

  Future<void> getPackageDataByProfile(int profile_id) async {
    print('SCHEMA 1');

    PackageDao dao = PackageDao();

    print('SCHEMA 2 - chamando DAO');

    List<Map<String, dynamic>> result =
        await dao.getProfilePackages(profile_id);

    print('SCHEMA 3 - DAO retornou');
    print(result);

    for (final item in result) {
      package_schema[item['id'] as int] = item['name'] as String;
    }

    print('SCHEMA 4 - terminou');
  }
}