import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';

/// Feedback screen with Google Form link
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  // TODO: Replace with actual Google Form URL
  static const String _feedbackFormUrl = 'https://docs.google.com/forms/d/e/1FAIpQLSecSbK0nb2xizH4_ANPE9EHB8QvyN839A_x_bmDMGPJq64WeA/viewform?usp=publish-editor';

  Future<void> _openFeedbackForm() async {
    final uri = Uri.parse(_feedbackFormUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Feedback illustration
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.feedback_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'We Value Your Feedback',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Help us improve Metro App by sharing your thoughts, suggestions, and experience.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Open form button
              ElevatedButton.icon(
                onPressed: _openFeedbackForm,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Feedback Form'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note
              Text(
                'Opens in your browser',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
