import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/reviews_cubit.dart';
import '../data/performance_repository.dart';
import 'performance_format.dart';

/// The employee's performance reviews (Phase 3): tasks to complete (PENDING) and
/// submitted reviews about them (read-only). Handles loading/empty/error/refresh.
class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ReviewsCubit(context.read<PerformanceRepository>()),
      child: const _MyReviewsView(),
    );
  }
}

class _MyReviewsView extends StatelessWidget {
  const _MyReviewsView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReviewsCubit>().state;
    final load = context.read<ReviewsCubit>().load;
    return Scaffold(
      appBar: AppBar(title: const Text('My Reviews')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            AsyncView<MyReviews>(
              value: state,
              onRetry: load,
              loading:
                  const SizedBox(height: 320, child: SkeletonList(count: 3)),
              builder: (reviews) {
                if (reviews.toWrite.isEmpty && reviews.aboutMe.isEmpty) {
                  return const EmptyView(
                    icon: Icons.rate_review_outlined,
                    title: 'No reviews yet',
                    message:
                        'Review tasks appear here when a cycle is assigned to you.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reviews.toWrite.isNotEmpty) ...[
                      _SectionTitle('To complete'),
                      for (final review in reviews.toWrite)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReviewCard(review: review, canOpen: true),
                        ),
                    ],
                    if (reviews.aboutMe.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _SectionTitle('About me'),
                      for (final review in reviews.aboutMe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReviewCard(review: review, canOpen: true),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.canOpen});

  final PerformanceReview review;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = ratingLabel(review.overallRating);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        key: Key('review.item.${review.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: canOpen ? () => _openReview(context, review) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.cycleName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                    reviewStatusLabel(review.status),
                    tone: reviewStatusTone(review.status),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${reviewTypeLabel(review.reviewType)} · ${review.employeeName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (rating != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Overall rating $rating',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              if (review.submittedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Submitted ${Clock.date(review.submittedAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openReview(BuildContext context, PerformanceReview review) {
  final cubit = context.read<ReviewsCubit>();
  final repository = context.read<PerformanceRepository>();
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => RepositoryProvider.value(
        value: repository,
        child: BlocProvider.value(
          value: cubit,
          child: _ReviewDetailScreen(reviewId: review.id),
        ),
      ),
    ),
  );
}

/// Loads the full review, then shows a read-only summary (SUBMITTED) or an
/// editable form (PENDING, assigned to the caller).
class _ReviewDetailScreen extends StatefulWidget {
  const _ReviewDetailScreen({required this.reviewId});

  final String reviewId;

  @override
  State<_ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<_ReviewDetailScreen> {
  late Future<PerformanceReview> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<PerformanceReview> _load() =>
      context.read<PerformanceRepository>().reviewDetail(widget.reviewId);

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: FutureBuilder<PerformanceReview>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList(count: 4);
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: failureMessage(apiFailureOf(snapshot.error!)),
              onRetry: _retry,
            );
          }
          final review = snapshot.data!;
          if (review.isSubmitted) {
            return _ReviewReadOnly(review: review);
          }
          return _ReviewForm(review: review);
        },
      ),
    );
  }
}

class _ReviewReadOnly extends StatelessWidget {
  const _ReviewReadOnly({required this.review});

  final PerformanceReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = ratingLabel(review.overallRating);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          review.cycleName,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${reviewTypeLabel(review.reviewType)} · ${review.employeeName}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.star_outline),
                const SizedBox(width: 10),
                Text(
                  rating == null ? 'No overall rating' : 'Overall rating $rating',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final answer in review.answers)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      answer.questionKey,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (ratingLabel(answer.rating) != null) ...[
                      const SizedBox(height: 4),
                      Text('Rating ${ratingLabel(answer.rating)}',
                          style: theme.textTheme.bodyMedium),
                    ],
                    if (answer.answer != null &&
                        answer.answer!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(answer.answer!, style: theme.textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.review});

  final PerformanceReview review;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  late final TextEditingController _overall = TextEditingController(
      text: ratingLabel(widget.review.overallRating) ?? '');
  late final Map<String, TextEditingController> _ratings = {
    for (final answer in widget.review.answers)
      answer.questionKey:
          TextEditingController(text: ratingLabel(answer.rating) ?? ''),
  };
  late final Map<String, TextEditingController> _answers = {
    for (final answer in widget.review.answers)
      answer.questionKey: TextEditingController(text: answer.answer ?? ''),
  };

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _overall.dispose();
    for (final controller in _ratings.values) {
      controller.dispose();
    }
    for (final controller in _answers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Map<String, Object?>> _answerPayload() => [
        for (final answer in widget.review.answers)
          {
            'questionKey': answer.questionKey,
            if (_ratings[answer.questionKey]!.text.trim().isNotEmpty)
              'rating': _ratings[answer.questionKey]!.text.trim(),
            if (_answers[answer.questionKey]!.text.trim().isNotEmpty)
              'answer': _answers[answer.questionKey]!.text.trim(),
          },
      ];

  Future<void> _submit() async {
    final repository = context.read<PerformanceRepository>();
    final reviews = context.read<ReviewsCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.saveReview(
        widget.review.id,
        overallRating: _overall.text.trim(),
        answers: _answerPayload(),
      );
      await repository.submitReview(widget.review.id);
      reviews.load();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Review submitted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failureMessage(apiFailureOf(error));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final review = widget.review;
    return Column(
      children: [
        Expanded(
          child: AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  review.cycleName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reviewTypeLabel(review.reviewType)} · ${review.employeeName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final answer in review.answers) ...[
                  Text(
                    answer.questionKey,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: Key('review.rating.${answer.questionKey}'),
                    controller: _ratings[answer.questionKey],
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Rating',
                      prefixIcon: Icon(Icons.star_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: Key('review.answer.${answer.questionKey}'),
                    controller: _answers[answer.questionKey],
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Overall',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('review.overall'),
                  controller: _overall,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Overall rating',
                    prefixIcon: Icon(Icons.star),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!,
                        style: TextStyle(color: colors.onErrorContainer)),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: FilledButton(
            key: const Key('review.submit'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save & submit'),
          ),
        ),
      ],
    );
  }
}
