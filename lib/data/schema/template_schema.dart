import 'package:sysyphus_learning_app/data/DAO/template_dao.dart';

class TemplateSchema {
  /* guarda os templates no schema, com base no 
   * template_id, mantendo uma espécie de cache */
  Map<int, Map<String, dynamic>> template_schema = {};

  void add(int id, Map<String, dynamic> template){
    template_schema[id] = template;
  }

  Future<void> isOnCache(int templateId_atual) async {
    
    if(!template_schema.containsKey(templateId_atual)){
      TemplateDao template_dao = TemplateDao(); 
      List<Map<String, dynamic>> template = await template_dao.getTemplateById(templateId_atual);
      add(templateId_atual, template[0]);
    }

    if(template_schema.length >= 5){
      template_schema.remove(template_schema.keys.first);
    }
  }

}