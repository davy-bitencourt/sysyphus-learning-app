class Revlog {
  final int? id;
  final int? packageId;
  final String? data;
  final String? time;

  Revlog({
    this.id,
    this.packageId,
    this.data,
    this.time,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'package_id': packageId,
    'data': data,
    'time': time,
  };

  factory Revlog.fromMap(Map<String, dynamic> map) => Revlog(
    id: map['id'],
    packageId: map['package_id'],
    data: map['data'],
    time: map['time'],
  );
}