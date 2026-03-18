import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  String _fullPhone = '';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.school,
                    size: 40, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 24),
              Text(
                'OMuz',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Learn. Grow. Succeed.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Text(
                'Enter your phone number',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              IntlPhoneField(
                initialCountryCode: 'TJ',
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha(80),
                ),
                disableLengthCheck: true,
                onChanged: (phone) {
                  _fullPhone = phone.completeNumber;
                },
              ),
              const SizedBox(height: 4),
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    auth.error!,
                    style: TextStyle(color: colorScheme.error),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              FilledButton(
                onPressed: auth.loading
                    ? null
                    : () async {
                        final phone = _fullPhone.trim();
                        if (phone.isEmpty) return;
                        final ok = await auth.sendOtp(phone);
                        if (ok && context.mounted) {
                          context.push('/otp');
                        }
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: auth.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue',
                        style: TextStyle(fontSize: 16)),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
