import 'package:sysyphus_learning_app/data/DAO/session_dao.dart';

class  SessionSchema {

  List<Map<String, dynamic>> session_schema = [];

  Future<void> getSessionsData() async {
    SessionDao dao = SessionDao();
    session_schema = await dao.getAll();
  }
}