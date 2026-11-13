import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/section_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _editing = false;

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/profile');
      final data = res['data'];
      setState(() {
        _profile = data;
        _nameController.text = data['full_name'] ?? '';
        _locationController.text = data['location'] ?? '';
        _stateController.text = data['state'] ?? '';
        _districtController.text = data['district'] ?? '';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.put('/profile', {
        'full_name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'state': _stateController.text.trim(),
        'district': _districtController.text.trim(),
      });
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              icon: Icon(_editing ? Icons.close : Icons.edit_outlined),
              onPressed: () => setState(() => _editing = !_editing),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorRetryView(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const CircleAvatar(radius: 36, backgroundColor: AppColors.lightGreen, child: Icon(Icons.person, size: 40, color: AppColors.primaryGreen)),
                          const SizedBox(height: 10),
                          Text(_profile!['full_name'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                          Text(_profile!['email'] ?? _profile!['mobile'] ?? '', style: const TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionCard(
                      title: 'Details',
                      icon: Icons.badge_outlined,
                      child: _editing
                          ? Column(
                              children: [
                                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full name')),
                                const SizedBox(height: 10),
                                TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Location')),
                                const SizedBox(height: 10),
                                TextField(controller: _stateController, decoration: const InputDecoration(labelText: 'State')),
                                const SizedBox(height: 10),
                                TextField(controller: _districtController, decoration: const InputDecoration(labelText: 'District')),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _save,
                                    child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _detailRow('Location', _profile!['location']),
                                _detailRow('State', _profile!['state']),
                                _detailRow('District', _profile!['district']),
                                _detailRow('Farm size', '${_profile!['total_farm_size_acres'] ?? 0} acres'),
                                _detailRow('Preferred language', _profile!['preferred_language']),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          await context.read<AuthProvider>().logout();
                          if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                        },
                        child: const Text('Log Out'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AppColors.textMuted))),
          Expanded(child: Text('${value ?? '—'}')),
        ],
      ),
    );
  }
}
