import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/category_model.dart';
import '../../core/providers/app_providers.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Categories'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expenses'),
              Tab(text: 'Income'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () => _showAddCategoryDialog(context, ref),
        ),
        body: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (categories) {
            final expenses = categories.where((c) => c.type == 'expense').toList();
            final income = categories.where((c) => c.type == 'income').toList();

            return TabBarView(
              children: [
                _buildList(expenses),
                _buildList(income),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(List<CategoryModel> list) {
    if (list.isEmpty) {
      return const Center(child: Text('No categories found.'));
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final cat = list[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.category)),
          title: Text(cat.name),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(cat),
          ),
          onTap: () => _showEditCategoryDialog(context, ref, cat),
        );
      },
    );
  }

  Future<void> _confirmDelete(CategoryModel cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${cat.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(categoriesProvider.notifier).delete(cat.id!);
    }
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    String type = 'expense';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                ],
                onChanged: (v) => setState(() => type = v!),
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ref.read(categoriesProvider.notifier).add(CategoryModel(
                      name: nameCtrl.text.trim(),
                      type: type,
                    ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, CategoryModel cat) {
    final nameCtrl = TextEditingController(text: cat.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref.read(categoriesProvider.notifier).edit(cat.id!, {'name': nameCtrl.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
