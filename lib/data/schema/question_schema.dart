import 'package:sysyphus_learning_app/data/DAO/question_dao.dart';

class QuestionSchema {
  /* os items serão acessados por meio de iteração, 
   * portanto List se faz necessária nesta situação */
  List<Map<String, dynamic>> question_schema = [];

  void getQuestionData(int packageId, int limit) async {
    QuestionDao dao = QuestionDao();
    question_schema = await dao.getByPackage(packageId, limit);
  }
}