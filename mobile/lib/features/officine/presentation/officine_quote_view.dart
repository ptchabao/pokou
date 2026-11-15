import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/media_image.dart';
import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../../modules/shared/module_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_order_screen.dart';
import 'officine_reject_screen.dart';
import 'officine_ui.dart';

/// Une ligne du devis en cours d'écriture.
class _Line {
  _Line({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.available,
  });

  String name;
  int quantity;
  int unitPrice;
  bool available;

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit_price': unitPrice,
    'available': available,
  };
}

/// Officine · 2. Devis, et 2b quand l'original est demandé.
///
/// L'officine lit l'ordonnance, chiffre chaque produit et dit s'il est
/// disponible ; Honam ajoute la course. Un devis envoyé se corrige tant que
/// la patiente ne l'a pas accepté.
class OfficineQuoteView extends ConsumerStatefulWidget {
  const OfficineQuoteView({
    super.key,
    required this.order,
    required this.run,
    required this.busy,
  });

  final OfficineOrder order;
  final OfficineRun run;
  final bool busy;

  @override
  ConsumerState<OfficineQuoteView> createState() => _OfficineQuoteViewState();
}

class _OfficineQuoteViewState extends ConsumerState<OfficineQuoteView> {
  late final List<_Line> _lines = [
    for (final item in widget.order.quoteItems)
      _Line(
        name: item.name,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        available: item.available,
      ),
  ];
  late bool _original = widget.order.originalRequired;

  OfficineOrder get order => widget.order;

  int get _medicines => _lines
      .where((line) => line.available)
      .fold(0, (sum, line) => sum + line.unitPrice * line.quantity);

