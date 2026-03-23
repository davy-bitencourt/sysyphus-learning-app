import 'package:sysyphus_learning_app/data/DAO/tag_dao.dart';

class TagSchema {
  Map<int, String> tag_schema = {};

  void getTagData() async {
    TagDao dao = TagDao();

    List<Map<String, dynamic>> result = await dao.getAll();

    for( final item in result){
      tag_schema[item['id'] as int] = item['title'] as String;
    }
  }
}