import 'package:sysyphus_learning_app/data/DAO/question_dao.dart';

class QuestionSchema {
  Map<int, Map<String, dynamic>> question_schema = {};

  void getQuestionData(int packageId, int limit) async {
    QuestionDao dao = QuestionDao();
    List<Map<String, dynamic>> result = await dao.getByPackage(packageId, limit);
    for( final item in result){
      question_schema[item['id'] as int] = item;
    }    
  }
}