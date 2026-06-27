import 'package:flutter/material.dart';

import '../db/db_helper.dart';
import '../models/product.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _rateController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  // bool _isLoading = false;

  Future<List<Product>>? _productsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _productsFuture = DatabaseHelper().getAllProducts();
    });
  }

  Future<void> _saveProduct({Product? existing}) async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final rate = double.parse(_rateController.text.trim());

    setState(() => _isSaving = true);

    try {
      final db = DatabaseHelper();

      if (existing == null) {
        // Insert new
        await db.insertProduct(
          Product(id: null, name: name, code: code, rate: rate),
        );
      } else {
        // Update existing
        if (existing.id == null) {
          throw StateError('Cannot update product without id');
        }
        await db.updateProduct(
          Product(id: existing.id, name: name, code: code, rate: rate),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product saved successfully')),
      );

      _nameController.clear();
      _codeController.clear();
      _rateController.clear();

      Navigator.of(context).pop();
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddEditDialog({Product? product}) {
    final isEdit = product != null;

    if (isEdit) {
      _nameController.text = product!.name;
      _codeController.text = product.code;
      _rateController.text = product.rate.toString();
    } else {
      _nameController.clear();
      _codeController.clear();
      _rateController.clear();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(isEdit ? 'Edit Product' : 'Add Product'),
          content: SizedBox(
            width: 380,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter product name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Product Code',
                      prefixIcon: Icon(Icons.tag_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter product code';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rateController,
                    decoration: const InputDecoration(
                      labelText: 'Rate',
                      prefixIcon: Icon(Icons.currency_rupee_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter rate';
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null) return 'Invalid number';
                      if (parsed < 0) return 'Rate can not be negative';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () => _saveProduct(existing: product),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${product.name}" (${product.code}) ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await DatabaseHelper().deleteProduct(product.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product deleted')));
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _productCard(Product p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xff1E88E5).withOpacity(0.12),

                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: const Color(0xff1E88E5),

                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: ${p.code}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹ ${p.rate.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff1E88E5),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () => _showAddEditDialog(product: p),
                    icon: const Icon(Icons.edit_outlined, size: 22),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => _deleteProduct(p),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 22,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),

      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff1565C0), Color(0xff1E88E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),

                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(26),
                    bottomRight: Radius.circular(26),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Products',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Add your product catalog with code + rate.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xff1E88E5),

                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _showAddEditDialog(),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add Product'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FutureBuilder<List<Product>>(
                  future: _productsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final products = snapshot.data ?? [];
                    if (products.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 56,
                                color: const Color.fromARGB(
                                  255,
                                  21,
                                  101,
                                  192,
                                ).withOpacity(0.9),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No products yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap "Add Product" to create your first one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView.builder(
                        itemCount: products.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final p = products[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _productCard(p),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
