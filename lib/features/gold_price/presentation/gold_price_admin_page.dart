import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mmgold/shared/supabase/supabase_provider.dart';
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

  bool _loading = true;
  bool _saving = false;
  bool _uploadingImage = false;

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
  }

  @override
  void dispose() {
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
    super.dispose();
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ဈေး update အောင်မြင်ပါသည်')),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

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
                    if (_imageUrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _imageUrl.text.trim(),
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 140,
                            alignment: Alignment.center,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: const Text('Image preview မရပါ'),
                          ),
                        ),
                      ),
                    ],
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
