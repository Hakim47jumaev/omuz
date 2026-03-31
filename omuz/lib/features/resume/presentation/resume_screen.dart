import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/omuz_ui.dart';
import '../providers/resume_provider.dart';

class ResumeScreen extends StatefulWidget {
  const ResumeScreen({super.key});

  @override
  State<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends State<ResumeScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<ResumeProvider>();
    Future.microtask(() => prov.loadResumes());
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ResumeProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Resumes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/resume/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create Resume'),
      ),
      body: prov.loading
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : prov.resumes.isEmpty
              ? OmuzPage.background(context: context, child: _buildEmpty(cs))
              : OmuzPage.background(
                  context: context,
                  child: RefreshIndicator(
                    onRefresh: () => prov.loadResumes(),
                    child: ListView.builder(
                      padding: OmuzPage.padding,
                      itemCount: prov.resumes.length,
                      itemBuilder: (_, i) =>
                          _buildResumeCard(prov.resumes[i], prov, cs),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 80, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text('No resumes yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create your first resume',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeCard(Map<String, dynamic> r, ResumeProvider prov, ColorScheme cs) {
    final id = r['id'] as int;
    final name = '${r['first_name']} ${r['last_name']}'.trim();
    final job = r['current_job'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await context.push('/resume/$id/view');
          if (mounted) prov.loadResumes();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.description, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    if (job.isNotEmpty)
                      Text(job, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.download, size: 22),
                onPressed: () => _download(prov, id),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 22, color: cs.error),
                onPressed: () => _confirmDelete(prov, id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _download(ResumeProvider prov, int id) async {
    final path = await prov.downloadPdf(id);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF saved, opening...')),
      );
      await OpenFilex.open(path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${prov.lastError ?? "unknown"}')),
      );
    }
  }

  void _confirmDelete(ResumeProvider prov, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete resume?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              prov.deleteResume(id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
