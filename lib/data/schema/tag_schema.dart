import 'package:sysyphus/data/DAO/tag_dao.dart';

class TagSchema {
  Map<int, String> tagSchema = {};

  Future<void> getTagData() async {
    TagDao dao = TagDao();

    List<Map<String, dynamic>> result = await dao.getAll();

    for( final item in result){
      tagSchema[item['id'] as int] = item['title'] as String;
    }
  }
}
