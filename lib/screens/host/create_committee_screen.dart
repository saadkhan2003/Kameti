import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../services/analytics_service.dart';
import '../../models/committee.dart';
import '../../utils/app_theme.dart';
import '../../utils/code_generator.dart';

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

  final _intervalController = TextEditingController(text: '30');

  String _collectionFrequency = 'daily';
  String _payoutFrequency = 'monthly';
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;

  final List<String> _collectionFrequencies = ['daily', 'weekly', 'monthly'];
  final List<String> _payoutFrequencies = [
    'daily',
    'weekly',
    'monthly',
    'custom',
  ];

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
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select committee start date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
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
      } else if (_payoutFrequency == 'weekly') {
        intervalDays = 7;
      } else if (_payoutFrequency == 'monthly') {
        intervalDays = 30;
      } else if (_payoutFrequency == 'custom') {
        intervalDays = int.tryParse(_intervalController.text) ?? 30;
      }

      final committee = Committee(
        id: const Uuid().v4(),
        code: CodeGenerator.generateCommitteeCode(),
        name: _nameController.text.trim(),
        hostId: _authService.currentUser?.uid ?? '',
        contributionAmount: double.parse(_amountController.text),
        frequency: _collectionFrequency,
        startDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
        totalMembers: 0,
        createdAt: DateTime.now(),
        paymentIntervalDays: intervalDays,
      );

      await _dbService.saveCommittee(committee);

      AnalyticsService.logCommitteeCreated(
        committeeName: committee.name,
        memberCount: 0,
        contributionAmount: committee.contributionAmount,
      );

      await _syncService.syncCommittees(committee.hostId);

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.secondaryColor,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kameti Created!',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your committee code is:',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        committee.code,
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Share this code with your members',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Got it!'),
                  ),
                ],
              ),
        );
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Create Committee'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: GoogleFonts.inter(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Kameti Name',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(
                    Icons.group_outlined,
                    color: Colors.grey[600],
                  ),
                  hintText: 'e.g., Family Committee',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Amount (Per Collection)',
                  labelStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    width: 60,
                    child: Text(
                      'PKR',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  hintText: 'e.g., 1000',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
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

              Text(
                'Collection Frequency',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _collectionFrequencies.map((freq) {
                      final isSelected = _collectionFrequency == freq;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _collectionFrequency = freq;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                isSelected
                                    ? null
                                    : Border.all(color: Colors.grey[300]!),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Text(
                            freq.substring(0, 1).toUpperCase() +
                                freq.substring(1),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected ? Colors.white : Colors.grey[600],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),

              Text(
                'Payout Frequency (Rounds)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _payoutFrequencies.map((freq) {
                      final isSelected = _payoutFrequency == freq;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _payoutFrequency = freq;
                            if (freq == 'daily') _intervalController.text = '1';
                            if (freq == 'weekly')
                              _intervalController.text = '7';
                            if (freq == 'monthly')
                              _intervalController.text = '30';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                isSelected
                                    ? null
                                    : Border.all(color: Colors.grey[300]!),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: AppTheme.primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Text(
                            freq == 'custom'
                                ? 'Custom'
                                : freq.substring(0, 1).toUpperCase() +
                                    freq.substring(1),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected ? Colors.white : Colors.grey[600],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),

              if (_payoutFrequency == 'custom') ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _intervalController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Days per Cycle',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(
                      Icons.timer_outlined,
                      color: Colors.grey[600],
                    ),
                    hintText: 'e.g., 45',
                    helperText: 'e.g., 10 days, 45 days, 90 days',
                    helperStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                      ),
                    ),
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

              Text(
                'Start Date',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickStartDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
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
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
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

              ElevatedButton(
                onPressed: _isLoading ? null : _createCommittee,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Create Committee',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
