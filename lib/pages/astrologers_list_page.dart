import 'package:flutter/material.dart';
import '../widgets/shimmer_loader.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/review_service.dart';
import 'astrologer_profile_page.dart';
import '../components/user_profile_image.dart';

class AstrologersListPage extends StatefulWidget {
  final String currentUserId;

  const AstrologersListPage({super.key, required this.currentUserId});

  @override
  _AstrologersListPageState createState() => _AstrologersListPageState();
}

class _AstrologersListPageState extends State<AstrologersListPage> {
  List<UserModel> _astrologers = [];
  List<UserModel> _filteredAstrologers = [];
  bool _isLoading = true;
  final Map<String, double> _ratings = {};
  final bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAstrologers();
    _searchController.addListener(_filterAstrologers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAstrologers);
    _searchController.dispose();
    super.dispose();
  }

  void _filterAstrologers() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredAstrologers = List.from(_astrologers);
      } else {
        _filteredAstrologers = _astrologers.where((astrologer) {
          // البحث في الاسم
          final fullName =
              '${astrologer.firstName ?? ''} ${astrologer.lastName ?? ''}'
                  .toLowerCase();
          if (fullName.contains(query)) {
            return true;
          }

          // البحث في الخدمات
          if (astrologer.services != null) {
            for (var service in astrologer.services!) {
              if (service.toLowerCase().contains(query)) {
                return true;
              }
            }
          }

          return false;
        }).toList();
      }
    });
  }

  Future<void> _loadAstrologers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final astrologers = await AuthService.getApprovedAstrologers();

      if (!mounted) return;
      setState(() {
        _astrologers = astrologers;
        _filteredAstrologers = List.from(astrologers);
        _isLoading = false;
      });

      // Load ratings for each astrologer
      for (var astrologer in astrologers) {
        _loadAstrologerRating(astrologer.id);
      }
    } catch (e) {
      print('Error loading astrologers: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل قائمة الفلكيين: $e')),
      );
    }
  }

  Future<void> _loadAstrologerRating(String astrologerId) async {
    try {
      final rating = await ReviewService.getAverageRating(astrologerId);
      if (!mounted) return;
      setState(() {
        _ratings[astrologerId] = rating;
      });
    } catch (e) {
      print('Error loading rating for $astrologerId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // العنوان
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تجربة عملية في تفسير الخرائط الفلكية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    Text(
                      'استكشاف عالم الأبراج',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ),

            // شريط البحث
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5.0, vertical: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'خرائط الفلكية، التوقعات اليومية..',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF191923)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Color(0xFF191923)),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide:
                          const BorderSide(color: Color(0xFFF2C792), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
                  ),
                  style: const TextStyle(color: Color(0xFF191923)),
                  cursorColor: const Color(0xFFF2C792),
                ),
              ),
            ),

            // محتوى الصفحة الرئيسي
            _isLoading
                ? SliverFillRemaining(
                    child: ShimmerLoader(
                      child: ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 5,
                        itemBuilder: (context, index) => const ShimmerCard(),
                      ),
                    ),
                  )
                : _filteredAstrologers.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off,
                                  size: 50, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'لا توجد نتائج مطابقة للبحث',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_searchController.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                  child: const Text('مسح البحث'),
                                ),
                              ]
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final astrologer = _filteredAstrologers[index];
                              final rating = _ratings[astrologer.id] ?? 0.0;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                color: const Color(0xFF191923),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AstrologerProfilePage(
                                          currentUserId: widget.currentUserId,
                                          astrologerId: astrologer.id,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        UserProfileImage(
                                          userId: astrologer.id,
                                          radius: 30,
                                          placeholderIcon: const Icon(
                                            Icons.person,
                                            size: 30,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${astrologer.firstName ?? ''} ${astrologer.lastName ?? ''}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              if (astrologer.services != null &&
                                                  astrologer.services!
                                                      .isNotEmpty) ...[
                                                Text(
                                                  'الخدمات: ${astrologer.services!.join(', ')}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                              ],
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    size: 18,
                                                    color: Colors.amber,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    rating.toStringAsFixed(1),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: _filteredAstrologers.length,
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}
