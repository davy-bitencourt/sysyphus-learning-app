import 'package:sysyphus/data/DAO/session_dao.dart';

class  SessionSchema {

  List<Map<String, dynamic>> sessionSchema = [];

  Future<void> getSessionsData() async {
    SessionDao dao = SessionDao();
    sessionSchema = await dao.getAll();
  }
}