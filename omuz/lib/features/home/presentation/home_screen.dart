import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/home_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<HomeProvider>();
    Future.microtask(() => prov.load());
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();

    return Scaffold(
      body: home.loading && home.courses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => home.load(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (home.continueLearning.isNotEmpty) ...[
                    Text('Continue Learning',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...home.continueLearning.map((c) => _courseCard(c)),
                    const SizedBox(height: 16),
                  ],
                  Text('Categories',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildCategories(home),
                  const SizedBox(height: 24),
                  Text('All Courses',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...home.courses.map((c) => _courseCard(c)),
                ],
              ),
            ),
    );
  }

  Widget _buildCategories(HomeProvider home) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _categoryChip('All', null, home),
          ...home.categories.map((cat) =>
              _categoryChip(cat['name'] as String, cat['id'] as int, home)),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, int? id, HomeProvider home) {
    final selected = home.selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => home.filterByCategory(id),
      ),
    );
  }

  Widget _courseCard(dynamic course) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/course/${course['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  course['image'] ?? '',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 56,
                    height: 56,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.school),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title'] ?? '',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${course['lessons_count'] ?? 0} lessons',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
