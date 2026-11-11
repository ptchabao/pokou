import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../l10n/app_localizations.dart';
import '../data/product_model.dart';
import 'marketplace_controller.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Le formulaire d'annonce — création et modification.
///
/// Sorti de `marketplace_screen.dart` parce qu'il a désormais DEUX appelants :
/// l'écran du marché et la page « Mon catalogue ». Tant qu'il y vivait en
/// privé, la seconde n'avait le choix qu'entre le recopier et renoncer.
///
/// Il ne écrit rien lui-même : il rend un [ProductDraft] à son appelant, qui
/// décide de créer ou de mettre à jour. C'est ce qui lui permet de servir les
/// deux écrans sans connaître ni l'un ni l'autre.

class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.description,
    required this.category,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.price,
    required this.currency,
    required this.imageMediaId,
    required this.galleryMediaIds,
  });

  final String name;
  final String description;
  final String category;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String price;
  final String currency;
  final int? imageMediaId;
  final List<int> galleryMediaIds;
}

class ProductEditor extends ConsumerStatefulWidget {
  const ProductEditor({this.product, this.onSubmit});

  /// Envoie l'annonce au serveur. Quand il est fourni, le formulaire RESTE
  /// ouvert pendant l'envoi et en cas d'échec : il fermait d'abord, puis
  /// envoyait — un refus du serveur faisait perdre tout ce qui avait été
  /// saisi, derrière un simple « Produit indisponible ».
  final Future<void> Function(ProductDraft draft)? onSubmit;

  final MarketplaceProduct? product;

  @override
  ConsumerState<ProductEditor> createState() => ProductEditorState();
}

