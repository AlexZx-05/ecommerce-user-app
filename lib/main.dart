import 'dart:convert';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String _apiBaseUrlFromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');

String get apiBaseUrl {
  if (_apiBaseUrlFromEnv.isNotEmpty) return _apiBaseUrlFromEnv;
  if (kIsWeb) return 'http://10.163.47.133:5000';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.163.47.133:5000';
  return 'http://localhost:5000';
}

class AppColors {
  static const bg = Color(0xFFF4F6F8);
  static const surface = Colors.white;
  static const primary = Color(0xFF0F766E);
  static const accent = Color(0xFFF59E0B);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const danger = Color(0xFFDC2626);
}

void main() {
  runApp(const UserApp());
}

class UserApp extends StatefulWidget {
  const UserApp({super.key});

  @override
  State<UserApp> createState() => _UserAppState();
}

class _UserAppState extends State<UserApp> {
  String? _token;
  bool _isAdmin = false;

  bool _hasAdminRole(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload is Map<String, dynamic> && payload['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ApnaCart',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE3EA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      home: _token == null
          ? AuthScreen(
              onLoggedIn: (token) => setState(() {
                _token = token;
                _isAdmin = _hasAdminRole(token);
              }),
            )
          : UserHome(
              token: _token!,
              isAdmin: _isAdmin,
              onLogout: () => setState(() {
                _token = null;
                _isAdmin = false;
              }),
            ),
    );
  }
}

class ApiClient {
  ApiClient(this.token);

