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
import '../../modules/shared/module_ui.dart';
import '../data/product_model.dart';
import 'assime_publish.dart';
import 'assime_sheets.dart';
import 'marketplace_controller.dart';
import '../../../core/widgets/media_image.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/pokou_sheet.dart';

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
    this.condition,
    this.negotiable = false,
  });

  /// Assimé 6 : l'état et « Prix à débattre ».
  final String? condition;
  final bool negotiable;

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
  const ProductEditor({this.product, this.onSubmit, this.onDelete});

  /// Assimé 23 : « Supprimer l'annonce », sous le formulaire de
  /// modification. Rend `true` si l'annonce a quitté le marché.
  final Future<bool> Function(BuildContext context)? onDelete;

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

  /// Les photos, la couverture d'abord (Assimé 5 : cinq au plus). La
  /// première part comme photo principale, les autres comme galerie.
  final List<MediaMeta> _photos = [];

  /// Étape de l'assistant de publication : 1 (photos et catégorie) ou 2
  /// (prix, état et lieu) ; l'aperçu est un écran à part.
  int _step = 1;

  bool _uploading = false;
  bool _saving = false;
  String? _condition;
  bool _negotiable = false;

  /// Les CODES envoyés au serveur (« XOF », « TELEPHONES »), tenus à part
  /// des champs affichés : un `DropdownMenu` écrit dans son contrôleur le
  /// LIBELLÉ de l'entrée choisie (« FCFA (XOF) », « Téléphones »). Tant que
  /// le formulaire relisait ce contrôleur, il envoyait le libellé — une
  /// devise que le serveur refuse, et une catégorie qui n'apparaît sous
  /// aucun filtre.
  late String _currencyCode;
  late String _categorySlug;

  static const _maxPhotos = 5;

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
    _condition = product?.condition;
    _negotiable = product?.negotiable ?? false;
    if (product != null) _photos.addAll(product.allImages);
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
    return showPokouSheet<ImageSource>(
      scrollable: true,
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

  Future<void> _addPhoto() async {
    if (_photos.length >= _maxPhotos) return;
    final media = await _pickAndUpload();
    if (media != null && mounted) setState(() => _photos.add(media));
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
      imageMediaId: _photos.firstOrNull?.id,
      galleryMediaIds: [for (final media in _photos.skip(1)) media.id],
      condition: _condition,
      negotiable: _negotiable,
    );
    final submit = widget.onSubmit;
    if (submit == null) {
      Navigator.pop(context, draft);
      return;
    }
    if (widget.product == null) {
      // Une nouvelle annonce passe par l'aperçu (Assimé 7), qui publie
      // lui-même et ouvre « Produit interdit » si le serveur refuse.
      final published = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AssimePreviewScreen(
            draft: draft,
            cover: _photos.firstOrNull,
            onPublish: submit,
          ),
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (published == true) Navigator.pop(context, draft);
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

  /// Assimé 5 → 6 : « Continuer » demande au moins un titre.
  void _continue() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).marketNameAndPrice)));
      return;
    }
    setState(() => _step = 2);
  }

  List<Widget> _photosAndCategory(L l, MarketplaceConfig config) => [
    _PhotoStrip(
      photos: _photos,
      busy: _uploading,
      onAdd: _uploading || _photos.length >= _maxPhotos ? null : _addPhoto,
      onRemove: (index) => setState(() => _photos.removeAt(index)),
    ),
    const SizedBox(height: 6),
    Text(
      l.assimePhotosHint(_photos.length),
      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
    ),
    const SizedBox(height: 14),
    TextField(
      contextMenuBuilder: pokouContextMenuBuilder,
      controller: _name,
      decoration: InputDecoration(labelText: l.assimeTitleLabel),
    ),
    const SizedBox(height: 8),
    DropdownMenu<String>(
      controller: _category,
      initialSelection: _categorySlug,
      enableSearch: true,
      expandedInsets: EdgeInsets.zero,
      label: Text(l.marketCategory),
      dropdownMenuEntries: [
        for (final categorie in config.categories)
          DropdownMenuEntry(value: categorie.slug, label: categorie.label),
      ],
      onSelected: (value) => setState(() => _categorySlug = value ?? 'AUTRE'),
    ),
    if (_categorySlug == 'AUTRE')
      TextField(
        contextMenuBuilder: pokouContextMenuBuilder,
        controller: _categoryDetail,
        decoration: InputDecoration(labelText: l.marketSpecifyCategory),
      ),
  ];

  List<Widget> _priceConditionPlace(L l, MarketplaceConfig config) => [
    Row(
      children: [
        Expanded(
          child: TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.marketPrice),
          ),
        ),
        const SizedBox(width: 10),
        // ── La devise se CHOISIT ──────────────────────────────────────
        //
        // C'était un champ de texte libre : « XOF », « FCFA » et « fcfa »
        // désignaient la même monnaie sans jamais se comparer. La liste
        // vient de l'administration, et le serveur refuse le reste.
        DropdownMenu<String>(
          controller: _currency,
          initialSelection: _currencyCode,
          width: 130,
          label: Text(l.marketCurrency),
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
      ],
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _negotiable,
      onChanged: (v) => setState(() => _negotiable = v),
      title: Text(l.assimeNegotiable),
      subtitle: Text(l.assimeNegotiableSub),
    ),
    Text(
      l.assimeFilterCondition,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final condition in assimeConditions)
          AssimeChoiceChip(
            label: assimeConditionLabel(l, condition),
            selected: _condition == condition,
            onSelected: (on) =>
                setState(() => _condition = on ? condition : null),
          ),
      ],
    ),
    const SizedBox(height: 8),
    TextField(
      contextMenuBuilder: pokouContextMenuBuilder,
      controller: _description,
      maxLines: 3,
      decoration: InputDecoration(labelText: l.marketDescription),
    ),
    const SizedBox(height: 4),
    Row(
      children: [
        Expanded(
          child: TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _location,
            decoration: InputDecoration(labelText: l.assimeAreaLabel),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _fetchingLocation ? null : _useMyGpsLocation,
          tooltip: l.marketUseGps,
          icon: _fetchingLocation
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.accentPrimaryDark.withValues(alpha: 0.1),
            foregroundColor: AppColors.accentPrimaryDark,
          ),
        ),
      ],
    ),
    if (_latitude != null && _longitude != null)
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          l.marketGpsCoords(
            _latitude!.toStringAsFixed(4),
            _longitude!.toStringAsFixed(4),
          ),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final config = ref.watch(marketplaceConfigProvider);
    // Une nouvelle annonce (Assimé 5 à 7) : un assistant en trois étapes,
    // la troisième étant l'aperçu. Une modification (Assimé 23) : une page.
    final wizard = widget.product == null && widget.onSubmit != null;
    final String title;
    String? subtitle;
    if (wizard) {
      title = _step == 1 ? l.assimeStep1Title : l.assimeStep2Title;
      subtitle = l.assimePublishStep(_step);
    } else {
      title = widget.product == null ? l.marketAddProduct : l.assimeEditTitle;
    }
    final String action = _uploading
        ? l.marketUploadingPhoto
        : wizard
        ? (_step == 1 ? l.assimeContinue : l.assimeSeePreview)
        : widget.product != null
        ? l.assimeSaveChanges
        : l.actionSave;
    return PopScope(
      canPop: !(wizard && _step == 2),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 1);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            if (wizard) ...[
              AssimeStepBar(step: _step),
              const SizedBox(height: 14),
            ],
            if (!wizard || _step == 1) ..._photosAndCategory(l, config),
            if (wizard && _step == 1) ...[
              const SizedBox(height: 14),
              ModuleCallout(
                tone: CalloutTone.beige,
                text: l.assimeNumberNeverShown,
              ),
            ],
            if (!wizard) const SizedBox(height: 8),
            if (!wizard || _step == 2) ..._priceConditionPlace(l, config),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModuleActionButton(
                  label: action,
                  busy: _saving,
                  onPressed: _uploading || _saving
                      ? null
                      : wizard && _step == 1
                      ? _continue
                      : _save,
                ),
                if (widget.onDelete != null)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            final gone = await widget.onDelete!(context);
                            if (gone && mounted) Navigator.of(context).pop();
                          },
                    child: Text(
                      l.assimeDeleteAction,
                      style: TextStyle(color: AppColors.feedbackDanger),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Assimé 5 et 23 : cinq photos au plus, la première sert de couverture.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photos,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
  });

  final List<MediaMeta> photos;
  final bool busy;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    const size = 76.0;
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + (onAdd == null && !busy ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            color: AppColors.accentPrimary,
                          ),
                          Text(
                            l.assimeAddPhotoShort,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ],
                      ),
              ),
            );
          }
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _MediaThumbnail(
                  media: photos[index],
                  width: size,
                  height: size,
                ),
              ),
              if (index == 0)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l.assimeCover,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
