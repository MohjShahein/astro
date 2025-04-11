import 'package:flutter/material.dart';
import '../services/live_stream_service.dart';
import '../services/live_stream_log_service.dart';

class LiveStreamSimulationPage extends StatefulWidget {
  const LiveStreamSimulationPage({Key? key}) : super(key: key);

  @override
  State<LiveStreamSimulationPage> createState() =>
      _LiveStreamSimulationPageState();
}

class _LiveStreamSimulationPageState extends State<LiveStreamSimulationPage> {
  final TextEditingController _astrologerIdController = TextEditingController();
  final TextEditingController _viewerIdsController = TextEditingController();
  bool _isSimulating = false;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _astrologerIdController.text = 'astrologer1'; // معرف افتراضي للمنجم
    _viewerIdsController.text =
        'user1,user2,user3'; // معرفات افتراضية للمشاهدين
  }

  @override
  void dispose() {
    _astrologerIdController.dispose();
    _viewerIdsController.dispose();
    super.dispose();
  }

  void _addLog(String log) {
    setState(() {
      _logs.add(log);
    });
  }

  Future<void> _startSimulation() async {
    if (_isSimulating) return;

    setState(() {
      _isSimulating = true;
      _logs = [];
      _logs.add('بدء المحاكاة...');
    });

    try {
      final astrologerId = _astrologerIdController.text.trim();
      final viewerIds = _viewerIdsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (astrologerId.isEmpty) {
        _addLog('⚠️ معرف المنجم مطلوب');
        return;
      }

      if (viewerIds.isEmpty) {
        _addLog('⚠️ يجب إدخال معرف مشاهد واحد على الأقل');
        return;
      }

      _addLog('بدء محاكاة جلسة بث مباشر');
      _addLog('معرف المنجم: $astrologerId');
      _addLog('معرفات المشاهدين: ${viewerIds.join(', ')}');

      // تشغيل المحاكاة مع استخدام التابع _addLog لتسجيل الرسائل
      final originalLogService = LiveStreamLogService.instance;
      LiveStreamLogService.instance = CallbackLiveStreamLogService(_addLog);

      // تشغيل المحاكاة
      await LiveStreamService.simulateCompleteLiveStreamSession(
        astrologerId: astrologerId,
        viewerIds: viewerIds,
      );

      // إعادة خدمة السجلات إلى الوضع الأصلي
      LiveStreamLogService.instance = originalLogService;

      _addLog('انتهت المحاكاة');
    } catch (e) {
      _addLog('⚠️ خطأ غير متوقع: $e');
    } finally {
      setState(() {
        _isSimulating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محاكاة البث المباشر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isSimulating
                ? null
                : () {
                    setState(() {
                      _logs = [];
                    });
                  },
            tooltip: 'مسح السجلات',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إعدادات المحاكاة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _astrologerIdController,
                      decoration: const InputDecoration(
                        labelText: 'معرف المنجم',
                        border: OutlineInputBorder(),
                        hintText: 'أدخل معرف المنجم (مثل: astrologer1)',
                      ),
                      enabled: !_isSimulating,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _viewerIdsController,
                      decoration: const InputDecoration(
                        labelText: 'معرفات المشاهدين (مفصولة بفواصل)',
                        border: OutlineInputBorder(),
                        hintText: 'مثال: user1,user2,user3',
                      ),
                      enabled: !_isSimulating,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSimulating ? null : _startSimulation,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isSimulating
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('بدء المحاكاة'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'سجلات المحاكاة:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    Color textColor = Colors.black;

                    if (log.contains('⚠️') || log.contains('خطأ')) {
                      textColor = Colors.red;
                    } else if (log.contains('✅')) {
                      textColor = Colors.green;
                    } else if (log.contains('ℹ️')) {
                      textColor = Colors.blue;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