  final String token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': token,
      };

  Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers,
    );
    return _parseResponse(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parseResponse(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parseResponse(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers,
    );
    return _parseResponse(response);
  }

  dynamic _parseResponse(http.Response response) {
    dynamic body = {};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        final preview = response.body.length > 120 ? '${response.body.substring(0, 120)}...' : response.body;
        throw Exception(
          'Non-JSON response from API (${response.statusCode}). '
          'Check backend URL/server. Response starts with: $preview',
        );
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final msg = body is Map<String, dynamic> ? body['msg'] ?? 'Request failed' : 'Request failed';
    throw Exception(msg);
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onLoggedIn});

  final ValueChanged<String> onLoggedIn;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        final response = await http.post(
          Uri.parse('$apiBaseUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': _emailController.text.trim(),
            'password': _passwordController.text.trim(),
          }),
        );
        final data = jsonDecode(response.body);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(data['msg'] ?? 'Login failed');
        }
        widget.onLoggedIn(data['token']);
      } else {
        final registerResponse = await http.post(
          Uri.parse('$apiBaseUrl/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'password': _passwordController.text.trim(),
            'role': 'user',
          }),
        );
        final registerData = jsonDecode(registerResponse.body);
        if (registerResponse.statusCode < 200 || registerResponse.statusCode >= 300) {
          throw Exception(registerData['msg'] ?? 'Register failed');
        }
        setState(() {
          _isLogin = true;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isLogin ? 'Welcome Back' : 'Create Account';
    final subtitle = _isLogin
        ? 'Sign in to continue shopping smarter.'
        : 'Join now and get a premium shopping experience.';
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 900;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE7FBF5), Color(0xFFF8FAFC)],
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              height: 280,
              width: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF99F6E4).withValues(alpha: 0.45),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              height: 240,
              width: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBFDBFE).withValues(alpha: 0.4),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: isWide ? 6 : 0,
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: isWide ? 28 : 0,
                            bottom: isWide ? 0 : 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppColors.primary,
                                    child: Icon(Icons.bolt, color: Colors.white),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'ApnaCart',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.text,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Smart groceries,\nzero waiting.',
                                style: TextStyle(
                                  fontSize: isWide ? 46 : 40,
                                  height: 1.04,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.text,
                                  letterSpacing: -1.0,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'From daily essentials to instant cravings, delivered in minutes with a premium checkout flow.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 16,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: const [
                                  _HeroPill(icon: Icons.local_shipping_outlined, label: '10-min delivery'),
                                  _HeroPill(icon: Icons.shield_outlined, label: 'Trusted quality'),
                                  _HeroPill(icon: Icons.discount_outlined, label: 'Daily deals'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: isWide ? 5 : 0,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.96, end: 1),
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Card(
                            elevation: 6,
                            shadowColor: const Color(0x1F0F172A),
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: FilledButton(
                                              onPressed: _loading
                                                  ? null
                                                  : () => setState(() {
                                                        _isLogin = true;
                                                        _error = null;
                                                      }),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: _isLogin ? AppColors.primary : Colors.transparent,
                                                foregroundColor: _isLogin ? Colors.white : AppColors.text,
                                                elevation: 0,
                                              ),
                                              child: const Text('Login'),
                                            ),
                                          ),
                                          Expanded(
                                            child: FilledButton(
                                              onPressed: _loading
                                                  ? null
                                                  : () => setState(() {
                                                        _isLogin = false;
                                                        _error = null;
                                                      }),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: !_isLogin ? AppColors.primary : Colors.transparent,
                                                foregroundColor: !_isLogin ? Colors.white : AppColors.text,
                                                elevation: 0,
                                              ),
                                              child: const Text('Register'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE7F6F4),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Trusted by 10k+ shoppers',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(subtitle, style: const TextStyle(color: AppColors.muted)),
                                    const SizedBox(height: 16),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 220),
                                      child: _isLogin
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              key: const ValueKey('name-field'),
                                              padding: const EdgeInsets.only(bottom: 12),
                                              child: TextFormField(
                                                controller: _nameController,
                                                decoration: const InputDecoration(
                                                  labelText: 'Full Name',
                                                  prefixIcon: Icon(Icons.person_outline),
                                                ),
                                                validator: (value) => (value == null || value.trim().isEmpty)
                                                    ? 'Enter name'
                                                    : null,
                                              ),
                                            ),
                                    ),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: Icon(Icons.alternate_email_rounded),
                                      ),
                                      validator: (value) =>
                                          (value == null || !value.contains('@')) ? 'Enter valid email' : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          }),
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (value) =>
                                          (value == null || value.length < 6) ? 'Min 6 characters' : null,
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {},
                                        child: const Text('Forgot password?'),
                                      ),
                                    ),
                                    if (_error != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(color: AppColors.danger),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _loading ? null : _submit,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        icon: Icon(_isLogin ? Icons.login_rounded : Icons.person_add_alt_1),
                                        label: Text(_loading
                                            ? 'Please wait...'
                                            : _isLogin
                                                ? 'Continue to App'
                                                : 'Create Account'),
                                      ),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9E2EC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class UserHome extends StatefulWidget {
  const UserHome({super.key, required this.token, required this.isAdmin, required this.onLogout});

  final String token;
  final bool isAdmin;
  final VoidCallback onLogout;

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _index = 0;
  Map<String, dynamic>? _profile;
  bool _profileLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiClient(widget.token).get('/api/user/me');
      if (!mounted) return;
      setState(() {
        _profile = data as Map<String, dynamic>;
        _profileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
      });
    }
  }

  String get _displayName {
    final name = '${_profile?['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return 'Guest User';
  }

  String get _displayEmail {
    final email = '${_profile?['email'] ?? ''}'.trim();
    if (email.isNotEmpty) return email;
    return 'No email';
  }

  String get _roleLabel {
    final role = '${_profile?['role'] ?? 'user'}'.trim().toLowerCase();
    if (role == 'admin') return 'Administrator';
    if (role == 'delivery') return 'Delivery Partner';
    return 'Customer';
  }

  String get _initials {
    final parts = _displayName.split(' ').where((e) => e.trim().isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  Widget _drawerHeader() {
    if (_profileLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B7E77), Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -34,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'ApnaCart',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                  ),
                ],
              ),
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _displayEmail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _roleLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerNavTile({
    required IconData icon,
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: active ? const Color(0xFFE7F6F4) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? const Color(0xFFBCE6DF) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: active ? AppColors.primary : const Color(0xFF334155)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: active ? AppColors.primary : AppColors.text,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (active)
                    const Icon(Icons.chevron_right, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(widget.token);
    final pages = [
      ProductsTab(api: api),
      CartTab(api: api),
      OrdersTab(api: api),
    ];
    final titles = ['ApnaCart', 'My Cart', 'My Orders'];

    return Scaffold(
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.86,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(26)),
        ),
        child: Container(
          color: const Color(0xFFF7FBFA),
          child: Column(
            children: [
              _drawerHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 6, bottom: 8),
                        child: Text(
                          'Browse',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      _drawerNavTile(
                        icon: Icons.storefront_outlined,
                        title: 'Products',
                        active: _index == 0,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _index = 0;
                          });
                        },
                      ),
                      _drawerNavTile(
                        icon: Icons.shopping_cart_outlined,
                        title: 'Cart',
                        active: _index == 1,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _index = 1;
                          });
                        },
                      ),
                      _drawerNavTile(
                        icon: Icons.local_shipping_outlined,
                        title: 'Orders',
                        active: _index == 2,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _index = 2;
                          });
                        },
                      ),
                      if (widget.isAdmin) ...[
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(left: 6, bottom: 8, top: 4),
                          child: Text(
                            'Admin Controls',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        _drawerNavTile(
                          icon: Icons.insights_outlined,
                          title: 'Admin Dashboard',
                          active: false,
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AdminDashboardPage(api: api)),
                            );
                          },
                        ),
                        _drawerNavTile(
                          icon: Icons.admin_panel_settings_outlined,
                          title: 'Admin Products',
                          active: false,
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AdminProductsPage(api: api)),
                            );
                          },
                        ),
                        _drawerNavTile(
                          icon: Icons.assignment_outlined,
                          title: 'Admin Orders',
                          active: false,
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AdminOrdersPage(api: api)),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout, color: AppColors.danger),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF1F2),
                      foregroundColor: AppColors.text,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        toolbarHeight: 86,
        leadingWidth: 74,
        leading: Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(left: 14, top: 14, bottom: 12),
            child: Material(
              color: const Color(0xFFE7F6F4),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Scaffold.of(context).openDrawer(),
                child: const Center(
                  child: Icon(Icons.menu_rounded, color: AppColors.primary, size: 24),
                ),
              ),
            ),
          ),
        ),
        titleSpacing: 6,
        title: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                titles[_index],
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    height: 6,
                    width: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _profileLoading ? 'Loading profile...' : _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 14, bottom: 12),
            child: Row(
              children: [
                Builder(
                  builder: (innerContext) => Material(
                    color: const Color(0xFFE7F6F4),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Scaffold.of(innerContext).openDrawer(),
                      child: SizedBox(
                        height: 42,
                        width: 42,
                        child: Center(
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: widget.onLogout,
                    child: const SizedBox(
                      height: 42,
                      width: 42,
                      child: Icon(Icons.logout_rounded, color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7FBFA), Color(0xFFF1F7F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: pages[_index],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            backgroundColor: Colors.white,
            elevation: 0,
            height: 74,
            selectedIndex: _index,
            indicatorColor: const Color(0xFFD8F2EE),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (value) => setState(() {
              _index = value;
            }),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Products',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_cart_outlined),
                selectedIcon: Icon(Icons.shopping_cart_rounded),
                label: 'Cart',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping_rounded),
                label: 'Orders',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  String _range = 'day';

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
      final data = await widget.api.get('/api/admin/analytics');
      if (!mounted) return;
      setState(() {
        _data = data as Map<String, dynamic>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  String _money(dynamic value) => 'Rs ${_asDouble(value).toStringAsFixed(0)}';

  Map<String, dynamic> get _totals => (_data?['totals'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> get _currentSales {
    final map = (_data?['currentSales'] as Map<String, dynamic>?) ?? {};
    return (map[_range] as Map<String, dynamic>?) ?? {};
  }

  List<dynamic> get _trend {
    final trends = (_data?['trends'] as Map<String, dynamic>?) ?? {};
    return (trends[_range] as List<dynamic>?) ?? const [];
  }

  List<dynamic> get _recentOrders => (_data?['recentOrders'] as List<dynamic>?) ?? const [];

  String get _rangeLabel {
    switch (_range) {
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      case 'year':
        return 'This Year';
      default:
        return 'Today';
    }
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 10),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final maxTrendRevenue = _trend.fold<double>(0, (max, item) {
      final map = item as Map<String, dynamic>;
      final value = _asDouble(map['revenue']);
      return value > max ? value : max;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Sales Dashboard'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF22C55E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _rangeLabel,
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _money(_currentSales['revenue']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Orders: ${_asInt(_currentSales['orders'])}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Day'),
                  selected: _range == 'day',
                  onSelected: (_) => setState(() => _range = 'day'),
                ),
                ChoiceChip(
                  label: const Text('Week'),
                  selected: _range == 'week',
                  onSelected: (_) => setState(() => _range = 'week'),
                ),
                ChoiceChip(
                  label: const Text('Month'),
                  selected: _range == 'month',
                  onSelected: (_) => setState(() => _range = 'month'),
                ),
                ChoiceChip(
                  label: const Text('Year'),
                  selected: _range == 'year',
                  onSelected: (_) => setState(() => _range = 'year'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _kpiCard(
                  title: 'Total Revenue',
                  value: _money(_totals['revenue']),
                  icon: Icons.currency_rupee_rounded,
                  color: const Color(0xFF0F766E),
                ),
                _kpiCard(
                  title: 'All Orders',
                  value: '${_asInt(_totals['orders'])}',
                  icon: Icons.shopping_bag_outlined,
                  color: const Color(0xFF1D4ED8),
                ),
                _kpiCard(
                  title: 'Delivered',
                  value: '${_asInt(_totals['deliveredOrders'])}',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF166534),
                ),
                _kpiCard(
                  title: 'Cancelled',
                  value: '${_asInt(_totals['cancelledOrders'])}',
                  icon: Icons.cancel_outlined,
                  color: AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sales Trend',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    if (_trend.isEmpty)
                      const Text('No sales data available for this period.')
                    else
                      for (final item in _trend)
                        Builder(
                          builder: (context) {
                            final map = item as Map<String, dynamic>;
                            final revenue = _asDouble(map['revenue']);
                            final orders = _asInt(map['orders']);
                            final ratio = maxTrendRevenue <= 0 ? 0.0 : (revenue / maxTrendRevenue).clamp(0.0, 1.0);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${map['label'] ?? '-'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${_money(revenue)} | $orders orders',
                                        style: const TextStyle(
                                          color: AppColors.muted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      minHeight: 8,
                                      value: ratio,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Previous Orders',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    if (_recentOrders.isEmpty)
                      const Text('No recent orders.')
                    else
                      for (final raw in _recentOrders.take(12))
                        Builder(
                          builder: (context) {
                            final order = raw as Map<String, dynamic>;
                            final orderId = '${order['_id'] ?? ''}';
                            final shortId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
                            final customer = (order['user'] as Map<String, dynamic>?) ?? {};
                            final name = '${customer['name'] ?? 'Unknown'}';
                            final createdAt = DateTime.tryParse('${order['createdAt'] ?? ''}');
                            final dateLabel = createdAt == null
                                ? '-'
                                : '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    height: 38,
                                    width: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE7F6F4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Order #$shortId',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$name | $dateLabel',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: AppColors.muted),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Status: ${order['orderStatus'] ?? 'placed'} | Payment: ${order['paymentStatus'] ?? 'pending'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _money(order['totalAmount']),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _products = const [];
  String _query = '';
  String _selectedCategory = 'All';

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
      final data = await widget.api.get('/api/products');
      setState(() {
        _products = data as List<dynamic>;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<String> get _categories {
    final values = <String>{'All'};
    for (final item in _products) {
      final map = item as Map<String, dynamic>;
      final category = '${map['category'] ?? ''}'.trim();
      if (category.isNotEmpty) values.add(category);
    }
    final sorted = values.where((e) => e != 'All').toList()..sort();
    return ['All', ...sorted];
  }

  int get _totalStock {
    var sum = 0;
    for (final item in _products) {
      final map = item as Map<String, dynamic>;
      sum += int.tryParse('${map['stock'] ?? 0}') ?? 0;
    }
    return sum;
  }

  List<dynamic> get _visibleProducts {
    final q = _query.trim().toLowerCase();
    return _products.where((item) {
      final map = item as Map<String, dynamic>;
      final category = '${map['category'] ?? ''}';
      if (_selectedCategory != 'All' && category != _selectedCategory) return false;
      if (q.isEmpty) return true;
      final name = '${map['name'] ?? ''}'.toLowerCase();
      return name.contains(q) || category.toLowerCase().contains(q);
    }).toList();
  }

  String _toDataUrl(Uint8List bytes, String ext) {
    final normalized = ext.toLowerCase();
    final mime = switch (normalized) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/png',
    };
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  Future<void> _pickImageToController(TextEditingController imageController, ValueNotifier<String> imageValue) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;
    final ext = (file.extension ?? 'png').toLowerCase();
    final dataUrl = _toDataUrl(bytes, ext);
    imageController.text = dataUrl;
    imageValue.value = dataUrl;
  }

  Future<void> _openEditor({Map<String, dynamic>? product}) async {
    final nameController = TextEditingController(text: product?['name']?.toString() ?? '');
    final descriptionController = TextEditingController(text: product?['description']?.toString() ?? '');
    final categoryController = TextEditingController(text: product?['category']?.toString() ?? 'General');
    final priceController = TextEditingController(text: '${product?['price'] ?? ''}');
    final stockController = TextEditingController(text: '${product?['stock'] ?? ''}');
    final imageController = TextEditingController(text: product?['image']?.toString() ?? '');
    final imageValue = ValueNotifier<String>(imageController.text.trim());
    final formKey = GlobalKey<FormState>();
    final isEdit = product != null;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Product' : 'Add Product'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Name required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Category required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          (num.tryParse((value ?? '').trim()) == null) ? 'Enter valid price' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: stockController,
                      decoration: const InputDecoration(labelText: 'Quantity/Stock'),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          (int.tryParse((value ?? '').trim()) == null) ? 'Enter valid stock' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: imageController,
                      decoration: const InputDecoration(labelText: 'Photo URL'),
                      onChanged: (value) {
                        imageValue.value = value.trim();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickImageToController(imageController, imageValue),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Upload From Device'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<String>(
                      valueListenable: imageValue,
                      builder: (context, value, _) {
                        if (value.isEmpty) return const SizedBox.shrink();
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            value,
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 70,
                              alignment: Alignment.center,
                              color: const Color(0xFFF1F5F9),
                              child: const Text('Invalid image URL / data'),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return;

    final body = <String, dynamic>{
      'name': nameController.text.trim(),
      'description': descriptionController.text.trim(),
      'price': num.parse(priceController.text.trim()),
      'category': categoryController.text.trim(),
      'stock': int.parse(stockController.text.trim()),
      'image': imageController.text.trim(),
    };

    try {
      if (isEdit) {
        await widget.api.put('/api/products/${product['_id']}', body);
      } else {
        await widget.api.post('/api/products/create', body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Product updated' : 'Product created')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteProduct(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.delete('/api/products/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _changeStock(Map<String, dynamic> product, int delta) async {
    final currentStock = int.tryParse('${product['stock'] ?? 0}') ?? 0;
    final nextStock = currentStock + delta;
    if (nextStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock cannot be negative')),
      );
      return;
    }

    final body = <String, dynamic>{
      'name': '${product['name'] ?? ''}',
      'description': '${product['description'] ?? ''}',
      'price': num.tryParse('${product['price'] ?? 0}') ?? 0,
      'category': '${product['category'] ?? ''}',
      'stock': nextStock,
      'image': '${product['image'] ?? ''}',
    };

    try {
      await widget.api.put('/api/products/${product['_id']}', body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock updated to $nextStock')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _visibleProducts;
    final categories = _categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Product Studio'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New Product'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF22C55E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Inventory Control',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_products.length} products live | $_totalStock total stock',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Sync'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: TextField(
                        onChanged: (value) => setState(() {
                          _query = value;
                        }),
                        decoration: const InputDecoration(
                          hintText: 'Search product or category...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 46,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final selected = category == _selectedCategory;
                          return ChoiceChip(
                            label: Text(category),
                            selected: selected,
                            onSelected: (_) => setState(() {
                              _selectedCategory = category;
                            }),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: filtered.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 60),
                                  Center(child: Text('No products matched your filter')),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final product = filtered[index] as Map<String, dynamic>;
                                  final imageUrl = '${product['image'] ?? ''}'.trim();
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: imageUrl.isNotEmpty
                                                    ? Image.network(
                                                        imageUrl,
                                                        width: 52,
                                                        height: 52,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) =>
                                                            const Icon(Icons.inventory_2_outlined, size: 36),
                                                      )
                                                    : const Icon(Icons.inventory_2_outlined, size: 36),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${product['name'] ?? ''}',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 17,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFE2E8F0),
                                                            borderRadius: BorderRadius.circular(999),
                                                          ),
                                                          child: Text('${product['category'] ?? 'General'}'),
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFDCFCE7),
                                                            borderRadius: BorderRadius.circular(999),
                                                          ),
                                                          child: Text('Qty ${product['stock'] ?? 0}'),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert),
                                                onSelected: (value) {
                                                  if (value == 'edit') _openEditor(product: product);
                                                  if (value == 'delete') _deleteProduct('${product['_id']}');
                                                },
                                                itemBuilder: (context) => const [
                                                  PopupMenuItem(value: 'edit', child: Text('Edit Product')),
                                                  PopupMenuItem(value: 'delete', child: Text('Delete Product')),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Text(
                                                'Rs ${product['price'] ?? 0}',
                                                style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const Spacer(),
                                              OutlinedButton.icon(
                                                onPressed: () => _changeStock(product, -1),
                                                icon: const Icon(Icons.remove),
                                                label: const Text('Minus'),
                                              ),
                                              const SizedBox(width: 8),
                                              FilledButton.icon(
                                                onPressed: () => _changeStock(product, 1),
                                                icon: const Icon(Icons.add),
                                                label: const Text('Add'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _orders = const [];
  List<dynamic> _deliveryUsers = const [];
  static const List<String> _statuses = [
    'placed',
    'packed',
    'shipped',
    'picked',
    'on-the-way',
    'delivered',
  ];

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
      final results = await Future.wait([
        widget.api.get('/api/admin/orders'),
        widget.api.get('/api/admin/delivery-boys'),
      ]);
      setState(() {
        _orders = results[0] as List<dynamic>;
        _deliveryUsers = results[1] as List<dynamic>;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _shortOrderId(dynamic idValue) {
    final id = '$idValue';
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      await widget.api.put('/api/admin/order/status/$orderId', {'status': status});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status set to $status')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _assignDelivery(String orderId, String deliveryBoyId) async {
    try {
      await widget.api.put('/api/admin/order/assign/$orderId', {'deliveryBoyId': deliveryBoyId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery user assigned')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('This will cancel order and restore stock. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.put('/api/admin/order/cancel/$orderId', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Orders Panel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index] as Map<String, dynamic>;
                      final orderId = '${order['_id'] ?? ''}';
                      final user = order['user'] as Map<String, dynamic>?;
                      final assigned = order['assignedDeliveryBoy'] as Map<String, dynamic>?;
                      final currentStatus = '${order['orderStatus'] ?? 'placed'}';
                      final currentDeliveryId = assigned?['_id']?.toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #${_shortOrderId(orderId)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text('Customer: ${user?['name'] ?? 'Unknown'} (${user?['email'] ?? '-'})'),
                              const SizedBox(height: 4),
                              Text(
                                'Amount: Rs ${order['totalAmount'] ?? 0} | Payment: ${order['paymentStatus'] ?? 'pending'}',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _statuses.contains(currentStatus) ? currentStatus : _statuses.first,
                                      items: _statuses
                                          .map(
                                            (value) => DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null || value == currentStatus) return;
                                        _updateStatus(orderId, value);
                                      },
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text('Delivery: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: currentDeliveryId,
                                      items: _deliveryUsers
                                          .map(
                                            (entry) => DropdownMenuItem<String>(
                                              value: '${entry['_id']}',
                                              child: Text('${entry['name']} (${entry['email']})'),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null || value == currentDeliveryId) return;
                                        _assignDelivery(orderId, value);
                                      },
                                      decoration: const InputDecoration(
                                        hintText: 'Assign delivery user',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () => _cancelOrder(orderId),
                                  icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                                  label: const Text('Cancel Order'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key, required this.api});

  final ApiClient api;

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  bool _loading = true;
  String? _error;
  List<dynamic> _products = const [];
  String _searchInput = '';
  String _searchQuery = '';
  String _selectedCategory = 'All';
  Timer? _searchDebounce;
  final PageController _bannerController = PageController(viewportFraction: 1);
  Timer? _bannerTimer;
  int _bannerIndex = 0;
  static const List<Map<String, String>> _banners = [
    {
      'title': 'Super Saver Deals',
      'subtitle': 'Fast delivery. Better prices. Premium experience.',
      'offer': 'Flat 20% OFF',
      'tag': 'Use: SAVE20',
    },
    {
      'title': 'Fresh Arrival Picks',
      'subtitle': 'Daily farm-fresh essentials, handpicked for you.',
      'offer': 'Buy 2 Get 1',
      'tag': 'On Fruits',
    },
    {
      'title': 'Weekend Mega Offers',
      'subtitle': 'Extra savings on groceries, dairy, fruits and more.',
      'offer': 'Up to Rs 150 OFF',
      'tag': 'Orders above Rs 999',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startBannerAutoScroll();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final next = (_bannerIndex + 1) % _banners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
      setState(() {
        _bannerIndex = next;
      });
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get('/api/products');
      setState(() {
        _products = data as List<dynamic>;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<String> get _categories {
    final values = <String>{'All'};
    for (final item in _products) {
      final map = item as Map<String, dynamic>;
      final category = '${map['category'] ?? ''}'.trim();
      if (category.isNotEmpty) values.add(category);
    }
    final list = values.toList();
    if (list.length > 1) {
      final rest = list.where((e) => e != 'All').toList()..sort();
      return ['All', ...rest];
    }
    return list;
  }

  List<dynamic> get _visibleProducts {
    final query = _searchQuery.trim().toLowerCase();
    return _products.where((item) {
      final map = item as Map<String, dynamic>;
      final category = '${map['category'] ?? ''}';
      if (_selectedCategory != 'All' && category != _selectedCategory) return false;
      if (query.isEmpty) return true;
      final name = '${map['name'] ?? ''}'.toLowerCase();
      final description = '${map['description'] ?? ''}'.toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchInput = value;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchInput;
      });
    });
  }

  Future<void> _addToCart(String productId) async {
    try {
      await widget.api.post('/api/cart/add', {'productId': productId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to cart')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filtered = _visibleProducts;
    final categories = _categories;
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1400 ? 5 : width >= 1100 ? 4 : width >= 800 ? 3 : 2;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    height: 130,
                    child: PageView.builder(
                      controller: _bannerController,
                      itemCount: _banners.length,
                      onPageChanged: (index) {
                        setState(() {
                          _bannerIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final banner = _banners[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F766E), Color(0xFF22C55E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      banner['offer'] ?? '',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      banner['tag'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                banner['title'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                banner['subtitle'] ?? '',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _banners.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: _bannerIndex == index ? 20 : 6,
                        decoration: BoxDecoration(
                          color: _bannerIndex == index ? AppColors.primary : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search products, brands, categories...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchInput.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => _onSearchChanged(''),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final selected = category == _selectedCategory;
                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _selectedCategory = category;
                    }),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: selected ? AppColors.primary : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ),
          if (_products.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No products found in database yet.'),
                  ),
                ),
              ),
            ),
          if (_products.isNotEmpty && filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.search_off, size: 36, color: AppColors.muted),
                        const SizedBox(height: 8),
                        const Text('No products matched your filters.'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _searchInput = '';
                            _searchQuery = '';
                            _selectedCategory = 'All';
                          }),
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (filtered.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverGrid.builder(
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 268,
                ),
                itemBuilder: (context, index) {
                  final product = filtered[index] as Map<String, dynamic>;
                  final priceValue = num.tryParse('${product['price'] ?? 0}') ?? 0;
                  final stockValue = num.tryParse('${product['stock'] ?? 0}') ?? 0;
                  final inStock = stockValue > 0;
                  final imageUrl = '${product['image'] ?? ''}'.trim();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 88,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F6F4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder: (context, error, stackTrace) => const Center(
                                            child: Icon(
                                              Icons.inventory_2_outlined,
                                              size: 34,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.inventory_2_outlined,
                                            size: 34,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Deal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${product['name'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${product['category'] ?? 'General'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Rs ${priceValue.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: inStock ? () => _addToCart('${product['_id']}') : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(80, 38),
                                ),
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: inStock ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              inStock ? 'In stock: ${stockValue.toInt()}' : 'Out of stock',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: inStock ? const Color(0xFF166534) : AppColors.danger,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class CartTab extends StatefulWidget {
  const CartTab({super.key, required this.api});

  final ApiClient api;

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  bool _loading = true;
  String? _error;
  List<dynamic> _items = const [];
  List<dynamic> _addresses = const [];
  String? _selectedAddressId;

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
      final cart = await widget.api.get('/api/cart');
      final addresses = await widget.api.get('/api/address');
      setState(() {
        _items = (cart['items'] ?? []) as List<dynamic>;
        _addresses = addresses as List<dynamic>;
        if (_addresses.isNotEmpty) {
          _selectedAddressId ??= _addresses.first['_id'];
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateQuantity(String productId, int quantity) async {
    if (quantity < 1) return;
    await widget.api.put('/api/cart/update', {'productId': productId, 'quantity': quantity});
    _load();
  }

  Future<void> _remove(String productId) async {
    await widget.api.delete('/api/cart/remove/$productId');
    _load();
  }

  Future<void> _addAddress() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final lineController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();
    final pinController = TextEditingController();
    final latController = TextEditingController(text: '15.6235');
    final lngController = TextEditingController(text: '76.9048');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Address'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
                TextField(controller: lineController, decoration: const InputDecoration(labelText: 'Address Line')),
                TextField(controller: cityController, decoration: const InputDecoration(labelText: 'City')),
                TextField(controller: stateController, decoration: const InputDecoration(labelText: 'State')),
                TextField(controller: pinController, decoration: const InputDecoration(labelText: 'Pincode')),
                TextField(controller: latController, decoration: const InputDecoration(labelText: 'Latitude')),
                TextField(controller: lngController, decoration: const InputDecoration(labelText: 'Longitude')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        );
      },
    );

    if (saved != true) return;
    await widget.api.post('/api/address/add', {
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'addressLine': lineController.text.trim(),
      'city': cityController.text.trim(),
      'state': stateController.text.trim(),
      'pincode': pinController.text.trim(),
      'landmark': '',
      'location': {
        'lat': double.tryParse(latController.text.trim()) ?? 0,
        'lng': double.tryParse(lngController.text.trim()) ?? 0,
      },
    });
    _load();
  }

  Future<void> _placeOrder() async {
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add and select an address first')),
      );
      return;
    }
    await widget.api.post('/api/order/create', {'addressId': _selectedAddressId});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed')),
      );
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final total = _items.fold<double>(0, (sum, item) {
      final product = item['product'] as Map<String, dynamic>? ?? {};
      final price = num.tryParse('${product['price'] ?? 0}')?.toDouble() ?? 0;
      final qty = num.tryParse('${item['quantity'] ?? 0}')?.toDouble() ?? 0;
      return sum + (price * qty);
    });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF22C55E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checkout Zone',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Review items, select address, and place your order.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Container(
                      height: 64,
                      width: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F6F4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.remove_shopping_cart_outlined, color: AppColors.primary, size: 30),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your cart is empty',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add products from the discover tab to continue.',
                      style: TextStyle(color: AppColors.muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          for (final item in _items)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F6F4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['product']?['name'] ?? 'Item').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rs ${item['product']?['price'] ?? 0}',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _updateQuantity(item['product']['_id'], item['quantity'] - 1),
                            icon: const Icon(Icons.remove, color: AppColors.primary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                            visualDensity: VisualDensity.compact,
                          ),
                          Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          IconButton(
                            onPressed: () => _updateQuantity(item['product']['_id'], item['quantity'] + 1),
                            icon: const Icon(Icons.add, color: AppColors.primary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _remove(item['product']['_id']),
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Delivery Address',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 17),
          ),
          const SizedBox(height: 8),
          if (_addresses.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('No address found', style: TextStyle(color: AppColors.muted)),
            ),
          if (_addresses.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _selectedAddressId,
              items: _addresses
                  .map(
                    (address) => DropdownMenuItem<String>(
                      value: address['_id'],
                      child: Text('${address['name']} - ${address['city']}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedAddressId = value;
              }),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _addAddress,
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Add Address'),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total', style: TextStyle(color: AppColors.muted)),
                  Text(
                    'Rs ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _items.isEmpty ? null : _placeOrder,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Place Order'),
            ),
          ),
        ],
      ),
    );
  }
}

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key, required this.api});

  final ApiClient api;

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  bool _loading = true;
  String? _error;
  List<dynamic> _orders = const [];

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value.contains('delivered')) return const Color(0xFF166534);
    if (value.contains('cancel')) return AppColors.danger;
    if (value.contains('ship') || value.contains('out')) return const Color(0xFF1D4ED8);
    return const Color(0xFF92400E);
  }

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
      final orders = await widget.api.get('/api/order/my');
      setState(() {
        _orders = orders as List<dynamic>;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index] as Map<String, dynamic>;
          final location = order['trackingLocation'] as Map<String, dynamic>?;
          final status = '${order['orderStatus'] ?? 'Pending'}';
          final statusColor = _statusColor(status);
          final orderId = '${order['_id'] ?? ''}';
          final shortOrderId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #$shortOrderId',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${order['paymentStatus'] ?? 'Unpaid'}',
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Amount: Rs ${order['totalAmount'] ?? 0}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  if (location != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Live Location: ${location['lat']}, ${location['lng']}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
