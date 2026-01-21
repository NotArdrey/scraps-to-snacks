import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scraps_to_snacks/models/ingredient.dart';
import 'package:scraps_to_snacks/models/recipe.dart';
import 'package:scraps_to_snacks/components/add_ingredient_dialog.dart';
import 'package:scraps_to_snacks/pages/recipe_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;
  List<Ingredient> _ingredients = [];
  bool _isLoading = true;
  bool _isCooking = false;
  bool _isScanning = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchIngredients();
  }

  Future<void> _fetchIngredients() async {
    try {
      final response = await _supabase
          .from('ingredients')
          .select()
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;

      if (mounted) {
        setState(() {
          _ingredients = data.map((json) => Ingredient.fromMap(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> _deleteIngredient(String id, int index) async {
    final deletedItem = _ingredients[index];
    setState(() {
      _ingredients.removeAt(index);
    });

    try {
      await _supabase.from('ingredients').delete().eq('id', id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _ingredients.insert(index, deletedItem);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
      }
    }
  }

  Future<void> _showAddDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const AddIngredientDialog(),
    );

    if (result == true) {
      _fetchIngredients();
    }
  }

  Future<void> _scanPantry() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isScanning = true;
      });

      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = fileName;

      await _supabase.storage
          .from('pantry_images')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final imageUrl = _supabase.storage
          .from('pantry_images')
          .getPublicUrl(filePath);

      final response = await _supabase.functions.invoke(
        'scan-pantry',
        body: {'imageUrl': imageUrl},
      );

      if (response.status != 200) {
        throw Exception('Scan failed: ${response.data}');
      }

      await _fetchIngredients();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingredients added via Magic Scan! ✨')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _generateRecipe() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some ingredients first!')),
      );
      return;
    }

    setState(() {
      _isCooking = true;
    });

    try {
      final ingredientNames = _ingredients.map((i) => i.name).toList();

      final response = await _supabase.functions.invoke(
        'generate-recipe',
        body: {'ingredients': ingredientNames},
      );

      final data = response.data;
      if (data is Map && data.containsKey('error')) {
        throw Exception(data['error']);
      }

      final recipe = Recipe.fromMap(data);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RecipePage(recipe: recipe)),
        );
      }
    } on FunctionException catch (e) {
      if (mounted) {
        if (e.status == 401) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Logging out to fix...'),
            ),
          );
          await _signOut();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chef Error: ${e.toString()}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate recipe: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCooking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'My Pantry',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
            actions: [
              IconButton(
                onPressed: (_isScanning || _isCooking) ? null : _showAddDialog,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.black,
                  size: 28,
                ),
                tooltip: 'Add Ingredient',
              ),
              IconButton(
                onPressed: (_isScanning || _isCooking) ? null : _scanPantry,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.green,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.black,
                        size: 28,
                      ),
                tooltip: 'Scan Pantry',
              ),
              IconButton(
                onPressed: () => _signOut(),
                icon: const Icon(Icons.logout, color: Colors.black),
              ),
            ],
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_ingredients.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.kitchen_outlined,
                      size: 80,
                      color: Colors.grey[200],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your pantry is empty!',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan or add ingredients to start cooking.',
                      style: GoogleFonts.outfit(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final ingredient = _ingredients[index];

                  // Expiry Logic colors
                  Color cardColor = Colors.white;
                  Color textColor = Colors.black87;

                  if (ingredient.isExpiringSoon) {
                    cardColor = Colors.red.shade50;
                    textColor = Colors.red.shade900;
                  } else if (ingredient.expiryDate != null &&
                      ingredient.expiryDate!
                              .difference(DateTime.now())
                              .inDays <=
                          5) {
                    cardColor = Colors.orange.shade50;
                    textColor = Colors.orange.shade900;
                  }

                  return Dismissible(
                    key: Key(ingredient.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    onDismissed: (direction) =>
                        _deleteIngredient(ingredient.id, index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: cardColor == Colors.white
                            ? Colors.grey[50]
                            : cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Text(
                            ingredient.name.isNotEmpty
                                ? ingredient.name[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        title: Text(
                          ingredient.name,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        subtitle: ingredient.expiryDate != null
                            ? Text(
                                'Expires ${DateFormat('MMM dd').format(ingredient.expiryDate!)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              )
                            : null,
                      ),
                    ),
                  );
                }, childCount: _ingredients.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isCooking || _isScanning) ? null : _generateRecipe,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        icon: _isCooking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          _isCooking ? 'Thinking...' : 'Generate Recipe',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
