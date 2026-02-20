import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mmgold/shared/supabase/supabase_provider.dart';
import 'package:mmgold/shared/notifications/admin_notification_sender.dart';
import 'package:mmgold/shared/notifications/notification_destination.dart';
import 'package:mmgold/shared/widgets/gradient_scaffold.dart';

import '../data/domain/gold_price_models.dart';
import '../data/domain/gold_price_repo.dart';

class GoldPriceAdminPage extends StatefulWidget {
  const GoldPriceAdminPage({super.key});

  @override
  State<GoldPriceAdminPage> createState() => _GoldPriceAdminPageState();
}

class _GoldPriceAdminPageState extends State<GoldPriceAdminPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSigningIn = false;
  String? _error;
  String? _adminCheckUid;
  Future<bool>? _adminCheckFuture;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Email နှင့် Password ထည့်ပါ');
      return;
    }

    setState(() {
      _isSigningIn = true;
      _error = null;
    });

    try {
      await SupabaseProvider.client.auth.signInWithPassword(
        email: email,
        password: pass,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Login မအောင်မြင်ပါ');
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<bool> _isAdmin(String uid) async {
    final row = await SupabaseProvider.client
        .from('admins')
        .select('user_id')
        .eq('user_id', uid)
        .maybeSingle();
    return row != null;
  }

  Future<bool> _adminFutureFor(String uid) {
    if (_adminCheckFuture == null || _adminCheckUid != uid) {
      _adminCheckUid = uid;
      _adminCheckFuture = _isAdmin(uid);
    }
    return _adminCheckFuture!;
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return GradientScaffold(
        appBar: AppBar(title: const Text('Gold Price Admin')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Admin dashboard ကို website မှာပဲအသုံးပြုနိုင်ပါတယ်။',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!SupabaseProvider.isConfigured) {
      return const GradientScaffold(
        appBar: null,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Supabase config မရှိသေးပါ။\n'
              'Run with --dart-define=SUPABASE_URL=... '
              '--dart-define=SUPABASE_ANON_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return GradientScaffold(
      appBar: AppBar(title: const Text('Gold Price Admin')),
      body: StreamBuilder<AuthState>(
        stream: SupabaseProvider.client.auth.onAuthStateChange,
        builder: (context, snap) {
          final user = snap.data?.session?.user ??
              SupabaseProvider.client.auth.currentUser;

          if (user == null) {
            _adminCheckUid = null;
            _adminCheckFuture = null;
            return _buildSignIn(context);
          }

          return FutureBuilder<bool>(
            future: _adminFutureFor(user.id),
            builder: (context, adminSnap) {
              if (adminSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final isAdmin = adminSnap.data == true;
              if (!isAdmin) {
                return _NoAdminAccess(
                  email: user.email ?? user.id,
                  onSignOut: () => SupabaseProvider.client.auth.signOut(),
                );
              }

              return _AdminEditor(
                email: user.email ?? user.id,
                onSignOut: () => SupabaseProvider.client.auth.signOut(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSignIn(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Sign In',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Supabase Auth ဖြင့် login ဝင်ပြီး dashboard မှ update တင်နိုင်ပါသည်။',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSigningIn ? null : _signIn,
                    child: _isSigningIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign In'),
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

class _NoAdminAccess extends StatelessWidget {
  final String email;
  final Future<void> Function() onSignOut;

  const _NoAdminAccess({required this.email, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Admin Access',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text('Signed in as $email'),
                const SizedBox(height: 8),
                const Text(
                  'ဒီ account ကို admins table ထဲ user_id ဖြင့်ထည့်ပြီးမှ update တင်နိုင်ပါမယ်။',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onSignOut,
                    child: const Text('Sign Out'),
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

class _AdminEditor extends StatefulWidget {
  final String email;
  final Future<void> Function() onSignOut;

  const _AdminEditor({required this.email, required this.onSignOut});

  @override
  State<_AdminEditor> createState() => _AdminEditorState();
}

class _AdminEditorState extends State<_AdminEditor> {
  final _formKey = GlobalKey<FormState>();
  final _repo = GoldPriceRepo();
  final _notificationSender = AdminNotificationSender();

  final _ygea16 = TextEditingController();
  final _k16Buy = TextEditingController();
  final _k16Sell = TextEditingController();
  final _k16newBuy = TextEditingController();
  final _k16newSell = TextEditingController();
  final _k15Buy = TextEditingController();
  final _k15Sell = TextEditingController();
  final _k15newBuy = TextEditingController();
  final _k15newSell = TextEditingController();
  final _imageUrl = TextEditingController();
  final _notifyTitle = TextEditingController(text: 'MMGold Notification');
  final _notifyBody = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _sendingNotification = false;
  bool _uploadingImage = false;
  bool _historyLoading = false;
  bool _historyBusy = false;
  String _notifyTarget = NotificationDestination.goldPrice;
  String _updateNotifyTarget = NotificationDestination.goldPrice;
  List<_HistoryRow> _historyRows = const [];
  final ScrollController _desktopScroll = ScrollController();
  _AdminSection _selectedSection = _AdminSection.dashboard;
  final Map<_AdminSection, GlobalKey> _sectionKeys = {
    _AdminSection.dashboard: GlobalKey(),
    _AdminSection.priceUpdates: GlobalKey(),
    _AdminSection.notifications: GlobalKey(),
    _AdminSection.imageUpload: GlobalKey(),
    _AdminSection.history: GlobalKey(),
    _AdminSection.settings: GlobalKey(),
  };

  String _normalizeDigits(String input) {
    const mm = '၀၁၂၃၄၅၆၇၈၉';
    var out = input;
    for (var i = 0; i < mm.length; i++) {
      out = out.replaceAll(mm[i], i.toString());
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _loadLatest();
    _loadHistory();
  }

  @override
  void dispose() {
    _desktopScroll.dispose();
    _ygea16.dispose();
    _k16Buy.dispose();
    _k16Sell.dispose();
    _k16newBuy.dispose();
    _k16newSell.dispose();
    _k15Buy.dispose();
    _k15Sell.dispose();
    _k15newBuy.dispose();
    _k15newSell.dispose();
    _imageUrl.dispose();
    _notifyTitle.dispose();
    _notifyBody.dispose();
    super.dispose();
  }

  Future<void> _jumpTo(_AdminSection section) async {
    setState(() => _selectedSection = section);
    final ctx = _sectionKeys[section]?.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  int _toInt(TextEditingController c) {
    final raw =
        _normalizeDigits(c.text.trim()).replaceAll(',', '').replaceAll(' ', '');
    return int.tryParse(raw) ?? 0;
  }

  void _fill(TextEditingController c, int? value) {
    c.text = value == null ? '' : value.toString();
  }

  DateTime _myanmarNow() {
    final utcNow = DateTime.now().toUtc();
    return utcNow.add(const Duration(hours: 6, minutes: 30));
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _loadLatest() async {
    setState(() => _loading = true);
    final latest = await _repo.fetchLatest();

    if (latest != null) {
      _fill(_ygea16, latest.ygea16);
      _fill(_k16Buy, latest.k16Buy);
      _fill(_k16Sell, latest.k16Sell);
      _fill(_k16newBuy, latest.k16newBuy);
      _fill(_k16newSell, latest.k16newSell);
      _fill(_k15Buy, latest.k15Buy);
      _fill(_k15Sell, latest.k15Sell);
      _fill(_k15newBuy, latest.k15newBuy);
      _fill(_k15newSell, latest.k15newSell);
      _imageUrl.text = latest.imageUrl ?? '';
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _historyLoading = true);
    try {
      final rows = await _repo.fetchHistoryRows(limit: 365);
      if (!mounted) return;
      setState(() {
        _historyRows = rows.map(_HistoryRow.fromMap).toList();
      });
    } finally {
      if (mounted) {
        setState(() => _historyLoading = false);
      }
    }
  }

  Future<void> _openHistoryEditor([_HistoryRow? row]) async {
    final dateCtrl = TextEditingController(text: row?.price.date ?? '');
    final timeCtrl = TextEditingController(text: row?.price.time ?? '');
    final ygeaCtrl =
        TextEditingController(text: row?.price.ygea16?.toString() ?? '');
    final k16BuyCtrl =
        TextEditingController(text: row?.price.k16Buy?.toString() ?? '');
    final k16SellCtrl =
        TextEditingController(text: row?.price.k16Sell?.toString() ?? '');
    final k16NewBuyCtrl =
        TextEditingController(text: row?.price.k16newBuy?.toString() ?? '');
    final k16NewSellCtrl =
        TextEditingController(text: row?.price.k16newSell?.toString() ?? '');
    final k15BuyCtrl =
        TextEditingController(text: row?.price.k15Buy?.toString() ?? '');
    final k15SellCtrl =
        TextEditingController(text: row?.price.k15Sell?.toString() ?? '');
    final k15NewBuyCtrl =
        TextEditingController(text: row?.price.k15newBuy?.toString() ?? '');
    final k15NewSellCtrl =
        TextEditingController(text: row?.price.k15newSell?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row == null ? 'Add History Row' : 'Edit History Row'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: dateCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: timeCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Time (hh:mm AM/PM)'),
                ),
                const SizedBox(height: 8),
                _historyNumField('YGEA 16', ygeaCtrl),
                _historyNumField('16 Buy', k16BuyCtrl),
                _historyNumField('16 Sell', k16SellCtrl),
                _historyNumField('16 New Buy', k16NewBuyCtrl),
                _historyNumField('16 New Sell', k16NewSellCtrl),
                _historyNumField('15 Buy', k15BuyCtrl),
                _historyNumField('15 Sell', k15SellCtrl),
                _historyNumField('15 New Buy', k15NewBuyCtrl),
                _historyNumField('15 New Sell', k15NewSellCtrl),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) {
      dateCtrl.dispose();
      timeCtrl.dispose();
      ygeaCtrl.dispose();
      k16BuyCtrl.dispose();
      k16SellCtrl.dispose();
      k16NewBuyCtrl.dispose();
      k16NewSellCtrl.dispose();
      k15BuyCtrl.dispose();
      k15SellCtrl.dispose();
      k15NewBuyCtrl.dispose();
      k15NewSellCtrl.dispose();
      return;
    }

    final model = GoldPriceLatest(
      date: dateCtrl.text.trim().isEmpty ? null : dateCtrl.text.trim(),
      time: timeCtrl.text.trim().isEmpty ? null : timeCtrl.text.trim(),
      ygea16: _parseHistoryInt(ygeaCtrl.text),
      k16Buy: _parseHistoryInt(k16BuyCtrl.text),
      k16Sell: _parseHistoryInt(k16SellCtrl.text),
      k16newBuy: _parseHistoryInt(k16NewBuyCtrl.text),
      k16newSell: _parseHistoryInt(k16NewSellCtrl.text),
      k15Buy: _parseHistoryInt(k15BuyCtrl.text),
      k15Sell: _parseHistoryInt(k15SellCtrl.text),
      k15newBuy: _parseHistoryInt(k15NewBuyCtrl.text),
      k15newSell: _parseHistoryInt(k15NewSellCtrl.text),
      imageUrl: row?.price.imageUrl,
    );

    dateCtrl.dispose();
    timeCtrl.dispose();
    ygeaCtrl.dispose();
    k16BuyCtrl.dispose();
    k16SellCtrl.dispose();
    k16NewBuyCtrl.dispose();
    k16NewSellCtrl.dispose();
    k15BuyCtrl.dispose();
    k15SellCtrl.dispose();
    k15NewBuyCtrl.dispose();
    k15NewSellCtrl.dispose();

    setState(() => _historyBusy = true);
    try {
      if (row == null) {
        await _repo.insertHistoryRow(model);
      } else {
        if (row.id.toString().isEmpty) {
          throw Exception('Missing history row id');
        }
        await _repo.updateHistoryRow(id: row.id, value: model);
      }
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(row == null
              ? 'History row ထည့်ပြီးပါပြီ'
              : 'History row ပြင်ပြီးပါပြီ'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History row save မအောင်မြင်ပါ')),
      );
    } finally {
      if (mounted) setState(() => _historyBusy = false);
    }
  }

  Future<void> _deleteHistory(_HistoryRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete History'),
        content:
            Text('Delete ${row.price.date ?? ''} ${row.price.time ?? ''} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (row.id.toString().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History row id မရှိလို့ မဖျက်နိုင်ပါ')),
      );
      return;
    }
    setState(() => _historyBusy = true);
    try {
      await _repo.deleteHistoryRow(row.id);
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History row ဖျက်ပြီးပါပြီ')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History row delete မအောင်မြင်ပါ')),
      );
    } finally {
      if (mounted) setState(() => _historyBusy = false);
    }
  }

  String? _requiredNumber(String? v) {
    final cleaned = _normalizeDigits(v ?? '')
        .trim()
        .replaceAll(',', '')
        .replaceAll(' ', '');
    if (cleaned.isEmpty) return 'လိုအပ်ပါတယ်';
    final n = int.tryParse(cleaned);
    if (n == null || n < 0) return '0 နှင့်အထက် ဂဏန်းထည့်ပါ';
    return null;
  }

  String _contentTypeForExtension(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _uploadImage() async {
    setState(() => _uploadingImage = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File data မရပါ')),
        );
        return;
      }

      final ext = (file.extension ?? 'jpg').toLowerCase();
      final safeName =
          (file.name.isEmpty ? 'image' : file.name).replaceAll(' ', '_');
      final path = 'latest/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      await SupabaseProvider.client.storage.from('gold-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeForExtension(ext),
            ),
          );

      final publicUrl = SupabaseProvider.client.storage
          .from('gold-images')
          .getPublicUrl(path);

      _imageUrl.text = publicUrl;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload အောင်မြင်ပါသည်')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload မအောင်မြင်ပါ')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final now = _myanmarNow();
      final model = GoldPriceLatest(
        date: _fmtDate(now),
        time: _fmtTime(now),
        imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
        ygea16: _toInt(_ygea16),
        k16Buy: _toInt(_k16Buy),
        k16Sell: _toInt(_k16Sell),
        k16newBuy: _toInt(_k16newBuy),
        k16newSell: _toInt(_k16newSell),
        k15Buy: _toInt(_k15Buy),
        k15Sell: _toInt(_k15Sell),
        k15newBuy: _toInt(_k15newBuy),
        k15newSell: _toInt(_k15newSell),
      );

      await _repo.updateLatestAutoHistory(model);

      String? notifyError;
      try {
        await _sendPriceUpdateNotification(model);
      } catch (_) {
        notifyError = 'ဈေး update သိပေး notification မပို့နိုင်ပါ';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notifyError == null
                ? 'ဈေး update + notification ပို့ပြီးပါပြီ'
                : 'ဈေး update အောင်မြင်ပါသည်။ $notifyError',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update မအောင်မြင်ပါ')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _sendPriceUpdateNotification(GoldPriceLatest model) async {
    final buy = _money(model.k16Buy ?? 0);
    final sell = _money(model.k16Sell ?? 0);

    await _notificationSender.send(
      title: 'ရွှေဈေး Update',
      body: '၁၆ ပဲရည် ဝယ်: $buy ကျပ် | ရောင်း: $sell ကျပ်',
      target: _updateNotifyTarget,
      type: 'gold_price_update',
      data: {
        'k16_buy': '${model.k16Buy ?? 0}',
        'k16_sell': '${model.k16Sell ?? 0}',
        'date': model.date ?? '',
        'time': model.time ?? '',
      },
    );
  }

  Future<void> _sendCustomNotification() async {
    final title = _notifyTitle.text.trim();
    final body = _notifyBody.text.trim();

    if (title.isEmpty || body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification title/body ထည့်ပါ')),
      );
      return;
    }

    setState(() => _sendingNotification = true);
    try {
      await _notificationSender.send(
        title: title,
        body: body,
        target: _notifyTarget,
        type: 'admin_custom',
      );

      if (!mounted) return;
      _notifyBody.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification ပို့ပြီးပါပြီ')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification မပို့နိုင်ပါ')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingNotification = false);
      }
    }
  }

  Widget _field(String label, TextEditingController c) {
    return TextFormField(
      controller: c,
      validator: _requiredNumber,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9၀-၉,\s]')),
      ],
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _historyNumField(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9၀-၉,\s]')),
        ],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  int? _parseHistoryInt(String value) {
    final cleaned =
        _normalizeDigits(value).trim().replaceAll(',', '').replaceAll(' ', '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  Widget _notificationPanel() {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Push Notifications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'ဈေး update တင်တိုင်း notification ပို့မည်။ Admin စာသားဖြင့်လည်း custom notification ပို့နိုင်ပါသည်။',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _updateNotifyTarget,
              decoration: const InputDecoration(
                labelText: 'Price update tap destination',
                prefixIcon: Icon(Icons.touch_app_outlined),
              ),
              items: NotificationDestination.options
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.value,
                      child: Text(e.label),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _updateNotifyTarget = v);
                    },
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notifyTitle,
              decoration: const InputDecoration(
                labelText: 'Custom notification title',
                prefixIcon: Icon(Icons.campaign_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notifyBody,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Custom notification body',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.edit_note_outlined),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _notifyTarget,
              decoration: const InputDecoration(
                labelText: 'Custom notification tap destination',
                prefixIcon: Icon(Icons.navigation_outlined),
              ),
              items: NotificationDestination.options
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.value,
                      child: Text(e.label),
                    ),
                  )
                  .toList(),
              onChanged: _sendingNotification
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _notifyTarget = v);
                    },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _sendingNotification ? null : _sendCustomNotification,
                icon: _sendingNotification
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Send Custom Notification'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyManagerPanel() {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'History Manager',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: (_historyBusy || _historyLoading)
                      ? null
                      : () => _openHistoryEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Row'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed:
                      (_historyBusy || _historyLoading) ? null : _loadHistory,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'တစ်နှစ်စာ history ကို ဒီနေရာမှာ ကိုယ်တိုင် Add / Edit / Delete လုပ်နိုင်ပါတယ်။',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (_historyLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_historyRows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('History data မရှိသေးပါ'),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    for (final row in _historyRows.take(60))
                      Column(
                        children: [
                          ListTile(
                            dense: true,
                            title: Text(
                              '${row.price.date ?? '-'}   ${row.price.time ?? '-'}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '16 Sell: ${_money(row.price.k16Sell ?? 0)} | '
                              '16 New Sell: ${_money(row.price.k16newSell ?? 0)} | '
                              '15 Sell: ${_money(row.price.k15Sell ?? 0)} | '
                              '15 New Sell: ${_money(row.price.k15newSell ?? 0)}',
                            ),
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: _historyBusy
                                      ? null
                                      : () => _openHistoryEditor(row),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: _historyBusy
                                      ? null
                                      : () => _deleteHistory(row),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: cs.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: cs.outlineVariant),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return _buildCompactLayout(context);
        }
        return _buildDesktopLayout(context);
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 248,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.75),
            border: Border(right: BorderSide(color: cs.outlineVariant)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    'MMGold Admin',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
                const Divider(height: 1),
                _menuTile(
                  'Dashboard',
                  Icons.dashboard_outlined,
                  _selectedSection == _AdminSection.dashboard,
                  () => _jumpTo(_AdminSection.dashboard),
                ),
                _menuTile(
                  'Price Updates',
                  Icons.currency_exchange_rounded,
                  _selectedSection == _AdminSection.priceUpdates,
                  () => _jumpTo(_AdminSection.priceUpdates),
                ),
                _menuTile(
                  'Notifications',
                  Icons.notifications_active_outlined,
                  _selectedSection == _AdminSection.notifications,
                  () => _jumpTo(_AdminSection.notifications),
                ),
                _menuTile(
                  'Image Upload',
                  Icons.image_outlined,
                  _selectedSection == _AdminSection.imageUpload,
                  () => _jumpTo(_AdminSection.imageUpload),
                ),
                _menuTile(
                  'History',
                  Icons.history_rounded,
                  _selectedSection == _AdminSection.history,
                  () => _jumpTo(_AdminSection.history),
                ),
                _menuTile(
                  'Settings',
                  Icons.settings_outlined,
                  _selectedSection == _AdminSection.settings,
                  () => _jumpTo(_AdminSection.settings),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _desktopScroll,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(key: _sectionKeys[_AdminSection.dashboard]),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Gold Price Dashboard',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(widget.email),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        title: 'YGEA 16',
                        value: _money(_toInt(_ygea16)),
                        subtitle: 'Current market price',
                        primary: true,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _statCard(
                        title: 'Status',
                        value: _saving ? 'Saving...' : 'Ready',
                        subtitle: 'Supabase admin panel',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(key: _sectionKeys[_AdminSection.priceUpdates]),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Price Update Form',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _fieldBox('YGEA 16', _ygea16),
                              _fieldBox('16 Buy', _k16Buy),
                              _fieldBox('16 Sell', _k16Sell),
                              _fieldBox('16 New Buy', _k16newBuy),
                              _fieldBox('16 New Sell', _k16newSell),
                              _fieldBox('15 Buy', _k15Buy),
                              _fieldBox('15 Sell', _k15Sell),
                              _fieldBox('15 New Buy', _k15newBuy),
                              _fieldBox('15 New Sell', _k15newSell),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                              key: _sectionKeys[_AdminSection.imageUpload]),
                          TextFormField(
                            controller: _imageUrl,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Image URL (optional)',
                              prefixIcon: Icon(Icons.image_outlined),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _uploadingImage ? null : _uploadImage,
                                  icon: _uploadingImage
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.upload_file_outlined),
                                  label: const Text(
                                      'Upload Image to Supabase Storage'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Save Update'),
                              ),
                            ],
                          ),
                          if (_imageUrl.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _imageUrl.text.trim(),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 180,
                                  alignment: Alignment.center,
                                  color: cs.surfaceContainerHighest,
                                  child: const Text('Image preview မရပါ'),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: _saving ? null : _loadLatest,
                                child: const Text('Reload Latest'),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Signed in: ${widget.email}',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  key: _sectionKeys[_AdminSection.notifications],
                  child: _notificationPanel(),
                ),
                const SizedBox(height: 16),
                Container(
                  key: _sectionKeys[_AdminSection.history],
                  child: _historyManagerPanel(),
                ),
                const SizedBox(height: 16),
                Container(
                  key: _sectionKeys[_AdminSection.settings],
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.onSignOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Signed in: ${widget.email}'),
                    const SizedBox(height: 10),
                    _field('YGEA 16', _ygea16),
                    const SizedBox(height: 10),
                    _field('16 Buy', _k16Buy),
                    const SizedBox(height: 10),
                    _field('16 Sell', _k16Sell),
                    const SizedBox(height: 10),
                    _field('16 New Buy', _k16newBuy),
                    const SizedBox(height: 10),
                    _field('16 New Sell', _k16newSell),
                    const SizedBox(height: 10),
                    _field('15 Buy', _k15Buy),
                    const SizedBox(height: 10),
                    _field('15 Sell', _k15Sell),
                    const SizedBox(height: 10),
                    _field('15 New Buy', _k15newBuy),
                    const SizedBox(height: 10),
                    _field('15 New Sell', _k15newSell),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _imageUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Image URL (optional)',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _uploadingImage ? null : _uploadImage,
                        icon: _uploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: const Text('Upload Image to Supabase Storage'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _loadLatest,
                            child: const Text('Reload Latest'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Save Update'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: widget.onSignOut,
                        child: const Text('Sign Out'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _notificationPanel(),
                    const SizedBox(height: 16),
                    _historyManagerPanel(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuTile(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color:
                selected ? cs.primaryContainer.withValues(alpha: 0.45) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? cs.primary : cs.onSurface),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    bool primary = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: primary ? cs.primaryContainer.withValues(alpha: 0.45) : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
    );
  }

  Widget _fieldBox(String label, TextEditingController c) {
    return SizedBox(
      width: 220,
      child: _field(label, c),
    );
  }

  String _money(int v) {
    final s = v.toString();
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }
}

class _HistoryRow {
  final Object id;
  final GoldPriceLatest price;

  const _HistoryRow({required this.id, required this.price});

  factory _HistoryRow.fromMap(Map<String, dynamic> m) {
    final rawId = m['id'];
    return _HistoryRow(
      id: rawId is num ? rawId.toInt() : (rawId?.toString() ?? ''),
      price: GoldPriceLatest.fromMap(m),
    );
  }
}

enum _AdminSection {
  dashboard,
  priceUpdates,
  notifications,
  imageUpload,
  history,
  settings,
}
