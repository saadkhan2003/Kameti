import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../services/analytics_service.dart';
import '../../services/currency_service.dart';
import '../../services/haptic_service.dart';
import '../../models/committee.dart';
import '../../utils/app_theme.dart';
import '../../utils/code_generator.dart';
import '../../ui/widgets/micro_animations.dart';

class CreateCommitteeScreen extends StatefulWidget {
  const CreateCommitteeScreen({super.key});

  @override
  State<CreateCommitteeScreen> createState() => _CreateCommitteeScreenState();
}

class _CreateCommitteeScreenState extends State<CreateCommitteeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _authService = AuthService();
  final _dbService = DatabaseService();
  final _syncService = SyncService();

  final _intervalController = TextEditingController(text: '30');  // Default to 30 days

  String _collectionFrequency = 'daily';
  String _payoutFrequency = 'monthly';
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;
  String _selectedCurrency = CurrencyService.defaultCurrency;

  final List<String> _collectionFrequencies = ['daily', 'weekly', 'monthly'];
  final List<String> _payoutFrequencies = ['daily', 'weekly', 'monthly', 'custom'];

  @override
  void initState() {
    super.initState();
    _loadDefaultCurrency();
  }

  Future<void> _loadDefaultCurrency() async {
    final currency = await CurrencyService().initialize().then((_) => CurrencyService().appDefaultCurrency);
    if (mounted) {
      setState(() => _selectedCurrency = currency);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      // Allow past dates (up to 2 years) for digitizing existing committees
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select committee start date (past dates allowed for existing committees)',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.darkCard,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _createCommittee() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      int intervalDays = 30;
      if (_payoutFrequency == 'daily') {
        intervalDays = 1;
      } else if (_payoutFrequency == 'weekly') intervalDays = 7;
      else if (_payoutFrequency == 'monthly') intervalDays = 30;
      else if (_payoutFrequency == 'custom') {
        intervalDays = int.tryParse(_intervalController.text) ?? 30;
      }

      final committee = Committee(
        id: const Uuid().v4(),
        code: CodeGenerator.generateCommitteeCode(),
        name: _nameController.text.trim(),
        hostId: _authService.currentUser?.id ?? '',
        contributionAmount: double.parse(_amountController.text),
        frequency: _collectionFrequency,
        startDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
        totalMembers: 0,
        createdAt: DateTime.now(),
        paymentIntervalDays: intervalDays,
        totalCycles: 0,
        isSynced: false,
        currency: _selectedCurrency,
      );

      await _dbService.saveCommittee(committee);
      
      // Log analytics event
      AnalyticsService.logCommitteeCreated(
        committeeName: committee.name,
        memberCount: 0,
        contributionAmount: committee.contributionAmount,
      );
      
      // Auto-sync to cloud immediately
      await _syncService.syncCommittees(committee.hostId);

      if (mounted) {
        HapticService.success();
        await SuccessAnimation.show(context, message: 'Kameti Created!');
        if (mounted) {
          Navigator.pop(context, true); // Return to dashboard
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Committee'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Committee Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Kameti Name',
                  prefixIcon: Icon(Icons.group_outlined),
                  hintText: 'e.g., Family Committee',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Contribution Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (Per Collection, e.g. Daily)',
                  prefixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    width: 60,
                    child: Text(
                      _selectedCurrency,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  hintText: 'e.g., 1000',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Collection Frequency Selection
              Text(
                'Collection Frequency',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _collectionFrequencies.map((freq) {
                  final isSelected = _collectionFrequency == freq;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _collectionFrequency = freq;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.grey[700]!),
                      ),
                      child: Text(
                        freq.substring(0, 1).toUpperCase() + freq.substring(1),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.grey[400],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Payout Frequency Selection
              Text(
                'Payout Frequency (Rounds)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _payoutFrequencies.map((freq) {
                  final isSelected = _payoutFrequency == freq;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _payoutFrequency = freq;
                        // Set default interval values
                        if (freq == 'daily') _intervalController.text = '1';
                        if (freq == 'weekly') _intervalController.text = '7';
                        if (freq == 'monthly') _intervalController.text = '30';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.grey[700]!),
                      ),
                      child: Text(
                        freq == 'custom' 
                            ? 'Custom' 
                            : freq.substring(0, 1).toUpperCase() + freq.substring(1),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.grey[400],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              // Custom Interval Input
              if (_payoutFrequency == 'custom') ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Days per Cycle',
                    prefixIcon: Icon(Icons.timer_outlined),
                    helperText: 'e.g., 10 days, 45 days, 90 days',
                  ),
                  validator: (value) {
                    if (_payoutFrequency == 'custom') {
                      if (value == null || value.isEmpty) {
                        return 'Please enter days';
                      }
                      final days = int.tryParse(value);
                      if (days == null || days <= 0) {
                        return 'Must be > 0';
                      }
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),

              // Currency Selection
              Text(
                'Currency',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _showCurrencyPicker(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        CurrencyService.getCurrencyInfo(_selectedCurrency).flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_selectedCurrency — ${CurrencyService.getCurrencyInfo(_selectedCurrency).name}',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Symbol: ${CurrencyService.getCurrencyInfo(_selectedCurrency).symbol}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Start Date
              Text(
                'Start Date',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickStartDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Create Button
              ElevatedButton(
                onPressed: _isLoading ? null : _createCommittee,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Committee'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.currency_exchange, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    'Select Currency',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: CurrencyService.supportedCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = CurrencyService.supportedCurrencies[index];
                  final isSelected = currency.code == _selectedCurrency;
                  return ListTile(
                    leading: Text(currency.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      '${currency.code} — ${currency.name}',
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'Symbol: ${currency.symbol}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                        : null,
                    onTap: () {
                      HapticService.selectionTick();
                      setState(() => _selectedCurrency = currency.code);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
