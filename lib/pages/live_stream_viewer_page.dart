import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/simple_live_stream_page.dart';
import '../models/user_model.dart';
import '../services/live_stream_service.dart';
import '../services/agora_service.dart';
import 'dart:developer' as developer;

class LiveStreamViewerPage extends StatefulWidget {
  final UserModel currentUser;
  final String liveStreamId;
  final String channelName;
  final Map<String, dynamic> liveStreamData;

  const LiveStreamViewerPage({
    Key? key,
    required this.currentUser,
    required this.liveStreamId,
    required this.channelName,
    required this.liveStreamData,
  }) : super(key: key);

  @override
  State<LiveStreamViewerPage> createState() => _LiveStreamViewerPageState();
}

class _LiveStreamViewerPageState extends State<LiveStreamViewerPage> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // سجل معلومات التصحيح للمساعدة في تشخيص المشكلات
      developer.log('بدء تهيئة صفحة مشاهد البث المباشر',
          name: 'LiveStreamViewer');
      developer.log('معرّف البث المباشر: ${widget.liveStreamId}',
          name: 'LiveStreamViewer');
      developer.log('اسم القناة: ${widget.channelName}',
          name: 'LiveStreamViewer');

      // التحقق من وجود معرف البث المباشر
      if (widget.liveStreamId.isEmpty) {
        throw Exception('معرف البث المباشر غير صالح');
      }

      // التحقق من حالة البث المباشر
      final liveStreamDoc = await FirebaseFirestore.instance
          .collection('live_streams')
          .doc(widget.liveStreamId)
          .get();

      if (!liveStreamDoc.exists) {
        throw Exception('البث المباشر غير موجود');
      }

      final liveStreamData = liveStreamDoc.data();
      if (liveStreamData == null) {
        throw Exception('بيانات البث المباشر غير صالحة');
      }

      // التحقق من حالة البث
      if (liveStreamData['status'] != 'live' &&
          liveStreamData['isLive'] != true) {
        throw Exception('البث المباشر غير نشط حالياً');
      }

      // اختبار خادم التوكن قبل الانتقال إلى صفحة البث
      String channelName = liveStreamData['channelName'] ?? widget.channelName;
      if (channelName.isEmpty) {
        throw Exception('اسم القناة غير صالح');
      }

      developer.log('اختبار الحصول على توكن للقناة: $channelName',
          name: 'LiveStreamViewer');

      final testTokenResult = await AgoraService.getToken(
        channelName: channelName,
        uid: 0,
        role: 2, // دور المشاهد
      );
      if (testTokenResult != null) {
        developer.log('تم الحصول على توكن Agora بنجاح',
            name: 'LiveStreamViewer');
      } else {
        developer.log(
            'تحذير: فشل في الحصول على توكن Agora، سيتم استخدام الوضع المؤقت',
            name: 'LiveStreamViewer');
      }

      // محاولة إضافة المشاهد إلى البث المباشر
      developer.log('محاولة إضافة المشاهد: ${widget.currentUser.id}',
          name: 'LiveStreamViewer');

      final viewerAdded = await LiveStreamService.addViewerToStream(
          widget.liveStreamId, widget.currentUser.id);

      if (!viewerAdded) {
        developer.log(
            'فشل في إضافة المشاهد إلى البث المباشر: ${widget.currentUser.id}',
            name: 'LiveStreamViewer');
        // لا نريد إيقاف العملية هنا، حاول المتابعة على أي حال
      } else {
        developer.log(
            'تم إضافة المشاهد إلى البث المباشر بنجاح: ${widget.currentUser.id}',
            name: 'LiveStreamViewer');
      }

      setState(() {
        _isLoading = false;
      });

      // الانتقال مباشرة إلى صفحة البث المباشر
      if (!mounted) return;

      developer.log('الانتقال إلى صفحة البث المباشر', name: 'LiveStreamViewer');

      // استخدام pushReplacement بدلاً من push للتخلص من الشاشة الحالية
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleLiveStreamPage(
            liveStreamData: widget.liveStreamData,
            isBroadcaster: false,
            liveStreamId: widget.liveStreamId,
            userId: widget.currentUser.id,
          ),
        ),
      ).then((_) async {
        // عند العودة من صفحة البث، قم بإزالة المشاهد
        developer.log('العودة من صفحة البث المباشر - إزالة المشاهد',
            name: 'LiveStreamViewer');

        final removed = await LiveStreamService.removeViewerFromStream(
            widget.liveStreamId, widget.currentUser.id);

        developer.log(
            removed ? 'تم إزالة المشاهد بنجاح' : 'فشل في إزالة المشاهد',
            name: 'LiveStreamViewer');
      });
    } catch (e) {
      developer.log('خطأ في تهيئة البث المباشر: $e', name: 'LiveStreamViewer');
      if (mounted) {
        setState(() {
          _errorMessage = 'خطأ في تهيئة البث المباشر: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشاهدة البث المباشر'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _errorMessage != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _initialize,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}
