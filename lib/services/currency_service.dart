import 'package:flutter/material.dart';
import 'database_service.dart';

/// Represents a supported currency with display info
class CurrencyInfo {
  final String code;       // e.g., 'PKR'
  final String symbol;     // e.g., '₨'
  final String name;       // e.g., 'Pakistani Rupee'
  final String flag;       // e.g., '🇵🇰'

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
  });
}

/// Service to manage currency selection and formatting throughout the app
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  /// Default currency code
  static const String defaultCurrency = 'PKR';

  /// All supported currencies
  static const List<CurrencyInfo> supportedCurrencies = [
    CurrencyInfo(code: 'PKR', symbol: '₨',  name: 'Pakistani Rupee',    flag: '🇵🇰'),
    CurrencyInfo(code: 'INR', symbol: '₹',  name: 'Indian Rupee',       flag: '🇮🇳'),
    CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar',          flag: '🇺🇸'),
    CurrencyInfo(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham',        flag: '🇦🇪'),
    CurrencyInfo(code: 'SAR', symbol: '﷼',  name: 'Saudi Riyal',        flag: '🇸🇦'),
    CurrencyInfo(code: 'GBP', symbol: '£',  name: 'British Pound',      flag: '🇬🇧'),
    CurrencyInfo(code: 'EUR', symbol: '€',  name: 'Euro',               flag: '🇪🇺'),
    CurrencyInfo(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar',   flag: '🇨🇦'),
    CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', flag: '🇦🇺'),
    CurrencyInfo(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit',  flag: '🇲🇾'),
    CurrencyInfo(code: 'BDT', symbol: '৳',  name: 'Bangladeshi Taka',   flag: '🇧🇩'),
    CurrencyInfo(code: 'QAR', symbol: 'ر.ق', name: 'Qatari Riyal',     flag: '🇶🇦'),
    CurrencyInfo(code: 'KWD', symbol: 'د.ك', name: 'Kuwaiti Dinar',    flag: '🇰🇼'),
    CurrencyInfo(code: 'OMR', symbol: 'ر.ع', name: 'Omani Rial',       flag: '🇴🇲'),
    CurrencyInfo(code: 'BHD', symbol: 'د.ب', name: 'Bahraini Dinar',   flag: '🇧🇭'),
  ];

  /// The app-wide default currency (stored in Hive)
  String _appDefaultCurrency = defaultCurrency;
  String get appDefaultCurrency => _appDefaultCurrency;

  /// Initialize from stored preference
  Future<void> initialize() async {
    final dbService = DatabaseService();
    _appDefaultCurrency = await dbService.getDefaultCurrency();
  }

  /// Set the app-wide default currency
  Future<void> setAppDefaultCurrency(String code) async {
    _appDefaultCurrency = code;
    final dbService = DatabaseService();
    await dbService.setDefaultCurrency(code);
  }

  /// Get CurrencyInfo by code
  static CurrencyInfo getCurrencyInfo(String code) {
    return supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCurrencies.first, // Default to PKR
    );
  }

  /// Format an amount with its currency code.
  /// e.g., formatAmount(1000, 'PKR') => 'PKR 1,000'
  static String formatAmount(double amount, String currencyCode) {
    final formatted = _formatNumber(amount.toInt());
    return '$currencyCode $formatted';
  }

  /// Format with symbol instead of code.
  /// e.g., formatWithSymbol(1000, 'PKR') => '₨ 1,000'
  static String formatWithSymbol(double amount, String currencyCode) {
    final info = getCurrencyInfo(currencyCode);
    final formatted = _formatNumber(amount.toInt());
    return '${info.symbol} $formatted';
  }

  /// Simple number formatting with commas
  static String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}
