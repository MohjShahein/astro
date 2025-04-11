class ChatMessageModel {
  final String id;
  final String userId;
  final String message;
  final DateTime timestamp;

  ChatMessageModel({
    required this.id,
    required this.userId,
    required this.message,
    required this.timestamp,
  });

  factory ChatMessageModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? messageTime;
    try {
      // محاولة الحصول على الوقت من created_at أو timestamp
      if (data['created_at'] != null) {
        messageTime = data['created_at'].toDate();
      } else if (data['timestamp'] != null) {
        messageTime = data['timestamp'].toDate();
      }
    } catch (e) {
      print('خطأ في تحويل الطابع الزمني: $e');
    }

    return ChatMessageModel(
      id: id,
      // استخدام sender_id أو user_id أيهما متوفر
      userId: data['sender_id'] ?? data['user_id'] ?? '',
      // استخدام content أو message أيهما متوفر
      message: data['content'] ?? data['message'] ?? '',
      timestamp: messageTime ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'sender_id': userId, 'content': message, 'created_at': timestamp};
  }

  // طريقة مساعدة للحصول على وقت الرسالة بتنسيق آمن
  String getFormattedTime() {
    try {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }
}
