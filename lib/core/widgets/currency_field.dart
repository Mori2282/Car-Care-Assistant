import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String garageMoney(double amount, String currency) => NumberFormat.currency(
  locale: 'ru',
  name: currency,
  symbol: currency,
  decimalDigits: 2,
).format(amount);

class CurrencyField extends StatelessWidget {
  const CurrencyField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Валюта'),
    items: [
      for (final currency in {
        'RUB',
        'BYN',
        'EUR',
        'USD',
        'CNY',
        'PLN',
        'KZT',
        'UAH',
        value,
      })
        DropdownMenuItem(value: currency, child: Text(currency)),
    ],
    onChanged: (currency) {
      if (currency != null) onChanged(currency);
    },
  );
}
