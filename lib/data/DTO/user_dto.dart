import 'package:sysyphus_learning_app/data/DAO/user_dao.dart';
import 'package:sysyphus_learning_app/data/DTO/user_dto.dart';

class UserDto {
  final String user_name;
  final String email;
  final String senha;

  UserDto({
    required this.user_name,
    required this.email,
    required this.senha
  });

  Map<String, dynamic> toMap() => {
    'username': user_name,
    'email': email,
    'senha': senha,
  };

  factory UserDto.fromMap(Map<String, dynamic> map) => UserDto(
    user_name: map['username'] as String,
    email: map['email'] as String, 
    senha: map['senha'] as String,
  );
}
