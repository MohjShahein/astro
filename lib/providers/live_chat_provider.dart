import 'package:flutter/foundation.dart';
import '../models/live_chat_message.dart';

class LiveChatProvider with ChangeNotifier {
  final List<LiveChatMessage> _messages = [];
  bool _isTyping = false;
  String? _typingUserId;
  String? _typingUserName;

  List<LiveChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;
  String? get typingUserId => _typingUserId;
  String? get typingUserName => _typingUserName;

  void addMessage(LiveChatMessage message) {
    _messages.add(message);
    notifyListeners();
  }

  void addMessages(List<LiveChatMessage> newMessages) {
    _messages.addAll(newMessages);
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void setTypingStatus(bool isTyping, {String? userId, String? userName}) {
    _isTyping = isTyping;
    _typingUserId = userId;
    _typingUserName = userName;
    notifyListeners();
  }

  void clear() {
    _messages.clear();
    _isTyping = false;
    _typingUserId = null;
    _typingUserName = null;
    notifyListeners();
  }
}
