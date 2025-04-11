import 'package:cloud_firestore/cloud_firestore.dart';

class LiveStream {
  final String id;
  final String title;
  final String broadcasterId;
  final String broadcasterName;
  final String thumbnailUrl;
  final int viewerCount;
  final bool isLive;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<String> viewers;
  final List<String> moderators;
  final Map<String, dynamic> data;

  LiveStream({
    required this.id,
    required this.title,
    required this.broadcasterId,
    required this.broadcasterName,
    required this.thumbnailUrl,
    required this.viewerCount,
    required this.isLive,
    required this.startedAt,
    this.endedAt,
    required this.viewers,
    required this.moderators,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'broadcasterId': broadcasterId,
      'broadcasterName': broadcasterName,
      'thumbnailUrl': thumbnailUrl,
      'viewerCount': viewerCount,
      'isLive': isLive,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'viewers': viewers,
      'moderators': moderators,
    };
  }

  factory LiveStream.fromMap(Map<String, dynamic> map, [String? id]) {
    final bool isLive = map['status'] == 'live' ||
        (map['isLive'] == true && map['status'] != 'ended');

    return LiveStream(
      id: id ?? map['id'] ?? '',
      title: map['title'] ?? '',
      broadcasterId: map['broadcasterId'] ?? map['astrologist_id'] ?? '',
      broadcasterName: map['broadcasterName'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      viewerCount: map['viewerCount']?.toInt() ?? 0,
      isLive: isLive,
      startedAt: (map['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: map['endedAt'] != null
          ? (map['endedAt'] as Timestamp).toDate()
          : null,
      viewers: List<String>.from(map['viewers'] ?? []),
      moderators: List<String>.from(map['moderators'] ?? []),
      data: map,
    );
  }

  LiveStream copyWith({
    String? id,
    String? title,
    String? broadcasterId,
    String? broadcasterName,
    String? thumbnailUrl,
    int? viewerCount,
    bool? isLive,
    DateTime? startedAt,
    DateTime? endedAt,
    List<String>? viewers,
    List<String>? moderators,
    Map<String, dynamic>? data,
  }) {
    return LiveStream(
      id: id ?? this.id,
      title: title ?? this.title,
      broadcasterId: broadcasterId ?? this.broadcasterId,
      broadcasterName: broadcasterName ?? this.broadcasterName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      viewerCount: viewerCount ?? this.viewerCount,
      isLive: isLive ?? this.isLive,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      viewers: viewers ?? this.viewers,
      moderators: moderators ?? this.moderators,
      data: data ?? this.data,
    );
  }

  factory LiveStream.fromDocumentSnapshot(DocumentSnapshot doc) {
    final docData = doc.data() as Map<String, dynamic>? ?? {};
    return LiveStream(
      id: doc.id,
      title: docData['title'] ?? '',
      broadcasterId:
          docData['broadcasterId'] ?? docData['astrologist_id'] ?? '',
      broadcasterName: docData['broadcasterName'] ?? '',
      thumbnailUrl: docData['thumbnailUrl'] ?? '',
      viewerCount: docData['viewerCount']?.toInt() ?? 0,
      isLive: docData['isLive'] ?? docData['status'] == 'live',
      startedAt:
          (docData['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: docData['endedAt'] != null
          ? (docData['endedAt'] as Timestamp).toDate()
          : null,
      viewers: List<String>.from(docData['viewers'] ?? []),
      moderators: List<String>.from(docData['moderators'] ?? []),
      data: docData,
    );
  }

  static List<LiveStream> fromQuerySnapshot(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => LiveStream.fromDocumentSnapshot(doc))
        .toList();
  }
}
