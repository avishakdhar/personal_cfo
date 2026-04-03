import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {

  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  String category = "Food";

  final List<String> categories = [
    "Food",
    "Transport",
    "Shopping",
    "Bills",
    "Entertainment",
    "Health"
  ];

  List<Map<String, dynamic>> accounts = [];

  int? selectedAccount;

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  Future<void> loadAccounts() async {

    final data = await DatabaseHelper.instance.getAccounts();

    setState(() {
      accounts = data;
      if (accounts.isNotEmpty) {
        selectedAccount = accounts.first['id'];
      }
    });
  }

  Future<void> saveTransaction() async {

    if (amountController.text.isEmpty) return;

    await DatabaseHelper.instance.insertTransaction({

      'amount': double.parse(amountController.text),
      'from_account': selectedAccount,
      'to_account': null,
      'category': category,
      'note': noteController.text,
      'date': DateTime.now().toString()

    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Transaction Added")),
    );

    amountController.clear();
    noteController.clear();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Transaction"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<int>(
  initialValue: selectedAccount,
  items: accounts.map<DropdownMenuItem<int>>((acc) {

    return DropdownMenuItem<int>(
      value: acc['id'],
      child: Text(acc['name']),
    );

  }).toList(),

              onChanged: (value) {
                selectedAccount = value;
              },

              decoration: const InputDecoration(
                labelText: "Account",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              initialValue: category,

              items: categories.map((cat) {

                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat),
                );

              }).toList(),

              onChanged: (value) {
                setState(() {
                  category = value!;
                });
              },

              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: "Note",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: saveTransaction,
              child: const Text("Save Transaction"),
            )

          ],
        ),
      ),
    );
  }
}