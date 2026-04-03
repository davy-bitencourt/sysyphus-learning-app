import '../DAO/revlog_dao.dart';

class RevlogSchema {
  final RevlogDao _dao = RevlogDao();

  Future<Map<DateTime, int>> getHeatmapData() async {
    final rawData = await _dao.getCountPerDay();

    final Map<DateTime, int> heatmapData = {};

    rawData.forEach((dateString, count) {
      final date = DateTime.parse(dateString);
      heatmapData[date] = count;
    });

    return heatmapData;
  }
}