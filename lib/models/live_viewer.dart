import 'package:cloud_firestore/cloud_firestore.dart';

class LiveViewer {
  final String userId;
  final String userName;
  final String? userImage;
  final DateTime joinedAt;
  final DateTime? lastActive;

  LiveViewer({
    required this.userId,
    required this.userName,
    this.userImage,
    required this.joinedAt,
    this.lastActive,
  });

  factory LiveViewer.fromMap(Map<String, dynamic> map) {
    return LiveViewer(
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      userImage: map['userImage'] as String?,
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      lastActive: map['lastActive'] != null
          ? (map['lastActive'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
    };
  }

  LiveViewer copyWith({
    String? userId,
    String? userName,
    String? userImage,
    DateTime? joinedAt,
    DateTime? lastActive,
  }) {
    return LiveViewer(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userImage: userImage ?? this.userImage,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
