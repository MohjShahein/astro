import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../components/user_profile_image.dart';
import '../models/user_model.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'astrologer_application_page.dart';
import 'astrologers_list_page.dart';
import 'sessions_page.dart';
import 'wallet_page.dart';
import 'live_streams_page.dart';
import 'live_stream_simulation_page.dart';

class MainPage extends StatefulWidget {
  final String userId;

  const MainPage({super.key, required this.userId});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  bool _isAdmin = false;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadUserData();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await AuthService.isCurrentUserAdmin();
      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
      });
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!mounted) return;
      setState(() {
        _userData = userDoc.data() as Map<String, dynamic>;
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // Home page with astrologers list
      AstrologersListPage(currentUserId: widget.userId),
      SessionsPage(userId: widget.userId),
      FutureBuilder<UserModel?>(
        future: UserService.getUserById(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
                child: Text('حدث خطأ أثناء تحميل معلومات المستخدم'));
          }

          return LiveStreamsPage(currentUser: snapshot.data!);
        },
      ),
      ProfilePage(userId: widget.userId),
    ];

    return Scaffold(
      appBar: AppBar(),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF191923),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (FirebaseAuth.instance.currentUser != null)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      final userData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final firstName = userData?['first_name'] ?? '';
                      final lastName = userData?['last_name'] ?? '';
                      return Column(
                        children: [
                          const SizedBox(height: 50),
                          UserProfileImage(
                            userId: widget.userId,
                            radius: 50,
                            placeholderIcon: const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$firstName $lastName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // رصيد المحفظة
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('wallets')
                                .doc(widget.userId)
                                .snapshots(),
                            builder: (context, walletSnapshot) {
                              if (walletSnapshot.hasData &&
                                  walletSnapshot.data != null &&
                                  walletSnapshot.data!.exists) {
                                final walletData = walletSnapshot.data!.data()
                                    as Map<String, dynamic>?;
                                final balance = walletData?['balance'] != null
                                    ? walletData!['balance'].toString()
                                    : '0';
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF21202F),
                                        Color(0xFF2C2A3F)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet,
                                        color: Color(0xFFF2C792),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '$balance كوينز',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF21202F),
                                      Color(0xFF2C2A3F)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.account_balance_wallet,
                                      color: Color(0xFFF2C792),
                                      size: 22,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      '0 كوينز',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }
                    return const SizedBox(height: 200);
                  },
                ),
              if (FirebaseAuth.instance.currentUser == null) ...[
                ListTile(
                  leading: const Icon(Icons.login,
                      color: Color(0xFFF2C792), size: 24),
                  title: const Text(
                    'تسجيل الدخول',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add,
                      color: Color(0xFFF2C792), size: 24),
                  title: const Text(
                    'إنشاء حساب',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.person,
                      color: Color(0xFFF2C792), size: 24),
                  title: const Text(
                    'الملف الشخصي',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedIndex = 3;
                    });
                    Navigator.pop(context);
                  },
                ),
                // إضافة زر التقديم كفلكي في القائمة الجانبية للمستخدمين العاديين
                FutureBuilder<Map<String, dynamic>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userId)
                      .get()
                      .then((doc) => doc.data() as Map<String, dynamic>),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'حدث خطأ في تحميل البيانات: ${snapshot.error}',
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: Text('لا توجد بيانات متاحة'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }

                    if (snapshot.hasData) {
                      final userData = snapshot.data!;
                      final userType =
                          userData['user_type'] as String? ?? 'normal';

                      if (userType == 'normal') {
                        return ListTile(
                          leading: const Icon(Icons.star,
                              color: Color(0xFFF2C792), size: 24),
                          title: const Text(
                            'التقديم كفلكي',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AstrologerApplicationPage(
                                  userId: widget.userId,
                                ),
                              ),
                            );
                          },
                        );
                      } else if (userType == 'astrologer') {
                        // إضافة رابط لصفحة محاكاة البث المباشر للمنجمين
                        return Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.live_tv,
                                  color: Color(0xFFF2C792), size: 24),
                              title: const Text(
                                'بث مباشر',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _selectedIndex =
                                      2; // تبديل إلى تاب البث المباشر
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.science,
                                  color: Color(0xFFF2C792), size: 24),
                              title: const Text(
                                'محاكاة البث المباشر',
                                style: TextStyle(color: Colors.white),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const LiveStreamSimulationPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }
                    }

                    return const SizedBox.shrink();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet,
                      color: Color(0xFFF2C792), size: 24),
                  title: const Text(
                    'المحفظة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WalletPage(userId: widget.userId),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info,
                      color: Color(0xFFF2C792), size: 24),
                  title: const Text(
                    'عن التطبيق',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    // TODO: Navigate to About page
                    Navigator.pop(context);
                  },
                ),

                // إضافة أيقونات التواصل الاجتماعي
                const SizedBox(height: 30),

                // إضافة نص "تابعونا على"
                const Center(
                  child: Text(
                    'تابعونا على',
                    style: TextStyle(
                      color: Color(0xFFF2C792),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // فيسبوك
                      InkWell(
                        onTap: () async {
                          // فتح صفحة فيسبوك
                          final Uri url =
                              Uri.parse('https://www.facebook.com/astrology');
                          if (!await launchUrl(url)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('لا يمكن فتح الرابط')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF21202F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF2C792),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: FaIcon(
                              FontAwesomeIcons.facebookF,
                              color: Color(0xFFF2C792),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // إنستغرام
                      InkWell(
                        onTap: () async {
                          // فتح صفحة إنستغرام
                          final Uri url =
                              Uri.parse('https://www.instagram.com/astrology');
                          if (!await launchUrl(url)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('لا يمكن فتح الرابط')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF21202F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF2C792),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: FaIcon(
                              FontAwesomeIcons.instagram,
                              color: Color(0xFFF2C792),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // واتساب
                      InkWell(
                        onTap: () async {
                          // فتح واتساب
                          final Uri url = Uri.parse('https://wa.me/1234567890');
                          if (!await launchUrl(url)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('لا يمكن فتح الرابط')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF21202F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF2C792),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: FaIcon(
                              FontAwesomeIcons.whatsapp,
                              color: Color(0xFFF2C792),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF191923),
        selectedItemColor: const Color(0xFFF2C792),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'المحادثات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_call),
            label: 'البث المباشر',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'الملف الشخصي',
          ),
        ],
      ),
    );
  }
}
