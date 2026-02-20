import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class VoucherSheet extends StatefulWidget {
  // If provided, we close via sheetCtx pop. Else fallback to Navigator.pop(context).
  final VoidCallback? onClose;

  final String actionLabel; // အဝယ် / အရောင်း
  final String goldFormLabel; // အတုံး / အထည်
  final String goldTypeLabel; // 16 ပဲရည် ...
  final double marketPrice16;

  // SELL only
  final double? buyTimePrice16; // inferred 16-pae at buy time
  final double? paidAmount; // what user paid at buy time
  final double? profitLoss; // final - paid (SELL only)

  final double weightKyattha;
  final double discountWeightKyattha;
  final double netWeightKyattha;

  final double baseAmount;
  final double discountAmount;
  final double finalAmount;

  // Optional: show timestamp in PDF header/footer
  final DateTime? calculatedAt;

  const VoucherSheet({
    super.key,
    this.onClose,
    required this.actionLabel,
    required this.goldFormLabel,
    required this.goldTypeLabel,
    required this.marketPrice16,
    this.buyTimePrice16,
    this.paidAmount,
    this.profitLoss,
    required this.weightKyattha,
    required this.discountWeightKyattha,
    required this.netWeightKyattha,
    required this.baseAmount,
    required this.discountAmount,
    required this.finalAmount,
    this.calculatedAt,
  });

  @override
  State<VoucherSheet> createState() => _VoucherSheetState();
}