class ProductEditorState extends ConsumerState<ProductEditor> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _currency;
  late final TextEditingController _category;
  late final TextEditingController _categoryDetail;
  late final TextEditingController _location;
  double? _latitude;
  double? _longitude;
  bool _fetchingLocation = false;

  MediaMeta? _mainImage;
  final List<MediaMeta> _gallery = [];

  bool _uploading = false;
  bool _saving = false;

  /// Les CODES envoyés au serveur (« XOF », « TELEPHONES »), tenus à part
  /// des champs affichés : un `DropdownMenu` écrit dans son contrôleur le
  /// LIBELLÉ de l'entrée choisie (« FCFA (XOF) », « Téléphones »). Tant que
  /// le formulaire relisait ce contrôleur, il envoyait le libellé — une
  /// devise que le serveur refuse, et une catégorie qui n'apparaît sous
  /// aucun filtre.
  late String _currencyCode;
  late String _categorySlug;

  static const _maxGallery = 8;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _price = TextEditingController(text: product?.price ?? '');
    // Catégories et devises viennent de l'administration, plus de la liste
    // écrite en dur dans l'application (voir `marketplaceConfigProvider`).
    final config = ref.read(marketplaceConfigProvider);
    final codesConnus = config.currencies.map((c) => c.code).toSet();
    _currencyCode = codesConnus.contains(product?.currency)
        ? product!.currency
        : config.defaultCurrency.code;
    _currency = TextEditingController();
    _category = TextEditingController();
    final slugsConnus = config.categories.map((c) => c.slug).toSet();
    final knownCategory = slugsConnus.contains(product?.category)
        ? product!.category
        : 'AUTRE';
    _categorySlug = knownCategory;
    _categoryDetail = TextEditingController(
      text: knownCategory == 'AUTRE' && product?.category != 'AUTRE'
          ? product?.category
          : '',
    );
    _location = TextEditingController(text: product?.location ?? '');
    _latitude = product?.latitude;
    _longitude = product?.longitude;
    _mainImage = product?.image;
    if (product != null) _gallery.addAll(product.gallery);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _currency.dispose();
    _category.dispose();
    _categoryDetail.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<ImageSource?> _askSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(L.of(context).profileGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt_outlined,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(L.of(context).profileCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<MediaMeta?> _pickAndUpload() async {
    final source = await _askSource();
    if (source == null) return null;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: ref.read(appSettingsProvider).imageUploadQuality,
    );
    if (picked == null) return null;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: bytes,
            filename: picked.name,
            mimeType: lookupMimeType(picked.name) ?? 'image/jpeg',
            messageType: 'IMAGE',
          );
      return MediaMeta(
        id: uploaded.id,
        mimeType: uploaded.mimeType,
        sizeBytes: uploaded.sizeBytes,
        originalFilename: picked.name,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).marketImageFailed)),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickMainImage() async {
    final media = await _pickAndUpload();
    if (media != null && mounted) setState(() => _mainImage = media);
  }

  Future<void> _addGalleryImage() async {
    if (_gallery.length >= _maxGallery) return;
    final media = await _pickAndUpload();
    if (media != null && mounted) setState(() => _gallery.add(media));
  }

  Future<void> _useMyGpsLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).marketLocationOff)),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).marketGpsDenied)));
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _location.text =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).marketGpsSaved)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).marketGpsFailed)));
      }
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  /// Le prix tel que le serveur l'attend : des chiffres, un point décimal.
  /// « 5 000 », « 5.000,50 » ou « 5000 F » se saisissent naturellement et
  /// étaient refusés en bloc. `null` : ce n'est pas un prix.
  static String? normalizePrice(String raw) {
    var text = raw.replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');
    text = text.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (text.isEmpty) return null;
    final lastSeparator = text.lastIndexOf(RegExp(r'[.,]'));
    if (lastSeparator != -1) {
      final decimals = text.length - lastSeparator - 1;
      final whole = text
          .substring(0, lastSeparator)
          .replaceAll(RegExp(r'[.,]'), '');
      final fraction = text.substring(lastSeparator + 1);
      // Un séparateur suivi de trois chiffres est un séparateur de
      // milliers (« 5.000 »), pas une décimale.
      text = decimals == 3 || decimals == 0
          ? '$whole$fraction'
          : '$whole.${fraction.length > 2 ? fraction.substring(0, 2) : fraction}';
    }
    final value = double.tryParse(text);
    if (value == null || value < 0 || value >= 10000000000) return null;
    return text;
  }

  /// La position, si elle s'obtient VITE. Elle sert à trier « près de chez
  /// toi » ; elle ne doit jamais retenir une publication. Sans limite de
  /// temps, un téléphone sans signal GPS laissait le bouton « Enregistrer »
  /// sans effet apparent.
  Future<void> _attachPositionIfQuick() async {
    if (_latitude != null && _longitude != null) return;
    try {
      await () async {
        if (!await Geolocator.isLocationServiceEnabled()) return;
        final permission = await Geolocator.checkPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          return;
        }
        final position =
            await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 4),
              ),
            );
        _latitude = position.latitude;
        _longitude = position.longitude;
      }().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Pas de position : l'annonce part sans.
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final price = normalizePrice(_price.text);
    if (_name.text.trim().isEmpty || _price.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).marketNameAndPrice)));
      return;
    }
    if (price == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).marketPriceInvalid)));
      return;
    }
    setState(() => _saving = true);
    await _attachPositionIfQuick();
    if (!mounted) return;
    final detail = _categoryDetail.text.trim();
    final draft = ProductDraft(
      name: _name.text.trim(),
      description: _description.text.trim(),
      category: _categorySlug == 'AUTRE' && detail.isNotEmpty
          ? detail.toUpperCase()
          : _categorySlug,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      latitude: _latitude ?? widget.product?.latitude,
      longitude: _longitude ?? widget.product?.longitude,
      price: price,
      currency: _currencyCode,
      imageMediaId: _mainImage?.id,
      galleryMediaIds: [for (final media in _gallery) media.id],
    );
    final submit = widget.onSubmit;
    if (submit == null) {
      Navigator.pop(context, draft);
      return;
    }
    try {
      await submit(draft);
      if (mounted) Navigator.pop(context, draft);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      // Le message du serveur quand il en donne un lisible (médicament
      // refusé, devise fermée) ; sinon, dire que rien n'est perdu.
      final message =
          error is ApiException &&
              error.statusCode < 500 &&
              !error.message.startsWith('[')
          ? error.message
          : L.of(context).marketPublishFailed;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(marketplaceConfigProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.product == null
              ? L.of(context).marketAddProduct
              : L.of(context).marketEditProduct,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            L.of(context).marketMainPhoto,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            L.of(context).marketMainPhotoHint,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _MainImagePicker(
            image: _mainImage,
            busy: _uploading,
            onPick: _uploading ? null : _pickMainImage,
            onRemove: _mainImage == null
                ? null
                : () => setState(() => _mainImage = null),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                L.of(context).marketOtherPhotos,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Text(
                '${_gallery.length}/$_maxGallery',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _GalleryStrip(
            images: _gallery,
            canAdd: !_uploading && _gallery.length < _maxGallery,
            onAdd: _addGalleryImage,
            onRemove: (index) => setState(() => _gallery.removeAt(index)),
          ),
          const SizedBox(height: 20),
          TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
            controller: _name,
            decoration: InputDecoration(labelText: L.of(context).marketName),
          ),
          TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
            controller: _description,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: L.of(context).marketDescription,
            ),
          ),
          TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: L.of(context).marketPrice),
          ),
          // ── La devise se CHOISIT ──────────────────────────────────
          //
          // C'était un champ de texte libre. « XOF », « FCFA », « fcfa » et
          // « CFA » désignaient la même monnaie sans jamais se comparer, et
          // rien n'empêchait de publier un prix en « BTC ». La liste vient
          // de l'administration, et le serveur refuse désormais ce qui n'y
          // est pas.
          DropdownMenu<String>(
            controller: _currency,
            initialSelection: _currencyCode,
            label: Text(L.of(context).marketCurrency),
            dropdownMenuEntries: [
              for (final devise in config.currencies)
                DropdownMenuEntry(
                  value: devise.code,
                  label: devise.label == devise.code
                      ? devise.code
                      : '${devise.label} (${devise.code})',
                ),
            ],
            onSelected: (value) => setState(
              () => _currencyCode = value ?? config.defaultCurrency.code,
            ),
          ),
          DropdownMenu<String>(
            controller: _category,
            initialSelection: _categorySlug,
            enableSearch: true,
            label: Text(L.of(context).marketCategory),
            dropdownMenuEntries: [
              for (final categorie in config.categories)
                DropdownMenuEntry(
                  value: categorie.slug,
                  label: categorie.label,
                ),
            ],
            onSelected: (value) =>
                setState(() => _categorySlug = value ?? 'AUTRE'),
          ),
          if (_categorySlug == 'AUTRE')
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: _categoryDetail,
              decoration: InputDecoration(
                labelText: L.of(context).marketSpecifyCategory,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                  controller: _location,
                  decoration: InputDecoration(
                    labelText: L.of(context).marketCityOrArea,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _fetchingLocation ? null : _useMyGpsLocation,
                tooltip: L.of(context).marketUseGps,
                icon: _fetchingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accentPrimaryDark.withOpacity(0.1),
                  foregroundColor: AppColors.accentPrimaryDark,
                ),
              ),
            ],
          ),
          if (_latitude != null && _longitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                L
                    .of(context)
                    .marketGpsCoords(
                      _latitude!.toStringAsFixed(4),
                      _longitude!.toStringAsFixed(4),
                    ),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _uploading || _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _uploading
                        ? L.of(context).marketUploadingPhoto
                        : L.of(context).actionSave,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MainImagePicker extends ConsumerWidget {
  const _MainImagePicker({
    required this.image,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  final MediaMeta? image;
  final bool busy;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = image;
    return Stack(
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: AppRadius.card,
          child: Container(
            height: 160,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
            ),
            child: busy && media == null
                ? const CircularProgressIndicator()
                : media == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.accentPrimaryDark,
                      ),
                      SizedBox(height: 6),
                      Text(
                        L.of(context).marketAddPhoto,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: AppRadius.card,
                    child: _MediaThumbnail(
                      media: media,
                      width: double.infinity,
                      height: 160,
                    ),
                  ),
          ),
        ),
        if (media != null && onRemove != null)
          Positioned(top: 6, right: 6, child: _RemoveBadge(onTap: onRemove!)),
      ],
    );
  }
}

class _GalleryStrip extends StatelessWidget {
  const _GalleryStrip({
    required this.images,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  final List<MediaMeta> images;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length + (canAdd ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == images.length) {
            return InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(Icons.add, color: AppColors.accentPrimaryDark),
              ),
            );
          }
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _MediaThumbnail(
                  media: images[index],
                  width: 84,
                  height: 84,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: _RemoveBadge(onTap: () => onRemove(index)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
        ),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    );
  }
}

class _MediaThumbnail extends ConsumerWidget {
  const _MediaThumbnail({
    required this.media,
    required this.width,
    required this.height,
  });

  final MediaMeta media;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: width,
      height: height,
      child: MediaImage.meta(media, decodeWidth: width),
    );
  }
}
