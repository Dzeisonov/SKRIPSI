import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const ondaBlue = Color(0xFF0055A5);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // Helper function to launch URLs
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        top: false,
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              return _buildLandscapeLayout(context);
            } else {
              return _buildPortraitLayout(context);
            }
          },
        ),
      ),
    );
  }

  // --- WIDGET PORTRAIT LAYOUT ---
  Widget _buildPortraitLayout(BuildContext context) {
    return AnimationLimiter(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Animate the header as the first block
            AnimationConfiguration.staggeredList(
              position: 0,
              duration: const Duration(milliseconds: 500),
              child: SlideAnimation(
                verticalOffset: -50.0,
                child: FadeInAnimation(child: _buildHeader(context)),
              ),
            ),
            // Animate the content card as the second block
            AnimationConfiguration.staggeredList(
              position: 1,
              duration: const Duration(milliseconds: 500),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(child: _buildContentCard(context)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WIDGET LANDSCAPE LAYOUT ---
  Widget _buildLandscapeLayout(BuildContext context) {
    return AnimationLimiter(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT PANEL (Blue background)
          Expanded(
            flex: 2,
            child: Container(
              color: ondaBlue,
              child: AnimationConfiguration.staggeredList(
                position: 0,
                duration: const Duration(milliseconds: 500),
                child: SlideAnimation(
                  horizontalOffset: -50.0,
                  child: FadeInAnimation(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _buildHeader(context, isLandscape: true),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // RIGHT PANEL (White scrollable content)
          Expanded(
            flex: 3,
            child: AnimationConfiguration.staggeredList(
              position: 1,
              duration: const Duration(milliseconds: 600),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: _buildContentCard(context, isLandscape: true),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable UI component for the Header ---
  Widget _buildHeader(BuildContext context, {bool isLandscape = false}) {
    final headerContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: isLandscape ? 0 : 50),
        Container(
          width: 160,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 3),
            image: const DecorationImage(
              alignment: Alignment.topCenter,
              fit: BoxFit.cover,
              image: AssetImage('assets/images/profile.png'),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          'Jason Permana',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'Mahasiswa S1 Teknik Informatika',
          style: TextStyle(fontSize: 16, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isLandscape ? 0 : 50),
      ],
    );

    return isLandscape
        ? Center(child: headerContent)
        : Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ondaBlue, ondaBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: headerContent,
          );
  }

  // --- Reusable UI component for the Content Card ---
  Widget _buildContentCard(BuildContext context, {bool isLandscape = false}) {
    final cardContent = Card(
      elevation: isLandscape ? 2 : 6,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tentang Saya',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Halo, nama saya Jason Permana, mahasiswa S1 Teknik Informatika di Universitas Tarumanagara.\n\n'
              'Aplikasi ini merupakan implementasi dari proyek skripsi saya yang berjudul, "Perancangan Sistem Klasifikasi Citra Produk Onda Menggunakan MobileNetV3". Sistem ini dirancang untuk mengatasi tantangan identifikasi produk di dunia nyata, khususnya untuk 15 varian kran Onda yang memiliki kemiripan visual tinggi.\n\n'
              'Dengan memanfaatkan deep learning dan arsitektur MobileNetV3, aplikasi ini mampu melakukan klasifikasi secara on-device, mengubah ponsel Anda menjadi alat identifikasi yang cepat dan akurat.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Connect With Me',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SocialButton(
                  icon: FontAwesomeIcons.github,
                  onPressed: () => _launchURL('https://github.com/Dzeisonov'),
                ),
                _SocialButton(
                  icon: FontAwesomeIcons.linkedin,
                  onPressed: () => _launchURL(
                    'https://linkedin.com/in/jason-permana-526ab82b7',
                  ),
                ),
                _SocialButton(
                  icon: FontAwesomeIcons.envelope,
                  onPressed: () {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'permanajason03@gmail.com',
                      query: 'subject=Inquiry from Product Classifier App',
                    );
                    _launchURL(emailLaunchUri.toString());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return isLandscape
        ? cardContent
        : Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: cardContent,
            ),
          );
  }
}

// Helper Widget for Connect with Me Buttons
class _SocialButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _SocialButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: FaIcon(icon),
      iconSize: 28.0,
      color: Colors.grey[800],
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      tooltip: icon.toString(),
    );
  }
}
