enum UserType { user, rider }

class Profile {
  String uid;
  String email;
  String password;
  String? name;
  UserType userType;
  String? photoUrl;
  String? plate;
  String? plateUrl;

  Profile({
    this.uid = '',
    required this.email,
    required this.password,
    this.name,
    required this.userType,
    this.photoUrl,
    this.plate,
    this.plateUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'userType': userType.toString().split('.').last,
      'photoUrl': photoUrl,
      'plate': plate, // เพิ่มตรงนี้
      'plateUrl': plateUrl,
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      password: '',
      name: map['name'],
      userType: map['userType'] == 'rider' ? UserType.rider : UserType.user,
      photoUrl: map['photoUrl'],
      plate: map['plate'],
      plateUrl: map['photoUrl'],
    );
  }
}
