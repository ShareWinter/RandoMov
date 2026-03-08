/// 本地用户模型
class LocalUser {
  final String id;
  final String name;

  LocalUser({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };

  factory LocalUser.fromJson(Map<String, dynamic> json) => LocalUser(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
  );

  LocalUser copyWith({
    String? id,
    String? name,
  }) {
    return LocalUser(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  String toString() => 'LocalUser(id: $id, name: $name)';
}
