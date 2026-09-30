/// Lightweight keyword-based expense classification (no ML model needed).
class CategoryService {
  String classify(String text) {
    final lower = text.toLowerCase();

    if (_match(lower, [
      'food', 'makan', 'restaurant', 'restoran', 'cafe', 'coffee', 'nasi',
      'mcdonald', 'kfc', 'starbucks', 'lunch', 'dinner', 'kedai',
      'mamak', 'warung', 'milo', 'takeaway', 'take away', 'bungkus',
      'mee', 'mi ', 'kopi', 'teh ', 'ayam', 'rice', 'burger',
    ])) {
      return 'food_dining';
    }
    if (_match(lower, [
      'petrol', 'fuel', 'bhp', 'shell', 'petronas', 'grab', 'taxi',
      'uber', 'bus', 'transport', 'tng', 'touch n go',
    ])) {
      return 'transportation';
    }
    if (_match(lower, [
      'tesco', 'giant', 'aeon', 'grocery', 'supermarket', 'mart', 'jaya grocer',
    ])) {
      return 'groceries';
    }
    if (_match(lower, [
      'hospital', 'clinic', 'pharmacy', 'watson', 'guardian', 'medicine',
    ])) {
      return 'healthcare';
    }
    if (_match(lower, [
      'electric', 'water', 'internet', 'bill', 'utility', 'astros', 'unifi',
    ])) {
      return 'bills_utilities';
    }
    if (_match(lower, ['school', 'tuition', 'course', 'education', 'book'])) {
      return 'education';
    }
    if (_match(lower, ['movie', 'cinema', 'game', 'entertain', 'netflix'])) {
      return 'entertainment';
    }
    if (_match(lower, ['shop', 'mall', 'store', 'mr diy', 'daiso', 'uniqlo'])) {
      return 'shopping';
    }
    return 'other_expense';
  }

  bool _match(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }
}