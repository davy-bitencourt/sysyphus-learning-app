import 'package:sysyphus_learning_app/data/DAO/package_dao.dart';

class PackageSchema {

  Map<int, String> package_schema = {};

  Future<void> getPackageDataByProfile(int profile_id) async {
    PackageDao dao = PackageDao();
    List<Map<String, dynamic>> result = await dao.getProfilePackages(profile_id);

    for( final item in result ){
      package_schema[item['id'] as int] = item['name'] as String;
    }
  }
}
