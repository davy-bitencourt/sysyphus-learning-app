import 'dart:convert';
import 'package:sysyphus/data/DAO/template_dao.dart';

class TemplateSchema {
  /* guarda os templates no schema, com base no 
   * template_id, mantendo uma espécie de cache */
  Map<int, Map<String, dynamic>> templateSchema = {};

  /* inicializando o cache do template com 5 itens randômicos */
  Future<void> getTemplateData() async {
    TemplateDao dao = TemplateDao();
    List<Map<String, dynamic>> result = await dao.getRandomLimit(5);

    for( final item in result ) {
      templateSchema[item['id'] as int] =
          jsonDecode(item['template'] as String) as Map<String, dynamic>;
    }
  }


  /* lóica do cache local */
  void add(int id, Map<String, dynamic> template){
    templateSchema[id] = template;
  }

  Future<void> isOnCache(int templateidAtual) async {
    
    if(!templateSchema.containsKey(templateidAtual)){
      TemplateDao dao = TemplateDao(); 
      List<Map<String, dynamic>> template = await dao.getTemplateById(templateidAtual);

      final decoded = jsonDecode(template[0]['template'] as String) as Map<String, dynamic>;
      add(templateidAtual, decoded);
    }

    if(templateSchema.length >= 5){
      templateSchema.remove(templateSchema.keys.first);
    }
  }

}
