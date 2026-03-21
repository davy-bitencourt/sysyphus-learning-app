import 'package:sysyphus_learning_app/data/DAO/account_dao.dart';

class AccountDto {
  final String email;
  final String senha;

  AccountDto({
    required this.email,
    required this.senha
  });

  Map<String, dynamic> toMap() => {
    'email': email,
    'senha': senha,
  };

  factory AccountDto.fromMap(Map<String, dynamic> map) => AccountDto(
    email: map['email'] as String, 
    senha: map['senha'] as String,
  );
}
