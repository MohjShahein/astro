import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/live_stream.dart';
import '../services/live_stream_service.dart';
import '../services/user_service.dart';
import 'live_stream_viewer_page.dart';
import 'live_stream_broadcaster_page.dart';

class LiveStreamsPage extends StatefulWidget {
  final UserModel currentUser;

  const LiveStreamsPage({
    super.key,
    required this.currentUser,
  });

  @override
  State<LiveStreamsPage> createState() => _LiveStreamsPageState();
}

class _LiveStreamsPageState extends State<LiveStreamsPage> {
  late Stream<List<LiveStream>> _liveStreamsStream;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  void _initializeStream() {
    print('تهيئة تدفق البث المباشر...');
    _liveStreamsStream = LiveStreamService.getLiveStreams();
    print('تم تهيئة تدفق البث المباشر');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('البث المباشر'),
        actions: [
          // إذا كان المستخدم منجمًا، يمكنه بدء بث مباشر جديد
          if (widget.currentUser.userType == 'astrologer')
            IconButton(
              icon: const Icon(Icons.video_call),
              onPressed: _showCreateLiveStreamDialog,
            ),
        ],
      ),
      body: StreamBuilder<List<LiveStream>>(
        stream: _liveStreamsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('خطأ في تدفق البث المباشر: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ: ${snapshot.error}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            print('لا يوجد بث مباشر حاليًا');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.videocam_off,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا يوجد بث مباشر حاليًا',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.currentUser.userType == 'astrologer')
                    ElevatedButton.icon(
                      onPressed: _showCreateLiveStreamDialog,
                      icon: const Icon(Icons.video_call),
                      label: const Text('بدء بث مباشر جديد'),
                    ),
                ],
              ),
            );
          }

          final liveStreams = snapshot.data!;
          print('عدد البث المباشر المستلم: ${liveStreams.length}');

          // تصفية البث المباشر غير الصالح
          final validLiveStreams = liveStreams.where((liveStream) {
            print('فحص بث مباشر: ${liveStream.id}');
            print('بيانات البث المباشر:');
            liveStream.data.forEach((key, value) {
              print('  $key: $value');
            });

            // التحقق من وجود اسم القناة بأي من الحقلين
            final hasChannelName = (liveStream.data['channelName'] != null &&
                    liveStream.data['channelName'].toString().isNotEmpty) ||
                (liveStream.data['channel_name'] != null &&
                    liveStream.data['channel_name'].toString().isNotEmpty);

            final isValid = ((liveStream.data['astrologist_id'] != null &&
                        liveStream.data['astrologist_id']
                            .toString()
                            .isNotEmpty) ||
                    (liveStream.data['broadcasterId'] != null &&
                        liveStream.data['broadcasterId']
                            .toString()
                            .isNotEmpty)) &&
                (liveStream.data['status'] == 'live' || liveStream.isLive) &&
                hasChannelName;
            print('البث المباشر صالح: $isValid');
            return isValid;
          }).toList();

          print('عدد البث المباشر الصالح: ${validLiveStreams.length}');

          if (validLiveStreams.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.videocam_off,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا يوجد بث مباشر صالح حاليًا',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.currentUser.userType == 'astrologer')
                    ElevatedButton.icon(
                      onPressed: _showCreateLiveStreamDialog,
                      icon: const Icon(Icons.video_call),
                      label: const Text('بدء بث مباشر جديد'),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: validLiveStreams.length,
            itemBuilder: (context, index) {
              final liveStream = validLiveStreams[index];
              final liveStreamId = liveStream.id;

              // التحقق من وجود معرف المنجم بأي من الحقلين
              final astrologistId = liveStream.data['astrologist_id'] ??
                  liveStream.data['broadcasterId'];
              if (astrologistId == null) {
                return const SizedBox.shrink();
              }

              // الحصول على اسم القناة بأي من الحقلين
              final channelName = liveStream.data['channelName'] ??
                  liveStream.data['channel_name'];
              if (channelName == null) {
                return const SizedBox.shrink();
              }

              return FutureBuilder<UserModel?>(
                future: UserService.getUserById(astrologistId as String),
                builder: (context, astrologerSnapshot) {
                  if (astrologerSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (astrologerSnapshot.hasError ||
                      !astrologerSnapshot.hasData) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child:
                            Center(child: Text('خطأ في تحميل بيانات المنجم')),
                      ),
                    );
                  }

                  final astrologer = astrologerSnapshot.data;
                  if (astrologer == null) {
                    return const SizedBox
                        .shrink(); // تجاهل البث المباشر إذا لم يتم العثور على المنجم
                  }

                  final isCurrentUserAstrologer =
                      widget.currentUser.id == astrologistId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    clipBehavior: Clip.antiAlias,
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // رأس البطاقة مع صورة المنجم
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            image: astrologer.profileImageUrl != null &&
                                    astrologer.profileImageUrl!.isNotEmpty
                                ? DecorationImage(
                                    fit: BoxFit.cover,
                                    image: NetworkImage(
                                        astrologer.profileImageUrl!),
                                  )
                                : null,
                          ),
                          child: Stack(
                            children: [
                              // مؤشر البث المباشر
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 4.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.fiber_manual_record,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'مباشر',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // عدد المشاهدين
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 4.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.remove_red_eye,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${liveStream.data['viewerCount'] ?? liveStream.data['viewers'] ?? liveStream.data['total_viewers'] ?? 0}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // تفاصيل البث المباشر
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage:
                                        astrologer.profileImageUrl != null &&
                                                astrologer
                                                    .profileImageUrl!.isNotEmpty
                                            ? NetworkImage(
                                                astrologer.profileImageUrl!)
                                            : null,
                                    child: astrologer.profileImageUrl == null ||
                                            (astrologer.profileImageUrl !=
                                                    null &&
                                                astrologer
                                                    .profileImageUrl!.isEmpty)
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          astrologer.fullName ?? 'منجم',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          astrologer.aboutMe ?? '',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                liveStream.data['title'] as String? ??
                                    'بث مباشر',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                liveStream.data['description'] as String? ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),

                              // زر الانضمام للبث
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _joinLiveStream(
                                    liveStreamId,
                                    liveStream.data,
                                    isCurrentUserAstrologer,
                                  ),
                                  icon: Icon(
                                    isCurrentUserAstrologer
                                        ? Icons.settings
                                        : Icons.visibility,
                                  ),
                                  label: Text(
                                    isCurrentUserAstrologer
                                        ? 'إدارة البث المباشر'
                                        : 'مشاهدة البث المباشر',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCurrentUserAstrologer
                                        ? Colors.blue
                                        : Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),

      // زر عائم لبدء بث مباشر جديد (للمنجمين فقط)
      floatingActionButton: widget.currentUser.userType == 'astrologer'
          ? FloatingActionButton.extended(
              onPressed: _showCreateLiveStreamDialog,
              icon: const Icon(Icons.video_call),
              label: const Text('بث مباشر جديد'),
            )
          : null,
    );
  }

  // الانضمام إلى بث مباشر
  void _joinLiveStream(
    String liveStreamId,
    Map<String, dynamic> liveStreamData,
    bool isCurrentUserAstrologer,
  ) async {
    // الحصول على اسم القناة بأي من الحقلين
    final channelName =
        liveStreamData['channelName'] ?? liveStreamData['channel_name'];
    if (channelName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ: لم يتم العثور على اسم القناة')),
      );
      return;
    }

    if (isCurrentUserAstrologer) {
      // المنجم يدير البث
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveStreamBroadcasterPage(
            currentUser: widget.currentUser,
            liveStreamId: liveStreamId,
            channelName: channelName,
            liveStreamData: liveStreamData,
          ),
        ),
      );
    } else {
      // إضافة المستخدم كمشاهد
      try {
        await LiveStreamService.addViewer(liveStreamId, widget.currentUser.id);

        // الانتقال إلى صفحة المشاهدة
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveStreamViewerPage(
              currentUser: widget.currentUser,
              liveStreamId: liveStreamId,
              channelName: channelName,
              liveStreamData: liveStreamData,
            ),
          ),
        ).then((_) async {
          // عند العودة من صفحة المشاهدة، قم بإزالة المستخدم من المشاهدين
          await LiveStreamService.removeViewer(
              liveStreamId, widget.currentUser.id);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  // إظهار مربع حوار لإنشاء بث مباشر جديد
  void _showCreateLiveStreamDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بث مباشر جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان البث المباشر',
                  hintText: 'مثال: نقاش حول الأبراج',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'وصف البث المباشر',
                  hintText: 'مثال: سنناقش تأثير الأبراج على حياتنا اليومية',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();

              if (title.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                      content: Text('يرجى إدخال عنوان للبث المباشر')),
                );
                return;
              }

              try {
                // إغلاق مربع الحوار قبل إنشاء البث المباشر
                Navigator.pop(dialogContext);

                print('جاري إنشاء بث مباشر جديد من صفحة البث المباشر');
                final liveStreamId = await LiveStreamService.createLiveStream(
                  title: title,
                  broadcasterName: widget.currentUser.fullName ?? 'منجم',
                );
                print('تم الحصول على معرف البث المباشر: $liveStreamId');

                // الحصول على بيانات البث المباشر
                print('جاري الحصول على بيانات البث المباشر من Firestore');
                final docSnapshot = await FirebaseFirestore.instance
                    .collection('live_streams')
                    .doc(liveStreamId)
                    .get();

                if (!docSnapshot.exists) {
                  print('خطأ: وثيقة البث المباشر غير موجودة');
                  throw Exception('فشل إنشاء البث المباشر');
                }

                final liveStreamData = docSnapshot.data()!;
                print('تم الحصول على بيانات البث المباشر بنجاح');
                print('محتويات البث المباشر:');
                liveStreamData.forEach((key, value) {
                  print('  $key: $value');
                });

                String? channelName;
                // محاولة الحصول على اسم القناة بعدة طرق
                if (liveStreamData.containsKey('channelName') &&
                    liveStreamData['channelName'] != null) {
                  channelName = liveStreamData['channelName'].toString();
                  print(
                      'تم العثور على اسم القناة من الحقل: channelName = $channelName');
                } else if (liveStreamData.containsKey('channel_name') &&
                    liveStreamData['channel_name'] != null) {
                  channelName = liveStreamData['channel_name'].toString();
                  print(
                      'تم العثور على اسم القناة من الحقل: channel_name = $channelName');
                }

                if (channelName == null || channelName.isEmpty) {
                  print('تحذير: اسم القناة غير موجود، استخدام معرف البث كبديل');
                  channelName = 'channel_$liveStreamId';

                  // تحديث وثيقة البث المباشر باسم القناة
                  try {
                    await FirebaseFirestore.instance
                        .collection('live_streams')
                        .doc(liveStreamId)
                        .update({'channelName': channelName});
                    print('تم تحديث وثيقة البث المباشر باسم القناة الجديد');
                  } catch (e) {
                    print('تحذير: فشل تحديث البث المباشر باسم القناة: $e');
                    // نستمر بالرغم من الخطأ
                  }
                }

                // الانتقال إلى صفحة البث
                print('الانتقال إلى صفحة البث المباشر...');
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LiveStreamBroadcasterPage(
                        currentUser: widget.currentUser,
                        liveStreamId: liveStreamId,
                        channelName: channelName,
                        liveStreamData: liveStreamData,
                      ),
                    ),
                  );
                  print('تم الانتقال إلى صفحة البث بنجاح');
                } else {
                  print('تحذير: السياق (context) لم يعد موجوداً');
                }
              } catch (e) {
                print('خطأ عام أثناء بدء البث المباشر: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ: $e')),
                  );
                }
              }
            },
            child: const Text('بدء البث'),
          ),
        ],
      ),
    );
  }

  bool _isValidLiveStream(DocumentSnapshot liveStream) {
    if (liveStream.data() == null) return false;

    final data = liveStream.data() as Map<String, dynamic>;

    // التحقق من وجود اسم القناة
    final hasChannelName = data.containsKey('channelName') &&
        data['channelName'] != null &&
        data['channelName'].toString().isNotEmpty;

    // التحقق من وجود مذيع
    final hasBroadcaster =
        (data.containsKey('broadcasterId') && data['broadcasterId'] != null) ||
            (data.containsKey('host_id') && data['host_id'] != null);

    // التحقق من حالة البث
    final isActive = data.containsKey('status') && data['status'] == 'live' ||
        (data.containsKey('isLive') && data['isLive'] == true);

    print('تفاصيل صلاحية البث المباشر:');
    print('  معرف البث: ${liveStream.id}');
    print('  لديه اسم قناة: $hasChannelName (${data['channelName']})');
    print('  لديه مذيع: $hasBroadcaster');
    print('  نشط: $isActive (${data['status'] ?? data['isLive']})');

    return hasChannelName && hasBroadcaster && isActive;
  }
}
