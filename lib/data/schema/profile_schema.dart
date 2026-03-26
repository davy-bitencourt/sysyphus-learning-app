import 'package:sysyphus_learning_app/data/DAO/profile_dao.dart';

class ProfileSchema {

  Map<int, String> profile_schema = {};

  Future<void>getProfileData() async {
    ProfileDao dao = ProfileDao();
    List<Map<String, dynamic>> result = await dao.getAllProfiles();

    for( final item in result ){
      profile_schema[item['id'] as int] = item['name'] as String;
    }
  }

}
