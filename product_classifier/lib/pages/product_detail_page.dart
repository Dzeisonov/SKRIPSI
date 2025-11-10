import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'full_screen_viewer.dart';

class ProductDetail {
  final String name;
  final String category;
  final String description;
  final List<String> advantages;
  final String bahan;

  ProductDetail({
    required this.name,
    required this.category,
    required this.description,
    required this.advantages,
    required this.bahan,
  });

  // Factory constructor untuk membuat objek ProductDetail dari JSON
  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    return ProductDetail(
      name: json['name'] ?? 'Unnamed Product',
      category: json['category'] ?? 'No Category',
      description: json['description'] ?? 'No description available.',
      advantages: List<String>.from(json['advantages'] ?? []),
      // Menangani key 'Bahan' atau 'bahan' yang tidak konsisten
      bahan: json['Bahan'] ?? json['bahan'] ?? 'Informasi tidak tersedia',
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  final String productName;
  final String imageName;

  const ProductDetailPage({
    super.key,
    required this.productName,
    required this.imageName,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late Future<ProductDetail?> _productDetailFuture;

  @override
  void initState() {
    super.initState();
    _productDetailFuture = _loadProductDetails();
  }

  // --- Fungsi untuk memuat dan mem-parsing JSON ---
  Future<ProductDetail?> _loadProductDetails() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/products.json');
      final Map<String, dynamic> allProducts = json.decode(jsonString);

      if (allProducts.containsKey(widget.imageName)) {
        return ProductDetail.fromJson(allProducts[widget.imageName]);
      }
      return null; // Produk tidak ditemukan di JSON
    } catch (e) {
      print('Error loading product details: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Latar belakang utama untuk area app bar
      body: FutureBuilder<ProductDetail?>(
        future: _productDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Gagal memuat detail produk.'));
          }

          final product = snapshot.data!;

          return CustomScrollView(
            slivers: [
              // AppBar yang menampilkan gambar
              SliverAppBar(
                expandedHeight: 300.0,
                pinned: true,
                elevation: 2,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  background: Hero(
                    tag: widget.imageName,
                    // --- 2. BUAT GAMBAR DAPAT DI-TAP ---
                    child: GestureDetector(
                      onTap: () {
                        // 3. NAVIGASI KE HALAMAN FULL SCREEN
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenImageViewer(
                              imageName: widget.imageName,
                            ),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/images/${widget.imageName}.jpg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // Konten halaman di dalam "sleeve" abu-abu yang rounded
              SliverToBoxAdapter(
                child: Container(
                  // Dekorasi untuk membuat "sleeve"
                  decoration: BoxDecoration(
                    color: Colors.grey[100], // Warna latar belakang abu-abu
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25.0),
                      topRight: Radius.circular(25.0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // Judul Produk
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Kategori Produk
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          product.category,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Divider(),
                      ),

                      // Bagian Deskripsi
                      _buildSectionTitle('Deskripsi'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          product.description,
                          textAlign: TextAlign.justify,
                          style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bagian Keunggulan
                      _buildSectionTitle('Keunggulan'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          product.advantages.map((s) => '• $s').join('\n'),
                          textAlign: TextAlign.justify,
                          style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bagian Bahan Utama
                      _buildSectionTitle('Bahan'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          product.bahan,
                          textAlign: TextAlign.justify,
                          style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 50), // Spasi ekstra di bagian bawah
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper widget untuk judul setiap bagian agar konsisten
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}