class _VoucherSheetState extends State<VoucherSheet> {
  bool _busy = false;
  final GlobalKey _captureKey = GlobalKey();
  static const MethodChannel _filesChannel = MethodChannel('mmgold/files');

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _close(BuildContext context) {
    HapticFeedback.selectionClick();
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  String _commaInt(num v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  String _fmtWeight(double kyattha) {
    final sign = kyattha < 0 ? '-' : '';
    double x = kyattha.abs();

    int kyat = x.floor();
    x = (x - kyat) * 16.0;

    int pae = x.floor();
    x = (x - pae) * 8.0;

    int yway = x.round();

    if (yway >= 8) {
      yway -= 8;
      pae += 1;
    }
    if (pae >= 16) {
      pae -= 16;
      kyat += 1;
    }

    return '$sign$kyat ကျပ် $pae ပဲ $yway ရွေး';
  }

  String _fmtDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<pw.Font> _loadMyanmarFont() async {
    final data =
        await rootBundle.load('assets/fonts/NotoSansMyanmar-Regular.ttf');
    return pw.Font.ttf(data);
  }

  Future<Uint8List> _buildPdfBytes() async {
    final font = await _loadMyanmarFont();

    final doc = pw.Document(
      title: 'Myanmar Gold Voucher',
      author: 'MMGold',
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );

    final now = widget.calculatedAt ?? DateTime.now();
    final isBuy = widget.actionLabel.contains('ဝယ်');
    final pl = widget.profitLoss;
    final plIsProfit = (pl ?? 0) >= 0;

    pw.Widget kv(String k, String v, {bool strong = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                k,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Text(
                v,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: strong ? 11 : 10,
                  fontWeight:
                      strong ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget sectionTitle(String t) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 6),
        child: pw.Text(
          t,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      );
    }

    pw.Widget pill(String t, PdfColor bg, PdfColor fg) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(999),
          border: pw.Border.all(color: fg, width: 0.6),
        ),
        child: pw.Text(
          t,
          style: pw.TextStyle(
              fontSize: 9.5, color: fg, fontWeight: pw.FontWeight.bold),
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MMGold • Voucher',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        build: (ctx) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'GOLD VOUCHER',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Calculated: ${_fmtDateTime(now)}',
                    style: const pw.TextStyle(
                        fontSize: 9.5, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${_commaInt(widget.finalAmount)} ကျပ်',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              pill(
                widget.actionLabel,
                isBuy ? PdfColors.blue50 : PdfColors.red50,
                isBuy ? PdfColors.blue800 : PdfColors.red800,
              ),
              if (widget.goldFormLabel.trim().isNotEmpty)
                pill(widget.goldFormLabel, PdfColors.indigo50,
                    PdfColors.indigo800),
              pill(widget.goldTypeLabel, PdfColors.teal50, PdfColors.teal800),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey300),
          sectionTitle('Weight Summary'),
          kv('အလေးချိန်', _fmtWeight(widget.weightKyattha), strong: true),
          kv('အလျော့ချိန်', _fmtWeight(widget.discountWeightKyattha)),
          kv('စုစုပေါင်း အလေးချိန်', _fmtWeight(widget.netWeightKyattha),
              strong: true),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColors.grey300),
          sectionTitle('Price Details'),
          kv('လက်ရှိ ၁၆ ပဲရည် ပေါက်ဈေး',
              '${_commaInt(widget.marketPrice16)} ကျပ်'),
          if (widget.buyTimePrice16 != null)
            kv('မိမိဝယ်ချိန်မှ ၁၆ ပဲရည် ရွှေဈေး',
                '${_commaInt(widget.buyTimePrice16!)} ကျပ်'),
          if (widget.paidAmount != null)
            kv('ဝယ်ခဲ့စဉ် ပေးခဲ့ရတဲ့စျေး',
                '${_commaInt(widget.paidAmount!)} ကျပ်'),
          kv('ကျသင့်ငွေ (Base)', '${_commaInt(widget.baseAmount)} ကျပ်'),
          kv('အလျော့တွက်', '${_commaInt(widget.discountAmount)} ကျပ်'),
          if (pl != null) ...[
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey300),
            sectionTitle('Profit / Loss'),
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: pw.BoxDecoration(
                color: plIsProfit ? PdfColors.green50 : PdfColors.red50,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(
                    color: plIsProfit ? PdfColors.green300 : PdfColors.red300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    plIsProfit ? 'Profit' : 'Loss',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: plIsProfit ? PdfColors.green800 : PdfColors.red800,
                    ),
                  ),
                  pw.Text(
                    '${plIsProfit ? '+' : ''}${_commaInt(pl)} ကျပ်',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: plIsProfit ? PdfColors.green800 : PdfColors.red800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  String _pdfFileName() {
    final t = DateTime.now().toIso8601String().replaceAll(':', '-');
    return 'mmgold_voucher_$t.pdf';
  }

  Future<void> _sharePdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _buildPdfBytes();
      await Printing.sharePdf(bytes: bytes, filename: _pdfFileName());
    } catch (e) {
      _snack('Share PDF မလုပ်နိုင်ပါ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List> _capturePngBytes() async {
    await Future.delayed(const Duration(milliseconds: 30));
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Voucher capture boundary not found');
    }
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to encode PNG');
    return byteData.buffer.asUint8List();
  }

  String _pngFileName() {
    final t = DateTime.now().toIso8601String().replaceAll(':', '-');
    return 'mmgold_voucher_$t.png';
  }

  Future<void> _saveImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePngBytes();
      final fileName = _pngFileName();

      if (!kIsWeb && Platform.isAndroid) {
        final savedPath =
            await _filesChannel.invokeMethod<String>('saveImageToDownloads', {
          'bytes': bytes,
          'fileName': fileName,
          'mimeType': 'image/png',
        });
        if (savedPath != null && savedPath.isNotEmpty) {
          _snack('Download ထဲသို့သိမ်းပြီးပါပြီ\n$savedPath');
          return;
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory('${dir.path}/mmgold');
      if (!await outDir.exists()) await outDir.create(recursive: true);
      final file = File('${outDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      _snack('Image saved ✅\n${file.path}');
    } catch (e) {
      _snack('Save Image မလုပ်နိုင်ပါ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ======= UI helpers =======
  Widget _badge({
    required BuildContext context,
    required String text,
    required Color bg,
    required Color fg,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {TextStyle? vStyle}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(k, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: vStyle ?? const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softDivider(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      height: 1,
      color: cs.outlineVariant.withValues(alpha: 0.55),
    );
  }

  ButtonStyle _solidPill(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: cs.surface,
      foregroundColor: cs.primary,
      side: BorderSide(color: cs.outline),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final isBuy = widget.actionLabel.contains('ဝယ်');
    final actionBg = isBuy
        ? Colors.blue.withValues(alpha: 0.12)
        : Colors.red.withValues(alpha: 0.12);
    final actionFg = isBuy ? Colors.blue : Colors.red;

    final pl = widget.profitLoss;
    final plIsProfit = (pl ?? 0) >= 0;
    final plColor = plIsProfit ? Colors.green : Colors.red;
    final plBg = plIsProfit
        ? Colors.green.withValues(alpha: 0.12)
        : Colors.red.withValues(alpha: 0.12);

    final cardContent = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(
                context: context,
                text: widget.actionLabel,
                bg: actionBg,
                fg: actionFg,
                icon: isBuy ? Icons.shopping_bag_outlined : Icons.sell_outlined,
              ),
              if (widget.goldFormLabel.trim().isNotEmpty)
                _badge(
                  context: context,
                  text: widget.goldFormLabel,
                  bg: cs.primary.withValues(alpha: 0.10),
                  fg: cs.primary,
                  icon: Icons.category_outlined,
                ),
              _badge(
                context: context,
                text: widget.goldTypeLabel,
                bg: cs.tertiary.withValues(alpha: 0.10),
                fg: cs.tertiary,
                icon: Icons.workspace_premium_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'GOLD VOUCHER',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_commaInt(widget.finalAmount)} ကျပ်',
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          _softDivider(context),
          _sectionTitle(context, 'Weight Summary', Icons.scale_outlined),
          _kv(
            context,
            'အလေးချိန်',
            _fmtWeight(widget.weightKyattha),
            vStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          _kv(context, 'အလျော့ချိန်', _fmtWeight(widget.discountWeightKyattha)),
          _kv(
            context,
            'စုစုပေါင်း အလေးချိန်',
            _fmtWeight(widget.netWeightKyattha),
            vStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          _softDivider(context),
          _sectionTitle(context, 'Price Details', Icons.payments_outlined),
          _kv(context, 'လက်ရှိ ၁၆ ပဲရည် ပေါက်ဈေး',
              '${_commaInt(widget.marketPrice16)} ကျပ်'),
          if (widget.buyTimePrice16 != null)
            _kv(context, 'မိမိဝယ်ချိန်မှ ၁၆ ပဲရည် ရွှေဈေး',
                '${_commaInt(widget.buyTimePrice16!)} ကျပ်'),
          if (widget.paidAmount != null)
            _kv(context, 'ဝယ်ခဲ့စဉ် ပေးခဲ့ရတဲ့စျေး',
                '${_commaInt(widget.paidAmount!)} ကျပ်'),
          _kv(context, 'ကျသင့်ငွေ (Base)',
              '${_commaInt(widget.baseAmount)} ကျပ်'),
          _kv(context, 'အလျော့တွက်',
              '${_commaInt(widget.discountAmount)} ကျပ်'),
          if (pl != null) ...[
            _softDivider(context),
            _sectionTitle(context, 'Profit / Loss', Icons.trending_up_rounded),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: plBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: plColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(
                    plIsProfit
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: plColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plIsProfit ? 'Profit' : 'Loss',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, color: plColor),
                    ),
                  ),
                  Text(
                    '${plIsProfit ? '+' : ''}${_commaInt(pl)} ကျပ်',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, color: plColor),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    // ✅ RepaintBoundary to capture PNG
    final mainCard = RepaintBoundary(
      key: _captureKey,
      child: cardContent,
    );

    final maxH = MediaQuery.of(context).size.height * 0.88;

    // ✅ Full-screen overlay with blur + dim
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                  top: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return FittedBox(
                                alignment: Alignment.topCenter,
                                fit: BoxFit.contain,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: mainCard,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _saveImage,
                                style: _solidPill(context),
                                icon: _busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.image_outlined, size: 18),
                                label: const Text(
                                  'Save Image',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _sharePdf,
                                style: _solidPill(context),
                                icon: const Icon(Icons.share_outlined, size: 18),
                                label: const Text(
                                  'Share PDF',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _close(context),
                                style: _solidPill(context),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text(
                                  'Close',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
