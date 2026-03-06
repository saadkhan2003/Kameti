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
import '../../utils/code_generator.dart';
import '../../ui/widgets/micro_animations.dart';

class CreateCommitteeScreen extends StatefulWidget {
  const CreateCommitteeScreen({super.key});

  @override
  State<CreateCommitteeScreen> createState() => _CreateCommitteeScreenState();
}

class _CreateCommitteeScreenState extends State<CreateCommitteeScreen> {
  static const Color _bg = Color(0xFFF7F8FC);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF3347A8);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _authService = AuthService();
  final _dbService = DatabaseService();
  final _syncService = SyncService();

  final _intervalController = TextEditingController(
    text: '30',
  ); // Default to 30 days

  String _collectionFrequency = 'daily';
  String _payoutFrequency = 'monthly';
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;
  String _selectedCurrency = CurrencyService.defaultCurrency;

  final List<String> _collectionFrequencies = ['daily', 'weekly', 'monthly'];
  final List<String> _payoutFrequencies = [
    'daily',
    'weekly',
    'monthly',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _loadDefaultCurrency();
  }

  Future<void> _loadDefaultCurrency() async {
    final currency = await CurrencyService().initialize().then(
      (_) => CurrencyService().appDefaultCurrency,
    );
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
      helpText:
          'Select committee start date (past dates allowed for existing committees)',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              surface: _surface,
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
      } else if (_payoutFrequency == 'weekly')
        intervalDays = 7;
      else if (_payoutFrequency == 'monthly')
        intervalDays = 30;
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
    final currencyInfo = CurrencyService.getCurrencyInfo(_selectedCurrency);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Create Committee',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDCE4F7)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.groups_rounded, color: _primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set up your committee',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            'Define collection rules and launch instantly',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _buildSectionCard(
                title: 'Basics',
                icon: Icons.edit_note_rounded,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputDecoration(
                        label: 'Kameti Name',
                        hint: 'e.g., Family Committee',
                        icon: Icons.group_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(
                        label: 'Amount Per Collection',
                        hint: 'e.g., 1000',
                        icon: Icons.payments_outlined,
                        prefixText: '$_selectedCurrency ',
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
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _buildSectionCard(
                title: 'Collection Rules',
                icon: Icons.tune_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collection Frequency',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _collectionFrequencies.map((freq) {
                            final isSelected = _collectionFrequency == freq;
                            return _buildOptionChip(
                              label:
                                  '${freq[0].toUpperCase()}${freq.substring(1)}',
                              selected: isSelected,
                              onTap:
                                  () => setState(
                                    () => _collectionFrequency = freq,
                                  ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payout Frequency',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          _payoutFrequencies.map((freq) {
                            final isSelected = _payoutFrequency == freq;
                            return _buildOptionChip(
                              label:
                                  freq == 'custom'
                                      ? 'Custom'
                                      : '${freq[0].toUpperCase()}${freq.substring(1)}',
                              selected: isSelected,
                              onTap: () {
                                setState(() {
                                  _payoutFrequency = freq;
                                  if (freq == 'daily')
                                    _intervalController.text = '1';
                                  if (freq == 'weekly')
                                    _intervalController.text = '7';
                                  if (freq == 'monthly')
                                    _intervalController.text = '30';
                                });
                              },
                            );
                          }).toList(),
                    ),
                    if (_payoutFrequency == 'custom') ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: 'Days per Cycle',
                          hint: 'e.g., 10, 45, 90',
                          icon: Icons.timer_outlined,
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
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _buildSectionCard(
                title: 'Regional & Start Date',
                icon: Icons.public_rounded,
                child: Column(
                  children: [
                    InkWell(
                      onTap: _showCurrencyPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDCE4F7)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              currencyInfo.flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_selectedCurrency — ${currencyInfo.name}',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Symbol: ${currencyInfo.symbol}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickStartDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDCE4F7)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: _primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isLoading ? null : _createCommittee,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
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
                        : const Text('Create Committee'),
              ),
              const SizedBox(height: 8),
              Text(
                'You can edit settings anytime after creation.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: Icon(icon, color: _textSecondary),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDCE4F7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDCE4F7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.6),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE4F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: _primary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primary : const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _primary : const Color(0xFFDCE4F7),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _textPrimary,
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_exchange, color: _primary),
                      const SizedBox(width: 12),
                      Text(
                        'Select Currency',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFFE2E8F0)),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: CurrencyService.supportedCurrencies.length,
                    itemBuilder: (context, index) {
                      final currency =
                          CurrencyService.supportedCurrencies[index];
                      final isSelected = currency.code == _selectedCurrency;
                      return ListTile(
                        leading: Text(
                          currency.flag,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          '${currency.code} — ${currency.name}',
                          style: TextStyle(
                            color: isSelected ? _primary : _textPrimary,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          'Symbol: ${currency.symbol}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing:
                            isSelected
                                ? const Icon(
                                  Icons.check_circle,
                                  color: _primary,
                                )
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
