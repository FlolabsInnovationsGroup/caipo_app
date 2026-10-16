import 'package:flutter/material.dart';

import '../../shared/copy/app_strings.dart';
import '../../shared/feedback/haptics.dart';
import '../../shared/theme/caipo_tokens.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == AppStrings.onboardingPages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CaipoSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.onboardingTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: CaipoSpace.l),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (page) => setState(() => _page = page),
                  children: [
                    for (final page in AppStrings.onboardingPages)
                      Text(page, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < AppStrings.onboardingPages.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: CaipoSpace.xs),
                      child: Container(
                        width: CaipoSpace.s,
                        height: CaipoSpace.s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: CaipoSpace.m),
              FilledButton(
                onPressed: () async {
                  caipoHaptic();
                  if (!last) {
                    await _controller.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                    return;
                  }
                  await widget.onFinished();
                },
                child: Text(last ? AppStrings.onboardingStart : AppStrings.onboardingNext),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
