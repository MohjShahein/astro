import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const ApproveAstrologerApp());
}

class ApproveAstrologerApp extends StatelessWidget {
  const ApproveAstrologerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إضافة منجم معتمد',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Tajawal'),
      home: const ApproveAstrologerPage(),
    );
  }
}

class ApproveAstrologerPage extends StatefulWidget {
  const ApproveAstrologerPage({super.key});

  @override
  _ApproveAstrologerPageState createState() => _ApproveAstrologerPageState();
}

class _ApproveAstrologerPageState extends State<ApproveAstrologerPage> {
  final TextEditingController _astrologerIdController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  Future<void> _approveAstrologer() async {
    final String astrologerId = _astrologerIdController.text.trim();

    if (astrologerId.isEmpty) {
      setState(() {
        _message = 'يرجى إدخال معرف المنجم';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      // التحقق من وجود المستخدم
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(astrologerId)
              .get();

      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
          _message = 'المستخدم غير موجود';
          _isSuccess = false;
        });
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['user_type'] != 'astrologer') {
        setState(() {
          _isLoading = false;
          _message = 'هذا المستخدم ليس منجماً';
          _isSuccess = false;
        });
        return;
      }

      // إضافة المنجم إلى قائمة المنجمين المعتمدين
      await FirebaseFirestore.instance
          .collection('approved_astrologers')
          .doc(astrologerId)
          .set({
            'approved_at': FieldValue.serverTimestamp(),
            'astrologer_id': astrologerId,
            'status': 'active',
          });

      // تحديث حالة المنجم في جدول المستخدمين
      await FirebaseFirestore.instance
          .collection('users')
          .doc(astrologerId)
          .update({'astrologer_status': 'approved'});

      setState(() {
        _isLoading = false;
        _message = 'تم اعتماد المنجم بنجاح';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = 'خطأ: ${e.toString()}';
        _isSuccess = false;
      });
    }
  }

  @override
  void dispose() {
    _astrologerIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة منجم معتمد')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _astrologerIdController,
              decoration: const InputDecoration(
                labelText: 'معرف المنجم',
                hintText: 'أدخل معرف المنجم الذي تريد اعتماده',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _approveAstrologer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('إضافة إلى قائمة المنجمين المعتمدين'),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _isSuccess ? Colors.green[900] : Colors.red[900],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
