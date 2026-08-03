import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/firestore_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final _fs = FirestoreService();
  List<Expense> _expenses = [];

  List<Expense> get expenses => _expenses;

  Stream<List<Expense>> get expensesStream => _fs.expensesStream();

  void initialize() {
    _fs.expensesStream().listen((list) {
      _expenses = list;
      notifyListeners();
    });
  }

  Future<void> addExpense(String description, double amount, String category) {
    final expense = Expense(
      id:          '',
      description: description,
      amount:      amount,
      category:    category,
      createdAt:   DateTime.now(),
    );
    return _fs.addExpense(expense);
    // Stream updates _expenses automatically
  }
}