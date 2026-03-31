import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/omuz_ui.dart';
import '../providers/admin_provider.dart';

class AdminModulesScreen extends StatefulWidget {
  final int courseId;
  const AdminModulesScreen({super.key, required this.courseId});

  @override
  State<AdminModulesScreen> createState() => _AdminModulesScreenState();
}

class _AdminModulesScreenState extends State<AdminModulesScreen> {
  @override
  void initState() {
    super.initState();
    final prov = context.read<AdminProvider>();
    Future.microtask(() => prov.loadModules(widget.courseId));
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AdminProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Modules')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showModuleDialog(context, prov),
        child: const Icon(Icons.add),
      ),
      body: prov.loading && prov.modules.isEmpty
          ? OmuzPage.background(
              context: context,
              child: const Center(child: CircularProgressIndicator()),
            )
          : prov.modules.isEmpty
              ? OmuzPage.background(
                  context: context,
                  child: Center(
                    child: Text(
                      'No modules yet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : OmuzPage.background(
                  context: context,
                  child: ReorderableListView.builder(
                  padding: OmuzPage.padding,
                  itemCount: prov.modules.length,
                  onReorder: (oldIndex, newIndex) =>
                      prov.reorderModules(oldIndex, newIndex, widget.courseId),
                  itemBuilder: (context, index) {
                    final mod = prov.modules[index] as Map<String, dynamic>;
                    return Card(
                      key: ValueKey(mod['id']),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(mod['title'] as String),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () =>
                                  _showModuleDialog(context, prov, module: mod),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Theme.of(context).colorScheme.error,
                                size: 20,
                              ),
                              onPressed: () =>
                                  prov.deleteModule(mod['id'] as int, widget.courseId),
                            ),
                          ],
                        ),
                        onTap: () =>
                            context.push('/admin/module/${mod['id']}/lessons'),
                      ),
                    );
                  },
                ),
                ),
    );
  }

  void _showModuleDialog(BuildContext context, AdminProvider prov, {Map<String, dynamic>? module}) {
    final isEdit = module != null;
    final titleC = TextEditingController(text: isEdit ? module['title'] as String : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Module' : 'New Module'),
        content: TextField(
          controller: titleC,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (titleC.text.isEmpty) return;
              if (isEdit) {
                await prov.updateModule(module['id'] as int, {'title': titleC.text});
              } else {
                await prov.createModule({
                  'course': widget.courseId,
                  'title': titleC.text,
                  'order': prov.modules.length,
                });
              }
              await prov.loadModules(widget.courseId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}
