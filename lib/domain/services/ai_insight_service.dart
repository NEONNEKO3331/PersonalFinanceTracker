import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';

class AiInsightService {
  Future<String> monthlyInsight({
    required double income,
    required double expense,
    required double balance,
    required Map<String, double> categoryTotals,
  }) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.5-flash-lite',
    );

    final cats = categoryTotals.entries
        .map((e) => '${e.key}: RM ${e.value.toStringAsFixed(2)}')
        .join('\n');

    final prompt = '''
You are a concise personal finance coach for a Malaysian user (currency RM).
Using ONLY the numbers below, write a short monthly analysis in English:
Return exactly these four lines, with one concise sentence after each label:
Overview: ...
Top spending pattern: ...
What to watch: ...
Next month tip: ...
Keep the complete response under 120 words. No markdown, no invented numbers.

Income: RM ${income.toStringAsFixed(2)}
Expense: RM ${expense.toStringAsFixed(2)}
Balance: RM ${balance.toStringAsFixed(2)}
Categories:
$cats
''';

    final response = await model.generateContent(
        [Content.text(prompt)]).timeout(const Duration(seconds: 60));
    return response.text?.trim() ?? 'No insight generated.';
  }
}
