import '../DAO/question_state_dao.dart';

class QuestionSchema {
  /* os items serão acessados por meio de iteração, 
   * portanto List se faz necessária nesta situação */
  List<Map<String, dynamic>> questionSchema = [];

  Future<void> getQuestionData(int packageId, int limit) async {
    QuestionDao dao = QuestionDao();
    questionSchema = await dao.getByPackage(packageId, limit);
  }
}