  Future<void> _edit([_Line? line]) async {
    final result = await showModuleSheet<_Line?>(
      context: context,
      builder: (_) => _LineEditor(line: line),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (line == null) {
        _lines.add(result);
      } else {
        line
          ..name = result.name
          ..quantity = result.quantity
          ..unitPrice = result.unitPrice
          ..available = result.available;
      }
    });
  }

  Future<void> _send() async {
    final l = L.of(context);
    if (!_lines.any((line) => line.available)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.offiQuoteNothingAvailable)));
      return;
    }
    final ok = await widget.run(
      'quote',
      body: {
        'items': [for (final line in _lines) line.toJson()],
        'original_required': _original,
      },
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.offiQuoteSent(officinePatient(context, order))),
        ),
      );
    }
  }

  void _zoom() {
    final id = order.prescriptionMediaId;
    if (id == null) return;
    ImageViewer.open(
      context,
      images: [
        ViewerImage(
          full: MediaImage(
            mediaId: id,
            fit: BoxFit.contain,
            semanticLabel: L
                .of(context)
                .offiPrescriptionOf(officinePatient(context, order)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final patient = officinePatient(context, order);
    final deliveryPrice =
        order.deliveryPrice ??
        ref.watch(officineDeliveryPriceProvider).valueOrNull;
    final quoted = order.status == 'QUOTED';
    final subtitle = [
      order.deliveryAddress,
      l.offiReceivedAt(officineTime(context, order.createdAt)),
    ].join(' · ');

    return OfficinePage(
      title: l.offiQuoteTitle(patient),
      subtitle: subtitle,
      status: order.status,
      onRefresh: () async => refreshOfficine(ref, order.id),
      primary: HonamPrimaryButton(
        label: quoted ? l.offiQuoteUpdate : l.offiQuoteSend(patient),
        busy: widget.busy,
        onPressed: _lines.isEmpty ? null : _send,
      ),
      secondary: quoted
          ? null
          : OfficineTextAction(
              label: l.offiRejectPrescription,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OfficineRejectScreen(order: order),
                ),
              ),
            ),
      children: [
        if (quoted && order.quoteExpiresAt != null) ...[
          ModuleCallout(
            tone: CalloutTone.amber,
            text: l.offiQuoteWaiting(
              patient,
              honamDateTime(context, order.quoteExpiresAt!),
            ),
          ),
          officineGap,
        ],
        // L'ordonnance, à agrandir.
        ModuleCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 72,
                  child: order.prescriptionMediaId == null
                      ? HonamThumb(
                          size: 64,
                          child: const Icon(Icons.description_outlined),
                        )
                      : MediaImage(
                          mediaId: order.prescriptionMediaId!,
                          decodeWidth: 200,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.offiPrescriptionOf(patient),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (order.patientNote != null &&
                        order.patientNote!.isNotEmpty)
                      Text(
                        '« ${order.patientNote} »',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (order.prescriptionMediaId != null)
                      OfficineOutlineButton(
                        label: l.offiZoom,
                        icon: Icons.zoom_out_map,
                        expanded: false,
                        onPressed: _zoom,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _original,
          onChanged: (value) => setState(() => _original = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.accentPrimary,
          title: Text(
            l.offiOriginalToCollect,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (_original) ...[
          OfficineNote(l.offiOriginalNotice(patient)),
          officineGap,
        ],
        ModuleSectionTitle(l.offiProducts),
        ModuleCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < _lines.length; i++) ...[
                if (i > 0) const HonamHairline(indent: 12),
                _LineRow(
                  line: _lines[i],
                  onTap: () => _edit(_lines[i]),
                  onRemove: () => setState(() => _lines.removeAt(i)),
                ),
              ],
              if (_lines.isNotEmpty) const HonamHairline(),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OfficineTextAction(
                  label: l.offiAddProduct,
                  icon: Icons.add,
                  onPressed: () => _edit(),
                ),
              ),
            ],
          ),
        ),
        officineGap,
        ModuleCard(
          child: Column(
            children: [
              OfficineAmountRow(l.offiMedicines, fcfa(_medicines)),
              OfficineAmountRow(l.offiCourseAddedByHonam, fcfa(deliveryPrice)),
              if (_original)
                OfficineAmountRow(l.offiOriginalReturn, fcfa(0), muted: true),
              const Divider(height: 18),
              OfficineAmountRow(
                l.offiTotalToPay,
                fcfa(_medicines + (deliveryPrice ?? 0)),
                strong: true,
              ),
            ],
          ),
        ),
        OfficineNote(l.offiCourseNote),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.onTap,
    required this.onRemove,
  });

  final _Line line;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: line.available
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        l.offiQuantity(line.quantity),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      OfficineTag(
                        line.available ? l.offiAvailable : l.offiUnavailable,
                        tone: line.available
                            ? OfficineTone.success
                            : OfficineTone.danger,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              fcfa(line.unitPrice * line.quantity),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            IconButton(
              tooltip: l.offiRemoveProduct,
              icon: Icon(Icons.close, size: 18, color: AppColors.textMuted),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// La feuille d'un produit : nom, quantité, prix unitaire, disponible.
class _LineEditor extends StatefulWidget {
  const _LineEditor({this.line});

  final _Line? line;

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late final _name = TextEditingController(text: widget.line?.name ?? '');
  late final _quantity = TextEditingController(
    text: '${widget.line?.quantity ?? 1}',
  );
  late final _price = TextEditingController(
    text: widget.line == null ? '' : '${widget.line!.unitPrice}',
  );
  late bool _available = widget.line?.available ?? true;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final quantity = int.tryParse(_quantity.text.trim()) ?? 0;
    final price = int.tryParse(_price.text.replaceAll(RegExp(r'\D'), ''));
    if (name.isEmpty || quantity < 1 || quantity > 100 || price == null) {
      HapticFeedback.heavyImpact();
      return;
    }
    Navigator.of(context).pop(
      _Line(
        name: name,
        quantity: quantity,
        unitPrice: price,
        available: _available,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleSheetTitle(
          widget.line == null ? l.offiAddProductTitle : l.offiEditProduct,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          autofocus: widget.line == null,
          maxLength: 160,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.offiProductName,
            hintText: l.offiProductNameHint,
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 110,
              child: TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l.offiProductQuantity),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l.offiProductUnitPrice,
                  suffixText: 'FCFA',
                ),
              ),
            ),
          ],
        ),
        SwitchListTile(
          value: _available,
          onChanged: (value) => setState(() => _available = value),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.accentPrimary,
          title: Text(l.offiAvailable),
          subtitle: Text(l.offiAvailableHint),
        ),
        const SizedBox(height: 8),
        HonamPrimaryButton(label: l.offiSave, onPressed: _save),
      ],
    );
  }
}
