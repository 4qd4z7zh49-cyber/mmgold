import 'package:flutter/material.dart';
import '../../../app_shell.dart';
import '../../../shared/widgets/gradient_scaffold.dart';

class WelcomeGate extends StatelessWidget {
  const WelcomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'မြန်မာ့ရွှေ Calculator မှ ကြိုဆိုပါတယ်',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'မြန်မာ့ရွှေဈေးများကို အခမဲ့ကြည့်ရှုနိုင်ပြီး '
              'Calculator နဲ့ History ကိုလည်း အခမဲ့ အသုံးပြုနိုင်ပါတယ်။',
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AppShell()),
                  );
                },
                child: const Text('Get Started'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
