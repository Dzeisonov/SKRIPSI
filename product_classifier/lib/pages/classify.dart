// lib/classify.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../ml/infer_client.dart';
import 'package:permission_handler/permission_handler.dart';

/// --- ProductInfo class ---
class ProductInfo {
  final String name;
  final String category;
  final String description;
  final List<String> advantages;
  final String bahan;
  final String imagePath;

  ProductInfo({
    required this.name,
    required this.category,
    required this.description,
    required this.advantages,
    required this.bahan,
    required this.imagePath,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      name: json['name'] ?? 'N/A',
      category: json['category'] ?? 'N/A',
      description: json['description'] ?? 'No description available.',
      advantages: List<String>.from(json['advantages'] ?? []),
      bahan: json['bahan'] ?? 'N/A',
      imagePath: json['imagePath'] ?? 'assets/images/placeholder.jpg',
    );
  }
}

/// --- Model kecil untuk Top-K item yang di-resolve ke database ---
class PredictedCandidate {
  final String label; // label asli dari model
  final double confidence; // 0..1
  final ProductInfo? product; // null jika tidak ditemukan di DB
  PredictedCandidate({
    required this.label,
    required this.confidence,
    required this.product,
  });
}

/// --- ProductClassificationPage ---
class ProductClassificationPage extends StatefulWidget {
  const ProductClassificationPage({super.key});

  @override
  State<ProductClassificationPage> createState() =>
      _ProductClassificationPageState();
}

