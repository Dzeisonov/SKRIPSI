import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:product_classifier/pages/product_detail_page.dart';
import 'package:shimmer/shimmer.dart';

// --- ONDA COLOR SCHEME ---
const ondaBlue = Color(0xFF0055A5);
const ondaYellow = Color(0xFFFFC107);
const backgroundLight = Color(0xFFF9FAFB);
const textPrimary = Color(0xFF212121);
const textSecondary = Color(0xFF757575);

// --- Data model ---
class Product {
  final String id;
  final String name;
  final String category;

  Product({required this.id, required this.name, required this.category});
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Product> _allProducts = [];
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProductData();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _loadProductData() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/products.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      final List<Product> loadedProducts = [];
      final Set<String> loadedCategories = {};

      jsonData.forEach((key, value) {
        final product = Product(
          id: key,
          name: value['name'] ?? key.replaceAll('_', ' '),
          category: value['category'] ?? 'Uncategorized',
        );
        loadedProducts.add(product);
        loadedCategories.add(product.category);
      });

      final sortedCategories = loadedCategories.toList()..sort();

      setState(() {
        _allProducts = loadedProducts;
        _categories = ['Semua', ...sortedCategories];
        _isLoading = false;
        _tabController = TabController(length: _categories.length, vsync: this);
        _tabController.addListener(() => setState(() {}));
      });
    } catch (e) {
      debugPrint("Error loading products: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    if (!_isLoading) _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Search Bar ---
  Widget _buildSearchBar({bool isLandscape = false}) {
    final String currentCategory = (_categories.isNotEmpty &&
            !_isLoading &&
            _tabController.index < _categories.length)
        ? _categories[_tabController.index]
        : 'Semua';

    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: isLandscape ? 'Cari...' : 'Cari di kategori "$currentCategory"...',
        prefixIcon: const Icon(Icons.search, color: textSecondary),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: ondaYellow, width: 2),
        ),
      ),
    );
  }

  // --- Product Grid ---
  Widget _buildCategoryGrid(List<Product> products) {
    if (products.isEmpty) {
      return const Center(child: Text("Produk tidak ditemukan."));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = (constraints.maxWidth ~/ 180).clamp(2, 5);
        return AnimationLimiter(
          child: GridView.builder(
            key: ValueKey(_categories[_tabController.index]),
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return AnimationConfiguration.staggeredGrid(
                position: index,
                duration: const Duration(milliseconds: 375),
                columnCount: crossAxisCount,
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: buildProductCard(context, product.id, product.name),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- Product Card ---
  Widget buildProductCard(
      BuildContext context, String imageName, String displayName) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 2),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailPage(
                productName: displayName,
                imageName: imageName,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Hero(
                  tag: imageName,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      'assets/images/$imageName.jpg',
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) =>
                          Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Lihat detail produk",
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Tab View Builder ---
  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: _categories.map((category) {
        final query = _searchController.text.toLowerCase();
        final productsForCategory = _allProducts.where((product) {
          final nameMatches = product.name.toLowerCase().contains(query);
          final categoryMatches =
              category == 'Semua' || product.category == category;
          return nameMatches && categoryMatches;
        }).toList();
        return _buildCategoryGrid(productsForCategory);
      }).toList(),
    );
  }

  // --- Main Layout ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                const double breakpoint = 800.0;
                final bool isWide = constraints.maxWidth >= breakpoint;

                if (isWide) {
                  // LANDSCAPE MODE
                  return SafeArea(
                    child: Row(
                      children: [
                        // LEFT PANEL
                        Container(
                          width: 240,
                          color: ondaBlue,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSearchBar(isLandscape: true),
                              const SizedBox(height: 16),
                              Expanded(
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    scrollbarTheme: ScrollbarThemeData(
                                      thickness: MaterialStateProperty.all(8.0),
                                      trackVisibility:
                                          MaterialStateProperty.all(true),
                                      trackColor: MaterialStateProperty.all(
                                          Colors.black.withOpacity(0.15)),
                                      thumbColor: MaterialStateProperty.all(
                                          Colors.black.withOpacity(0.5)),
                                    ),
                                  ),
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    child: AnimationLimiter(
                                      child: ListView.builder(
                                        itemCount: _categories.length,
                                        itemBuilder: (context, index) {
                                          final category = _categories[index];
                                          final isSelected =
                                              _categories[_tabController.index] ==
                                                  category;

                                          return AnimationConfiguration
                                              .staggeredList(
                                            position: index,
                                            duration: const Duration(
                                                milliseconds: 450),
                                            child: SlideAnimation(
                                              verticalOffset: 40.0,
                                              curve: Curves.easeOutCubic,
                                              child: FadeInAnimation(
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                      milliseconds: 250),
                                                  curve: Curves.easeInOut,
                                                  margin: const EdgeInsets
                                                      .symmetric(vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? ondaYellow
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: ListTile(
                                                    dense: true,
                                                    title:
                                                        AnimatedDefaultTextStyle(
                                                      duration: const Duration(
                                                          milliseconds: 250),
                                                      curve: Curves.easeInOut,
                                                      style: TextStyle(
                                                        fontWeight: isSelected
                                                            ? FontWeight.bold
                                                            : FontWeight.w500,
                                                        color: isSelected
                                                            ? Colors.black
                                                            : Colors.white,
                                                      ),
                                                      child: Text(category),
                                                    ),
                                                    onTap: () => _tabController
                                                        .animateTo(_categories
                                                            .indexOf(category)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // RIGHT PANEL
                        Expanded(
                          child: Container(
                            color: backgroundLight,
                            child: _buildTabBarView(),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // PORTRAIT MODE
                  return Column(
                    children: [
                      Material(
                        elevation: 2,
                        child: Container(
                          color: ondaBlue,
                          child: SafeArea(
                            bottom: false,
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: _buildSearchBar(),
                                ),
                                const SizedBox(height: 16),
                                TabBar(
                                  controller: _tabController,
                                  isScrollable: true,
                                  labelColor: ondaYellow,
                                  unselectedLabelColor:
                                      Colors.white,
                                  indicatorColor: ondaYellow,
                                  indicatorWeight: 3,
                                  labelStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                  tabs: _categories
                                      .map((c) => Tab(text: c))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: _buildTabBarView()),
                    ],
                  );
                }
              },
            ),
    );
  }
}
