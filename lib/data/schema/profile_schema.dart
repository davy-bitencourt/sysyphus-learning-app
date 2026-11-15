import 'package:sysyphus/data/DAO/profile_dao.dart';

class ProfileSchema {

  Map<int, String> profileSchema = {};

  Future<void>getProfileData() async {
    ProfileDao dao = ProfileDao();
    List<Map<String, dynamic>> result = await dao.getAllProfiles();

    for( final item in result ){
      profileSchema[item['id'] as int] = item['name'] as String;
    }
  }

}
