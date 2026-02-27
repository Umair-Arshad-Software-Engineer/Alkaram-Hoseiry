import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────
class _C {
  static const bgPrimary     = Color(0xFFF8FAFC);
  static const bgCard        = Color(0xFFFFFFFF);
  static const accentOrange  = Color(0xFFFF8A65);
  static const accentAmber   = Color(0xFFFFB74D);
  static const accentTeal    = Color(0xFF26A69A);
  static const accentGreen   = Color(0xFF66BB6A);
  static const accentPurple  = Color(0xFFAB47BC);
  static const accentBlue    = Color(0xFF42A5F5);
  static const accentRed     = Color(0xFFEF5350);
  static const textPrimary   = Color(0xFF2C3E50);
  static const textSecondary = Color(0xFF7F8C8D);
  static const border        = Color(0xFFE2E8F0);
  static const shadow        = Color(0x1A000000);
}

// ─────────────────────────────────────────────────────────────
//  Item Model — only name, description, imageId
// ─────────────────────────────────────────────────────────────
class Item {
  final String   id;
  final String   name;
  final String   description;
  final String   imageId;   // key in item_images node
  final DateTime createdAt;

  Item({
    required this.id,
    required this.name,
    required this.description,
    required this.imageId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'name':        name,
    'description': description,
    'imageId':     imageId,
    'createdAt':   createdAt.toIso8601String(),
  };

  factory Item.fromMap(String id, Map<String, dynamic> map) => Item(
    id:          id,
    name:        map['name']        ?? '',
    description: map['description'] ?? '',
    imageId:     map['imageId']     ?? '',
    createdAt:   DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────
//  Item Management Page
// ─────────────────────────────────────────────────────────────
class ItemManagementPage extends StatefulWidget {
  const ItemManagementPage({super.key});

  @override
  State<ItemManagementPage> createState() => _ItemManagementPageState();
}

class _ItemManagementPageState extends State<ItemManagementPage>
    with SingleTickerProviderStateMixin {

  final _itemsRef  = FirebaseDatabase.instance.ref('items');
  final _imagesRef = FirebaseDatabase.instance.ref('item_images');

  // All items stored locally
  List<Item>            _allItems     = [];
  List<Item>            _filtered     = [];
  List<Item>            _displayedItems = []; // Paginated items for display
  Map<String, String>   _imageCache  = {}; // imageId → base64 (persists)
  bool                  _isLoading   = true;
  bool                  _isLoadingMore = false;
  bool                  _hasMoreItems = true;
  String                _searchQuery = '';

  // Pagination
  static const int _pageSize = 10;
  int _currentPage = 0;

  final _searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 50));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _scrollController.addListener(_onScroll);

    // ✅ Auto-fetch on open
    _fetchItemsFromFirebase();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Fetch items from Firebase ──────────────────────────────
  Future<void> _fetchItemsFromFirebase() async {
    setState(() {
      _isLoading = true;
      _allItems = [];
      _filtered = [];
      _displayedItems = [];
      _currentPage = 0;
      _hasMoreItems = true;
    });

    try {
      final snapshot = await _itemsRef.get();

      if (!mounted) return;

      if (snapshot.value == null) {
        setState(() {
          _isLoading = false;
          _hasMoreItems = false;
        });
        _fadeCtrl.forward();
        return;
      }

      final data = snapshot.value;
      if (data is! Map) {
        setState(() {
          _isLoading = false;
          _hasMoreItems = false;
        });
        _fadeCtrl.forward();
        return;
      }

      final items = <Item>[];
      for (final entry in data.entries) {
        try {
          items.add(Item.fromMap(
            entry.key.toString(),
            Map<String, dynamic>.from(entry.value as Map),
          ));
        } catch (_) {}
      }

      items.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _allItems = items;
        _filtered = _applyFilter(items);
        _loadNextPage(); // Load first page
        _isLoading = false;
      });

      _fadeCtrl.forward();

      // Fetch images for items in current page only
      _fetchImagesForCurrentPage();

    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasMoreItems = false;
      });
      _snack('Error fetching items: $e', color: _C.accentRed);
    }
  }

  // ── Fetch images only for displayed items ──────────────────
  Future<void> _fetchImagesForCurrentPage() async {
    for (final item in _displayedItems) {
      if (item.imageId.isNotEmpty && !_imageCache.containsKey(item.imageId)) {
        await _fetchImage(item.imageId);
      }
    }
  }

  // ── Fetch image from separate node ──────────────────────────
  Future<void> _fetchImage(String imageId) async {
    try {
      final snap = await _imagesRef.child(imageId).child('data').get();
      if (snap.value != null && mounted) {
        setState(() {
          _imageCache[imageId] = snap.value.toString();
        });
      }
    } catch (_) {}
  }

  // ── Pagination methods ─────────────────────────────────────
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (!_hasMoreItems || _isLoadingMore) return;
    _loadNextPage();
  }

  void _loadNextPage() {
    final startIndex = _currentPage * _pageSize;
    final endIndex = startIndex + _pageSize;

    if (startIndex >= _filtered.length) {
      setState(() {
        _hasMoreItems = false;
        _isLoadingMore = false;
      });
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    // Add next page of items
    final nextItems = _filtered.sublist(
        startIndex,
        endIndex < _filtered.length ? endIndex : _filtered.length
    );

    _displayedItems.addAll(nextItems);
    _currentPage++;

    setState(() {
      _isLoadingMore = false;
      _hasMoreItems = endIndex < _filtered.length;
    });

    // Fetch images for new items
    for (final item in nextItems) {
      if (item.imageId.isNotEmpty && !_imageCache.containsKey(item.imageId)) {
        _fetchImage(item.imageId);
      }
    }
  }

  void _resetPagination() {
    setState(() {
      _currentPage = 0;
      _displayedItems = [];
      _hasMoreItems = true;
    });
    _loadNextPage();
  }

  // ── Filter ──────────────────────────────────────────────────
  List<Item> _applyFilter(List<Item> source) {
    if (_searchQuery.isEmpty) return source;
    return source.where((item) =>
    item.name.toLowerCase().contains(_searchQuery) ||
        item.description.toLowerCase().contains(_searchQuery)).toList();
  }

  void _onSearch(String q) {
    setState(() {
      _searchQuery = q.toLowerCase();
      _filtered = _applyFilter(_allItems);
    });
    _resetPagination();
  }

  // ── Image helpers ────────────────────────────────────────────
  Future<String?> _pickAndCompressImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Source',
            style: TextStyle(color: _C.textPrimary, fontWeight: FontWeight.w600)),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _srcBtn(Icons.camera_alt,    'Camera',  ImageSource.camera),
            _srcBtn(Icons.photo_library, 'Gallery', ImageSource.gallery),
          ],
        ),
      ),
    );
    if (source == null) return null;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    return base64Encode(bytes);
  }

  Widget _srcBtn(IconData icon, String label, ImageSource src) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, src),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.accentOrange.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _C.accentOrange, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(
            color: _C.textSecondary, fontSize: 12)),
      ]),
    );
  }

  // ── Save / delete image node ─────────────────────────────────
  Future<String> _saveImage(String base64Data) async {
    final ref = _imagesRef.push();
    await ref.set({'data': base64Data, 'createdAt': DateTime.now().toIso8601String()});
    _imageCache[ref.key!] = base64Data;
    return ref.key!;
  }

  Future<void> _deleteImage(String imageId) async {
    if (imageId.isEmpty) return;
    await _imagesRef.child(imageId).remove();
    _imageCache.remove(imageId);
  }

  // ── Add / Edit dialog ────────────────────────────────────────
  Future<void> _showItemDialog({Item? item}) async {
    final isEdit   = item != null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    String? base64Preview = item?.imageId.isNotEmpty == true
        ? _imageCache[item!.imageId]
        : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: _C.bgCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // ── Header ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.accentOrange, _C.accentAmber],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                ),
                child: Row(children: [
                  const Icon(Icons.inventory_2, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Edit Item' : 'Add New Item',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),

              // ── Form ────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [

                    // Image picker
                    GestureDetector(
                      onTap: () async {
                        final b64 = await _pickAndCompressImage();
                        if (b64 != null) setS(() => base64Preview = b64);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: _C.accentOrange.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: base64Preview != null
                                ? _C.accentOrange : _C.border,
                            width: 2,
                          ),
                        ),
                        child: base64Preview != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(fit: StackFit.expand, children: [
                            Image.memory(
                                base64Decode(base64Preview!),
                                fit: BoxFit.cover),
                            Positioned(
                              bottom: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit,
                                        color: Colors.white, size: 13),
                                    SizedBox(width: 4),
                                    Text('Change',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        )
                            : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: _C.accentOrange.withOpacity(0.5),
                                size: 42),
                            const SizedBox(height: 10),
                            const Text('Tap to add image',
                                style: TextStyle(
                                    color: _C.textSecondary, fontSize: 14)),
                            const SizedBox(height: 4),
                            const Text('Auto-compressed for storage',
                                style: TextStyle(
                                    color: _C.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name field
                    _field(nameCtrl, 'Item Name', Icons.label_outline),
                    const SizedBox(height: 12),

                    // Description field
                    _field(descCtrl, 'Description (optional)',
                        Icons.description_outlined, maxLines: 3),
                  ]),
                ),
              ),

              // ── Actions ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _C.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: _C.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.accentOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          _snack('Item name is required',
                              color: _C.accentRed);
                          return;
                        }
                        Navigator.pop(ctx);
                        _showSavingOverlay();

                        try {
                          String imageId = item?.imageId ?? '';

                          // If a new image was picked, replace old
                          if (base64Preview != null &&
                              base64Preview != _imageCache[item?.imageId]) {
                            if (imageId.isNotEmpty) await _deleteImage(imageId);
                            imageId = await _saveImage(base64Preview!);
                          }

                          final newItem = Item(
                            id:          isEdit ? item!.id : '',
                            name:        nameCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            imageId:     imageId,
                            createdAt:   item?.createdAt ?? DateTime.now(),
                          );

                          if (isEdit) {
                            await _itemsRef.child(item!.id)
                                .update(newItem.toMap());

                            // Update local cache
                            final index = _allItems.indexWhere((i) => i.id == item.id);
                            if (index != -1) {
                              _allItems[index] = newItem;
                            }
                          } else {
                            final ref = await _itemsRef.push();
                            await ref.set(newItem.toMap());

                            // Add to local cache
                            _allItems.add(Item(
                              id: ref.key!,
                              name: newItem.name,
                              description: newItem.description,
                              imageId: newItem.imageId,
                              createdAt: newItem.createdAt,
                            ));
                          }

                          // Re-sort and filter
                          _allItems.sort((a, b) => a.name.compareTo(b.name));
                          _filtered = _applyFilter(_allItems);
                          _resetPagination();

                          _hideOverlay();
                          _snack(isEdit ? 'Item updated!' : 'Item added!',
                              color: _C.accentGreen);
                        } catch (e) {
                          _hideOverlay();
                          _snack('Error: $e', color: _C.accentRed);
                        }
                      },
                      child: Text(
                        isEdit ? 'Save Changes' : 'Add Item',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Delete item ──────────────────────────────────────────────
  Future<void> _deleteItem(Item item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Item',
            style: TextStyle(
                color: _C.textPrimary, fontWeight: FontWeight.w600)),
        content: Text('Delete "${item.name}"? '
            'Its image will also be removed.',
            style: const TextStyle(color: _C.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: _C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: _C.accentRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _deleteImage(item.imageId);
      await _itemsRef.child(item.id).remove();

      // Remove from local cache
      _allItems.removeWhere((i) => i.id == item.id);
      _filtered = _applyFilter(_allItems);
      _resetPagination();

      _snack('Item deleted', color: _C.accentRed);
    } catch (e) {
      _snack('Error: $e', color: _C.accentRed);
    }
  }

  // ── Full-screen image viewer ─────────────────────────────────
  void _viewImage(String base64) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(child: Image.memory(base64Decode(base64))),
          ),
          Positioned(
            top: 16, right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Overlay / snack ──────────────────────────────────────────
  OverlayEntry? _overlayEntry;

  void _showSavingOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Container(
          color: Colors.black26,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _C.bgCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: _C.accentOrange),
                SizedBox(height: 12),
                Text('Saving...', style: TextStyle(color: _C.textPrimary)),
              ]),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _snack(String msg, {Color color = _C.accentGreen}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: _C.textPrimary)),
      backgroundColor: _C.bgCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withOpacity(0.5)),
      ),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Form field helper ────────────────────────────────────────
  Widget _field(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        int maxLines = 1,
      }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: _C.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _C.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _C.accentOrange, size: 18),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        filled: true,
        fillColor: _C.bgPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.accentOrange, width: 1.5),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgPrimary,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: _C.accentOrange))
          : FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          _buildSearchBar(),
          _buildCountBar(),
          Expanded(child: _buildGrid()),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemDialog(),
        backgroundColor: _C.accentOrange,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const Text('Add Item',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.accentOrange, _C.accentAmber],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: const Text('Item Management'),
      titleTextStyle: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
      actions: [
        // Refresh button to fetch from Firebase
        IconButton(
          icon: const Icon(Icons.sync),
          onPressed: _fetchItemsFromFirebase,
          tooltip: 'Fetch items from server',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        style: const TextStyle(color: _C.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: const TextStyle(color: _C.textSecondary),
          prefixIcon:
          const Icon(Icons.search, color: _C.accentOrange, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
              icon: const Icon(Icons.clear,
                  size: 18, color: _C.textSecondary),
              onPressed: () { _searchCtrl.clear(); _onSearch(''); })
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: _C.accentOrange, width: 1.5),
          ),
        ),
      ),
    );
  }

  // Simple total-items count bar
  Widget _buildCountBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _C.accentOrange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.accentOrange.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.inventory_2_outlined,
                color: _C.accentOrange, size: 16),
            const SizedBox(width: 6),
            Text(
              '${_filtered.length} item${_filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(
                  color: _C.accentOrange,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        const Spacer(),
        Text(
          'Showing ${_displayedItems.length} of ${_filtered.length}',
          style: const TextStyle(
            color: _C.textSecondary,
            fontSize: 12,
          ),
        ),
      ]),
    );
  }

  // ── Grid ─────────────────────────────────────────────────────
  Widget _buildGrid() {
    if (_displayedItems.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _C.accentOrange.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2_outlined,
                  size: 44, color: _C.accentOrange.withOpacity(0.4)),
            ),
            const SizedBox(height: 16),
            const Text('No items found',
                style: TextStyle(
                    color: _C.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text('Tap + to add your first item',
                style: TextStyle(color: _C.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: _displayedItems.length + (_hasMoreItems ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _displayedItems.length) {
          return _buildLoadingIndicator();
        }
        return _buildItemCard(_displayedItems[i]);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _C.accentOrange,
        ),
      ),
    );
  }

  // ── Item Card ─────────────────────────────────────────────────
  Widget _buildItemCard(Item item) {
    final imgB64 = _imageCache[item.imageId];

    return Container(
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(color: _C.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Image ────────────────────────────────────────────
          Expanded(
            flex: 6,
            child: GestureDetector(
              onTap: imgB64 != null ? () => _viewImage(imgB64) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: _C.accentOrange.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14)),
                ),
                child: Stack(children: [
                  // Image / spinner / placeholder
                  Center(
                    child: imgB64 != null
                        ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      child: SizedBox.expand(
                        child: Image.memory(
                          base64Decode(imgB64),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                        : item.imageId.isNotEmpty
                        ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _C.accentOrange)
                        : Icon(Icons.inventory_2_outlined,
                        size: 44,
                        color: _C.accentOrange.withOpacity(0.3)),
                  ),

                  // Edit / Delete buttons
                  Positioned(
                    top: 6, right: 6,
                    child: Column(children: [
                      _actionBtn(
                        icon: Icons.edit_outlined,
                        color: _C.accentBlue,
                        onTap: () => _showItemDialog(item: item),
                      ),
                      const SizedBox(height: 4),
                      _actionBtn(
                        icon: Icons.delete_outline,
                        color: _C.accentRed,
                        onTap: () => _deleteItem(item),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

          // ── Info ─────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: _C.shadow, blurRadius: 3)],
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}