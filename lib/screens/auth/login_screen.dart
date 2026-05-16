import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_input_field.dart';
import '../../widgets/floating_orbs_background.dart';
import '../../widgets/gradient_button.dart';
import '../main_shell.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Email
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _emailLoading = false;

  // Phone
  final _countryCtrl = TextEditingController(text: '+91');
  final _phoneCtrl = TextEditingController();
  bool _phoneLoading = false;

  // Google
  bool _googleLoading = false;

  // Guest
  bool _guestLoading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _countryCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      _showSnack('Please fill in all fields');
      return;
    }
    setState(() => _emailLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signInWithEmail(email: email, password: pass);
      if (!mounted) return;
      _goHome();
    } catch (e) {
      _showSnack(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  Future<void> _sendOTP() async {
    final code = _countryCtrl.text.trim();
    final number = _phoneCtrl.text.trim();
    if (number.isEmpty) {
      _showSnack('Please enter your phone number');
      return;
    }
    final full = '$code$number';
    setState(() => _phoneLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      await auth.sendOTP(
        phoneNumber: full,
        onVerificationCompleted: (_) {},
        onVerificationFailed: (e) {
          _showSnack(e.message ?? 'Verification failed');
          setState(() => _phoneLoading = false);
        },
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() => _phoneLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                phoneNumber: full,
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            ),
          );
        },
        onCodeAutoRetrievalTimeout: (_) {
          if (mounted) setState(() => _phoneLoading = false);
        },
      );
    } catch (e) {
      _showSnack(_friendlyError(e.toString()));
      setState(() => _phoneLoading = false);
    }
  }

  Future<void> _signInGuest() async {
    setState(() => _guestLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signInAnonymously();
      if (!mounted) return;
      _goHome();
    } catch (e) {
      _showSnack(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _guestLoading = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final user = await auth.signInWithGoogle();
      if (!mounted) return;
      if (user != null) _goHome();
    } catch (e) {
      _showSnack(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential') ||
        raw.contains('INVALID_LOGIN_CREDENTIALS') ||
        raw.contains('auth credential is incorrect')) {
      return 'Invalid email or password';
    }
    if (raw.contains('invalid-email')) { return 'Invalid email address'; }
    if (raw.contains('user-disabled')) {
      return 'This account has been disabled.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (raw.contains('network')) {
      return 'Network error. Check your connection.';
    }
    if (raw.contains('BILLING_NOT_ENABLED') ||
        raw.contains('billing-not-enabled')) {
      return 'Phone sign-in requires Firebase billing to be enabled. Please upgrade your Firebase project to Blaze plan.';
    }
    if (raw.contains('invalid-phone-number')) {
      return 'Invalid phone number. Include country code (e.g. +91).';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FloatingOrbsBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: AppTheme.accentGradient,
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppTheme.gradientMid.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt,
                        size: 52, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        AppTheme.accentGradient.createShader(bounds),
                    child: Text(
                      'Welcome to UniTrend',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                const SizedBox(height: 32),

                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicator: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    tabs: const [
                      Tab(text: 'Email'),
                      Tab(text: 'Phone'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 280,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _EmailTab(
                        emailCtrl: _emailCtrl,
                        passCtrl: _passCtrl,
                        obscure: _obscure,
                        onToggleObscure: () =>
                            setState(() => _obscure = !_obscure),
                        onSignIn: _signInEmail,
                        loading: _emailLoading,
                      ),
                      _PhoneTab(
                        countryCtrl: _countryCtrl,
                        phoneCtrl: _phoneCtrl,
                        onSendOTP: _sendOTP,
                        loading: _phoneLoading,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // OR divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              )),
                    ),
                    Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
                  ],
                ),
                const SizedBox(height: 16),

                // Google Sign-In button
                OutlinedButton(
                  onPressed: _googleLoading ? null : _signInGoogle,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: _googleLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _GoogleLogo(),
                            const SizedBox(width: 10),
                            Text('Continue with Google',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                ),
                const SizedBox(height: 12),

                // Guest button
                TextButton(
                  onPressed: _guestLoading ? null : _signInGuest,
                  child: _guestLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary),
                        )
                      : Text(
                          'Continue as Guest',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            )),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignupScreen()),
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.accentGradient.createShader(bounds),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
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
    );
  }
}

// ── Google logo ───────────────────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    );
  }
}

// ── Email tab ────────────────────────────────────────────────────────────────

class _EmailTab extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSignIn;
  final bool loading;

  const _EmailTab({
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSignIn,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedInputField(
          controller: emailCtrl,
          labelText: 'Email',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        AnimatedInputField(
          controller: passCtrl,
          labelText: 'Password',
          prefixIcon: Icons.lock_outlined,
          obscureText: obscure,
          suffixIcon: IconButton(
            icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20),
            onPressed: onToggleObscure,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen()),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.accentGradient.createShader(bounds),
              child: const Text('Forgot password?',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        GradientButton(
          onPressed: loading ? null : onSignIn,
          loading: loading,
          child: const Text('Sign In'),
        ),
      ],
    );
  }
}

// ── Phone tab ────────────────────────────────────────────────────────────────

class _PhoneTab extends StatelessWidget {
  final TextEditingController countryCtrl;
  final TextEditingController phoneCtrl;
  final VoidCallback onSendOTP;
  final bool loading;

  const _PhoneTab({
    required this.countryCtrl,
    required this.phoneCtrl,
    required this.onSendOTP,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 90,
              child: AnimatedInputField(
                controller: countryCtrl,
                labelText: 'Code',
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedInputField(
                controller: phoneCtrl,
                labelText: 'Phone number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'We\'ll send a one-time code to verify your number.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        GradientButton(
          onPressed: loading ? null : onSendOTP,
          loading: loading,
          child: const Text('Send OTP'),
        ),
      ],
    );
  }
}
