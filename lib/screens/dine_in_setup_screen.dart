import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/table.dart' as restaurant_table;
import '../services/table_service.dart';
import '../widgets/back_button.dart';
import 'order_creation_screen.dart';
import 'package:provider/provider.dart';

class DineInSetupScreen extends StatefulWidget {
  final User user;

  const DineInSetupScreen({super.key, required this.user});

  @override
  State<DineInSetupScreen> createState() => _DineInSetupScreenState();
}

class _DineInSetupScreenState extends State<DineInSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tableNumberController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController(text: '4');
  int _numberOfPeople = 4;
  bool _isLoading = false;
  List<restaurant_table.Table> _tables = [];
  restaurant_table.Table? _selectedTable;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    final tableService = Provider.of<TableService>(context, listen: false);
    final tables = await tableService.getTables();
    setState(() {
      _tables = tables;
    });
  }

  void _selectTable(restaurant_table.Table table) {
    if (table.isAvailable) {
      setState(() {
        _selectedTable = table;
        _tableNumberController.text = table.number.toString();
        _capacityController.text = table.capacity.toString();
        _numberOfPeople = table.capacity;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Table ${table.number} is currently occupied!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _createOrUseTable() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final tableService = Provider.of<TableService>(context, listen: false);
      final inputTableNumber = int.tryParse(_tableNumberController.text.trim());
      final inputCapacity = int.tryParse(_capacityController.text.trim()) ?? 4;
      
      if (inputTableNumber == null) {
        throw Exception('Please enter a valid table number');
      }

      restaurant_table.Table? existingTable;
      for (final table in _tables) {
        if (table.number == inputTableNumber) {
          existingTable = table;
          break;
        }
      }

      if (existingTable != null) {
        if (existingTable.isAvailable) {
          // Use the available table
          _navigateToOrderCreation(existingTable);
        } else {
          throw Exception('Table $inputTableNumber is currently occupied!');
        }
      } else {
        // Create new table
        await tableService.createTable(inputTableNumber, inputCapacity);
        final newTable = restaurant_table.Table(
          number: inputTableNumber,
          capacity: inputCapacity,
          status: restaurant_table.TableStatus.available,
        );
        _navigateToOrderCreation(newTable);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToOrderCreation(restaurant_table.Table table) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderCreationScreen(
          user: widget.user,
          table: table,
          numberOfPeople: _numberOfPeople,
          orderType: 'dine-in',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dine-In Setup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: <Widget>[
          const CustomBackButton(),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: 0.5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Step 2 of 4: Table Setup',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              'Select Table & Guests',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose an available table or create a new one for your guests.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Table Map Section
            Text(
              'Available Tables',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Visual Table Map
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _tables.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _tables.length,
                      itemBuilder: (context, index) {
                        final table = _tables[index];
                        final isSelected = _selectedTable?.id == table.id;
                        final isAvailable = table.isAvailable;
                        
                        return GestureDetector(
                          onTap: () => _selectTable(table),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : isAvailable
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : isAvailable
                                        ? Colors.green
                                        : Colors.red,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.table_restaurant,
                                  color: isSelected
                                      ? Colors.white
                                      : isAvailable
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${table.number}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : isAvailable
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                  ),
                                ),
                                Text(
                                  '${table.capacity}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Colors.white70
                                        : isAvailable
                                            ? Colors.green.shade600
                                            : Colors.red.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),

            // Manual Input Section
            Text(
              'Or Enter Manually',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tableNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Table Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.table_restaurant),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a table number';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _capacityController,
                          decoration: const InputDecoration(
                            labelText: 'Capacity',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.people),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter capacity';
                            }
                            final capacity = int.tryParse(value);
                            if (capacity == null || capacity < 1) {
                              return 'Please enter a valid capacity';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            final capacity = int.tryParse(value);
                            if (capacity != null && capacity > 0) {
                              setState(() => _numberOfPeople = capacity);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Number of People Slider
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Number of Guests: $_numberOfPeople',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Slider(
                        value: _numberOfPeople.toDouble(),
                        min: 1,
                        max: 12,
                        divisions: 11,
                        label: _numberOfPeople.toString(),
                        onChanged: (value) {
                          setState(() => _numberOfPeople = value.round());
                          _capacityController.text = value.round().toString();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createOrUseTable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Continue to Order',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 