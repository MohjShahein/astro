import 'package:cloud_firestore/cloud_firestore.dart';

class LiveChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String? userImage;
  final String message;
  final DateTime timestamp;

  LiveChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    this.userImage,
    required this.message,
    required this.timestamp,
  });

  factory LiveChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveChatMessage(
      id: doc.id,
      userId: data['userId'] as String,
      userName: data['userName'] as String,
      userImage: data['userImage'] as String?,
      message: data['message'] as String,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  LiveChatMessage copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userImage,
    String? message,
    DateTime? timestamp,
  }) {
    return LiveChatMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userImage: userImage ?? this.userImage,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
