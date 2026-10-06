import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/brand/brand.dart';
import '../application/auth_cubit.dart';
import '../application/login_cubit.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginCubit(
        context.read<AuthRepository>(),
        context.read<AuthCubit>(),
      ),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submit(
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    // The brand band paints edge to edge behind the status bar.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: BrandColors.brandGradient,
                ),
                child: _BrandBand(
                  screenHeight: MediaQuery.sizeOf(context).height,
                ),
              ),
              // The form sheet overlaps the band so its rounded corners sit
              // on the brand colour.
              Transform.translate(
                offset: const Offset(0, -_overlap),
                child: const _FormPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const double _overlap = 28;

/// Violet identity band: logo, wordmark, and what the app is for.
class _BrandBand extends StatelessWidget {
  const _BrandBand({required this.screenHeight});

  /// Taller phones get more room above so the form sits in thumb reach.
  final double screenHeight;

  bool get compact => screenHeight < 640;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          28,
          (screenHeight * 0.09).clamp(20, 96),
          28,
          24 + _overlap,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    Brand.iconAsset,
                    width: 44,
                    height: 44,
                    semanticLabel: '${Brand.name} logo',
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Brand.name,
                  style: text.titleMedium?.copyWith(
                    color: BrandColors.offWhite,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 20 : 36),
            Text(
              'Your workday,\nin one place.',
              style: text.headlineMedium?.copyWith(
                color: BrandColors.offWhite,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Clock in, request leave, and follow approvals.',
              style: text.bodyMedium?.copyWith(
                color: BrandColors.offWhite.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form sheet that overlaps the band with rounded top corners.
class _FormPanel extends StatelessWidget {
  const _FormPanel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: _LoginForm(),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_LoginViewState>()!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sessionExpired = context.select(
      (AuthCubit cubit) => cubit.state.sessionExpired,
    );

    return BlocBuilder<LoginCubit, LoginState>(
      builder: (context, login) {
        return AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign in to your account',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Use the work email registered by your HR team.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: login.error != null
                    ? _Banner(
                        icon: Icons.error_outline,
                        message: login.error!,
                        tone: _BannerTone.error,
                      )
                    : sessionExpired
                        ? const _Banner(
                            icon: Icons.schedule,
                            message:
                                'Your session has ended. Sign in again to continue.',
                            tone: _BannerTone.info,
                          )
                        : const SizedBox(width: double.infinity),
              ),
              TextField(
                key: const Key('login.email'),
                controller: state._email,
                enabled: !login.submitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => context.read<LoginCubit>().clearError(),
                onSubmitted: (_) => state._passwordFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Work email',
                  hintText: 'name@company.co.id',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
              ),
              const SizedBox(height: 14),
              StatefulBuilder(
                builder: (context, setLocal) => TextField(
                  key: const Key('login.password'),
                  controller: state._password,
                  focusNode: state._passwordFocus,
                  enabled: !login.submitting,
                  obscureText: state._obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onChanged: (_) => context.read<LoginCubit>().clearError(),
                  onSubmitted: (_) => state._submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip:
                          state._obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        state._obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setLocal(() => state._obscure = !state._obscure),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('login.submit'),
                onPressed: login.submitting ? null : state._submit,
                child: login.submitting
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Signing in…'),
                        ],
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Forgot your password? Contact your HR team.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _BannerTone { info, error }

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String message;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final error = tone == _BannerTone.error;
    final dark = theme.brightness == Brightness.dark;
    // Dark mode uses a tinted surface; a solid error container is too loud.
    final foreground = error
        ? (dark ? colors.error : colors.onErrorContainer)
        : colors.onSurface;
    final background = error
        ? (dark ? colors.error.withValues(alpha: 0.14) : colors.errorContainer)
        : colors.secondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: foreground, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