class _ProductClassificationPageState extends State<ProductClassificationPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  File? _imageFile;
  img.Image? _imageInput;
  bool _isLoading = true;
  bool _isDebugging = false;
  bool _isInferencing = false;

  // --- PERUBAHAN 1: Menyimpan list kandidat, bukan hanya Top-1 ---
  List<PredictedCandidate>? _lastCandidates;

  // isolated inference client
  final InferClient _infer = InferClient(
    // modelAsset: 'assets/model.tflite',
    // labelsAsset: 'assets/labels.txt',
    modelAsset: 'assets/model_20.tflite',
    labelsAsset: 'assets/labels_20.txt',
    inputSize: 224,
  );

  late Map<String, ProductInfo> _productDatabase;

  final buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFFFC107),
    foregroundColor: Colors.black,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  );

  @override
  void initState() {
    super.initState();
    _loadData(); // start isolate + load product DB
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([_infer.start(), _loadProductDatabase()]);
    } catch (e) {
      debugPrint("Error loading assets: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Init error: $e',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFFFFC107),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProductDatabase() async {
    final String jsonString = await rootBundle.loadString(
      'assets/data/products.json',
    );
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    _productDatabase = jsonMap.map((key, value) {
      return MapEntry(key, ProductInfo.fromJson(value as Map<String, dynamic>));
    });
  }

  // --- Utils ---
  String _normalizeLabel(String raw) => raw.trim().replaceAll(' ', '_');

  // --- Inference helpers (Top-K) ---
  Future<void> _runInference(Uint8List bytes, img.Image imageInput) async {
    setState(() => _isInferencing = true);

    try {
      // Pakai Top-K (misal K=3)
      final results = await _infer.classifyTopK(bytes, k: 3);

      // Build list kandidat untuk dialog (tiap kandidat di-bind ke DB)
      final candidates = results.map((r) {
        final key = _normalizeLabel(r.label);
        final product = _productDatabase[key];
        return PredictedCandidate(
          label: r.label,
          confidence: r.confidence,
          product: product,
        );
      }).toList();

      // --- PERUBAHAN 2: Simpan semua kandidat ke state ---
      setState(() {
        _lastCandidates = candidates;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => ResultDialog(
            userInputImage: imageInput,
            candidates: candidates,
            initialIndex: 0,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error running model: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error running model: $e',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFFFFC107),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInferencing = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // --- Step 1: Request permission ---
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();

      if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin kamera ditolak.',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Color(0xFFFFC107),
            ),
          );
        }
        return;
      } else if (status.isPermanentlyDenied) {
        if (!mounted) return;

        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Izin Diperlukan'),
            content: const Text(
              'Aplikasi membutuhkan akses kamera untuk mengambil gambar.\n'
              'Apakah Anda ingin membuka pengaturan untuk memberikan izin?',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Buka Pengaturan'),
              ),
            ],
          ),
        );

        if (shouldOpen == true) {
          await openAppSettings();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin kamera ditolak.',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Color(0xFFFFC107),
            ),
          );
        }

        return;
      }
    }

    // --- Step 2: Pick image from camera or gallery ---
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);
    final bytes = await imageFile.readAsBytes();
    final imageInput = img.decodeImage(bytes);

    if (imageInput == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal membaca gambar.',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Color(0xFFFFC107),
          ),
        );
      }
      return;
    }

    // --- Step 3: Proceed with inference ---
    setState(() {
      _imageFile = imageFile;
      _imageInput = imageInput;
    });

    await _runInference(bytes, imageInput);
  }

  Future<void> _selectPreset(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final imageInput = img.decodeImage(bytes);

      if (imageInput == null) return;

      setState(() {
        _imageFile = null;
        _imageInput = imageInput;
      });

      await _runInference(bytes, imageInput);
    } catch (e) {
      debugPrint('Error loading preset image: $e');
    }
  }

  Widget _buildImageDisplay() {
    return AnimationLimiter(
      child: AnimationConfiguration.synchronized(
        duration: const Duration(milliseconds: 600),
        child: SlideAnimation(
          verticalOffset: 50.0,
          child: FadeInAnimation(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400, width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : _imageInput != null
                    ? Image.memory(
                        Uint8List.fromList(img.encodeJpg(_imageInput!)),
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: Text(
                          'Pilih Gambar',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonControls({bool isDebugging = false}) {
    final presetButtons = [
      ElevatedButton(
        onPressed: () => _selectPreset('assets/images/BM.jpg'),
        child: const Text('BM.jpg'),
        style: buttonStyle,
      ),
      ElevatedButton(
        onPressed: () => _selectPreset('assets/images/BL.jpg'),
        child: const Text('BL.jpg'),
        style: buttonStyle,
      ),
      ElevatedButton(
        onPressed: () => _selectPreset('assets/images/A_801_T.jpg'),
        child: const Text('A 801 T.jpg'),
        style: buttonStyle,
      ),
    ];

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // === Judul sekarang ikut teranimasi ===
          AnimationLimiter(
            child: AnimationConfiguration.synchronized(
              duration: const Duration(milliseconds: 450),
              child: SlideAnimation(
                verticalOffset: 24,
                child: FadeInAnimation(
                  child: const Text(
                    'Pilih gambar untuk diklasifikasi',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Tombol Camera / Gallery (sudah teranimasi)
          AnimationLimiter(
            child: Wrap(
              spacing: 15,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: List.generate(2, (index) {
                final button = index == 0
                    ? ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          backgroundColor: const Color(0xFFFFC107),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          backgroundColor: const Color(0xFFFFC107),
                        ),
                      );

                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 400),
                  child: SlideAnimation(
                    verticalOffset: 30,
                    child: FadeInAnimation(child: button),
                  ),
                );
              }),
            ),
          ),

          if (isDebugging) ...[
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),
            AnimationLimiter(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: List.generate(presetButtons.length, (index) {
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 400),
                    child: ScaleAnimation(
                      child: FadeInAnimation(child: presetButtons[index]),
                    ),
                  );
                }),
              ),
            ),
          ] else ...[
            const SizedBox(height: 30),
            AnimationLimiter(
              child: AnimationConfiguration.staggeredList(
                position: 0,
                duration: const Duration(milliseconds: 500),
                child: SlideAnimation(
                  verticalOffset: 40.0,
                  child: FadeInAnimation(
                    // --- PERUBAHAN 3: Kirim list kandidat ke ResultPanel ---
                    child: ResultPanel(candidates: _lastCandidates),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // penting untuk keep-alive
    return Scaffold(
      backgroundColor: Colors.white,
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Stack(
            children: [
              CustomPaint(
                size: Size(MediaQuery.of(context).size.width, double.infinity),
                painter: CurvedBackgroundPainter(orientation: orientation),
              ),
              SafeArea(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: (orientation == Orientation.portrait)
                                  ? Colors.white
                                  : Colors.blue.shade700,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Memuat model dan data produk...",
                              style: TextStyle(
                                color: (orientation == Orientation.portrait)
                                    ? Colors.white
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: (orientation == Orientation.portrait)
                            ? _buildPortraitLayout(context)
                            : _buildLandscapeLayout(context),
                      ),
              ),
              if (_isInferencing)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text(
                          "Menganalisis gambar...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 20),
          child: Text(
            'Klasifikasi Produk',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: AspectRatio(aspectRatio: 1.0, child: _buildImageDisplay()),
        ),
        const SizedBox(height: 40),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: _buildButtonControls(isDebugging: _isDebugging),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Klasifikasi Produk',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: _buildImageDisplay(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: _buildButtonControls(isDebugging: _isDebugging),
          ),
        ),
      ],
    );
  }
}

/// --- ResultDialog (Stateful, dropdown di samping nama & re-animate) ---
class ResultDialog extends StatefulWidget {
  final img.Image userInputImage;
  final List<PredictedCandidate> candidates;
  final int initialIndex;

  const ResultDialog({
    super.key,
    required this.userInputImage,
    required this.candidates,
    this.initialIndex = 0,
  });

  @override
  State<ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<ResultDialog> {
  late int _selected; // index kandidat aktif
  late final Widget _userImageWidget;

  PredictedCandidate get current => widget.candidates[_selected];

  String _percent(double p) => '${(p * 100).toStringAsFixed(1)}%';
  Color _barColor(double p) {
    if (p >= 0.90) return Colors.green;
    if (p >= 0.70) return Colors.orange;
    return Colors.red;
  }

  Color _textColor(double p) {
    if (p >= 0.90) return const Color(0xFF1B5E20); // green700
    if (p >= 0.70) return const Color(0xFFEF6C00); // orange800-ish
    return const Color(0xFFB71C1C); // red900
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex.clamp(0, widget.candidates.length - 1);

    _userImageWidget = Image.memory(
      Uint8List.fromList(img.encodeJpg(widget.userInputImage)),
      fit: BoxFit.cover,
      gaplessPlayback: true, // Prevents flicker if the image provider changes
    );
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      title: const Center(
        child: Text(
          'Hasil Inferensi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: orientation == Orientation.landscape
              ? _buildLandscapeContent(context)
              : _buildPortraitContent(context),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'DONE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameRow(BuildContext context) {
    final name = current.product?.name ?? current.label;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Text(
              name,
              key: ValueKey('title_${_selected}'),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.left,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Dropdown compact di kanan nama
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: _TopKDropdownCompact(
            candidates: widget.candidates,
            selectedIndex: _selected,
            onChanged: (i) => setState(() => _selected = i),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBlock(BuildContext context) {
    final p = current.product;
    final bar = _barColor(current.confidence);
    final txt = _textColor(current.confidence);

    final headerChildren = <Widget>[
      // Nama + dropdown (tetap di header konten)
      _buildNameRow(context),
      const SizedBox(height: 8),
      if ((p?.category ?? '').isNotEmpty) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            label: Text(
              p!.category,
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: Theme.of(
              context,
            ).primaryColorLight.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        const SizedBox(height: 8),
      ],
      const Text(
        'Confidence',
        style: TextStyle(
          fontSize: 14,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: current.confidence,
                backgroundColor: Colors.grey.shade300,
                color: bar,
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _percent(current.confidence),
            style: TextStyle(
              fontSize: 16,
              color: txt,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ];

    return AnimationLimiter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(headerChildren.length, (i) {
          return AnimationConfiguration.staggeredList(
            position: i,
            delay: const Duration(milliseconds: 60),
            duration: const Duration(milliseconds: 300),
            child: SlideAnimation(
              verticalOffset: 16,
              child: FadeInAnimation(child: headerChildren[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBodyBlock(BuildContext context) {
    final p = current.product;

    final bodyChildren = <Widget>[
      Text(
        p?.description ?? 'No description available for this label.',
        textAlign: TextAlign.justify,
        style: const TextStyle(fontSize: 15, color: Colors.black, height: 1.4),
      ),
      if ((p?.advantages ?? []).isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          'Keunggulan:',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final adv in p!.advantages)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(adv)),
              ],
            ),
          ),
      ],
      if ((p?.bahan ?? '').isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          'Bahan:',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.layers_outlined, color: Colors.grey.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(p!.bahan)),
          ],
        ),
      ],
    ];

    return AnimationLimiter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(bodyChildren.length, (i) {
          return AnimationConfiguration.staggeredList(
            position: i,
            delay: const Duration(milliseconds: 60),
            duration: const Duration(milliseconds: 300),
            child: SlideAnimation(
              verticalOffset: 16,
              child: FadeInAnimation(child: bodyChildren[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLandscapeContent(BuildContext context) {
    final p = current.product;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ImageCard(
                      title: 'Gambar Anda',
                      imageWidget: _userImageWidget,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ImageCard(
                      title: 'Gambar Produk',
                      imageWidget: (p?.imagePath != null)
                          ? Image.asset(p!.imagePath, fit: BoxFit.cover)
                          : const _NoImage(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),

            Expanded(
              flex: 3,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Column(
                  key: ValueKey(_selected), // Important!
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildHeaderBlock(context)],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Column(
            key: ValueKey(_selected),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildBodyBlock(context)],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitContent(BuildContext context) {
    final p = current.product;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ImageCard(
                title: 'Gambar Anda',
                imageWidget: _userImageWidget,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ImageCard(
                title: 'Gambar Produk',
                imageWidget: (p?.imagePath != null)
                    ? Image.asset(p!.imagePath, fit: BoxFit.cover)
                    : const _NoImage(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Column(
            key: ValueKey(_selected),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderBlock(context),
              const SizedBox(height: 16),
              _buildBodyBlock(context),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopKDropdownCompact extends StatelessWidget {
  final List<PredictedCandidate> candidates;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TopKDropdownCompact({
    required this.candidates,
    required this.selectedIndex,
    required this.onChanged,
  });

  String _percent(double p) => '${(p * 100).toStringAsFixed(1)}%';

  // Helper untuk warna TEKS (gelap & kontras)
  Color _confidenceTextColor(double p) {
    if (p >= 0.90) return Colors.green.shade800;
    if (p >= 0.70) return Colors.amber.shade900;
    return Colors.red.shade800;
  }

  // --- HELPER BARU ---
  // Helper untuk warna BACKGROUND BUTTON (terang & lembut)
  Color _confidenceBackgroundColor(double p) {
    if (p >= 0.90) return Colors.green.shade100;
    if (p >= 0.70) return Colors.amber.shade100;
    return Colors.red.shade100;
  }

  @override
  Widget build(BuildContext context) {
    // Ambil confidence dari item yang sedang terpilih
    final double currentConfidence = candidates[selectedIndex].confidence;

    // Tentukan warna background dan teks berdasarkan confidence
    final Color backgroundColor = _confidenceBackgroundColor(currentConfidence);
    final Color textColor = _confidenceTextColor(currentConfidence);

    // --- PERUBAHAN UTAMA ADA DI CONTAINER INI ---
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        // Terapkan warna background dinamis di sini
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        // Kita bisa sedikit menggelapkan border agar serasi
        border: Border.all(color: textColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isDense: true,
          value: selectedIndex,
          // Ikon juga bisa disesuaikan warnanya
          icon: Icon(Icons.keyboard_arrow_down, size: 20, color: textColor),

          borderRadius: BorderRadius.circular(12),
          elevation: 4,
          dropdownColor: Colors.white,
          menuMaxHeight: 240.0,

          items: List.generate(candidates.length, (i) {
            final c = candidates[i];
            final isSelected = i == selectedIndex;

            return DropdownMenuItem(
              value: i,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _confidenceTextColor(c.confidence),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.product?.name ?? c.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _percent(c.confidence),
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _confidenceTextColor(c.confidence),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Terapkan warna teks dinamis di sini
          selectedItemBuilder: (context) {
            return candidates.map((c) {
              return Center(
                child: Text(
                  '${c.product?.name ?? c.label} • ${_percent(c.confidence)}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList();
          },

          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.05),
      child: const Center(
        child: Text(
          'No product image',
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final String title;
  final Widget imageWidget;

  const _ImageCard({required this.title, required this.imageWidget});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageWidget,
            ),
          ),
        ),
      ],
    );
  }
}

/// --- Orientation-aware Curved Background ---
class CurvedBackgroundPainter extends CustomPainter {
  final Orientation orientation;

  CurvedBackgroundPainter({required this.orientation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0055A5)
      ..style = PaintingStyle.fill;

    if (orientation == Orientation.portrait) {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(0, size.height * 0.4)
        ..quadraticBezierTo(
          size.width / 2,
          size.height * 0.5,
          size.width,
          size.height * 0.4,
        )
        ..lineTo(size.width, 0)
        ..close();
      canvas.drawPath(path, paint);
    } else {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * 0.4, 0)
        ..quadraticBezierTo(
          size.width * 0.49,
          size.height / 2,
          size.width * 0.4,
          size.height,
        )
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CurvedBackgroundPainter oldDelegate) {
    return oldDelegate.orientation != orientation;
  }
}

/// --- ResultPanel (ringkas di halaman utama, berfungsi sebagai dropdown) ---
class ResultPanel extends StatefulWidget {
  final List<PredictedCandidate>? candidates;

  const ResultPanel({this.candidates, super.key});

  @override
  State<ResultPanel> createState() => _ResultPanelState();
}

class _ResultPanelState extends State<ResultPanel> {
  int _selectedIndex = 0;

  // Reset pilihan ke item pertama setiap kali ada hasil inferensi baru
  @override
  void didUpdateWidget(covariant ResultPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.candidates != oldWidget.candidates) {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  // --- Helper warna & format ---
  String _percent(double p) => '${(p * 100).toStringAsFixed(1)}%';

  Color _barColor(double p) {
    if (p >= .90) return Colors.green;
    if (p >= .70) return Colors.orange;
    return Colors.red;
  }

  Color _textColor(double p) {
    if (p >= .90) return const Color(0xFF1B5E20);
    if (p >= .70) return const Color(0xFFEF6C00);
    return const Color(0xFFB71C1C);
  }

  @override
  Widget build(BuildContext context) {
    final currentCandidates = widget.candidates;

    if (currentCandidates == null || currentCandidates.isEmpty) {
      return _buildInitialView();
    }

    if (_selectedIndex >= currentCandidates.length) {
      _selectedIndex = 0;
    }
    final selected = currentCandidates[_selectedIndex];

    // --- PERUBAHAN UTAMA: Ganti PopupMenuButton dengan GestureDetector ---
    // Builder digunakan untuk mendapatkan context yang tepat dari widget di bawahnya
    return Builder(
      builder: (BuildContext builderContext) {
        return GestureDetector(
          // Panggil fungsi untuk menampilkan menu secara manual
          onTap: () {
            _showMenu(builderContext, currentCandidates);
          },
          // Tampilan panel tetap sama
          child: _buildResultDisplay(selected),
        );
      },
    );
  }

  /// Fungsi untuk menampilkan menu dropdown dengan posisi yang presisi
  void _showMenu(BuildContext context, List<PredictedCandidate> candidates) {
    // 1. Dapatkan RenderBox (info ukuran & posisi) dari widget yang ditekan
    final RenderBox button = context.findRenderObject()! as RenderBox;
    // 2. Dapatkan RenderBox dari Overlay (seluruh layar)
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    // 3. Hitung posisi menu agar muncul dari pojok kanan bawah 'button'
    final RelativeRect position = RelativeRect.fromRect(
      // Buat sebuah kotak berukuran 0x0 di pojok kanan bawah button
      Rect.fromPoints(
        button.localToGlobal(
          button.size.topRight(Offset.zero),
          ancestor: overlay,
        ),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      // Relatif terhadap ukuran keseluruhan overlay
      Offset.zero & overlay.size,
    );

    // 4. Panggil fungsi global showMenu
    showMenu<int>(
      context: context,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: position, // Gunakan posisi yang sudah dihitung
      items: List.generate(candidates.length, (i) {
        final c = candidates[i];
        final isSelected = i == _selectedIndex;

        return PopupMenuItem<int>(
          value: i,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _textColor(c.confidence),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  c.product?.name ?? c.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _percent(c.confidence),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: _textColor(c.confidence),
                ),
              ),
            ],
          ),
        );
      }),
    ).then((int? newIndex) {
      // 5. Update state saat item baru dipilih
      if (newIndex != null) {
        setState(() {
          _selectedIndex = newIndex;
        });
      }
    });
  }

  /// Widget untuk tampilan "Belum ada gambar"
  Widget _buildInitialView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.info_outline, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'Belum ada gambar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Ambil foto atau pilih dari galeri untuk memulai klasifikasi',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }

  /// Widget untuk menampilkan hasil yang terpilih (sekarang menjadi child dari GestureDetector)
  Widget _buildResultDisplay(PredictedCandidate selected) {
    final confidence = selected.confidence;
    final name = selected.product?.name ?? selected.label;
    final textColor = _textColor(confidence);
    final barColor = _barColor(confidence);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hasil Terakhir',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.unfold_more, color: Colors.black54),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: confidence,
              color: barColor,
              backgroundColor: Colors.grey.shade300,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _percent(confidence),
            style: TextStyle(fontSize: 14, color: textColor),
          ),
        ],
      ),
    );
  }
}
