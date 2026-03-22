import 'package:sysyphus_learning_app/data/DAO/template_dao.dart';

class TemplateSchema {
  /* guarda os templates no schema, com base no 
   * template_id, mantendo uma espécie de cache */
  Map<int, Map<String, dynamic>> template_schema = {};

  /* inicializando o template */
  void getTemplateData() async {
    TemplateDao dao = TemplateDao();
    List<Map<String, dynamic>> result = await dao.getRandomLimit(5);

    for( final item in result ) {
      template_schema[item['id']] = item['template']; 
    };
  }


  /* lóica do cache */
  void add(int id, Map<String, dynamic> template){
    template_schema[id] = template;
  }

  Future<void> isOnCache(int templateId_atual) async {
    
    if(!template_schema.containsKey(templateId_atual)){
      TemplateDao dao = TemplateDao(); 
      List<Map<String, dynamic>> template = await dao.getTemplateById(templateId_atual);
      add(templateId_atual, template[0]);
    }

    if(template_schema.length >= 5){
      template_schema.remove(template_schema.keys.first);
    }
  }

}