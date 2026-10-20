
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ContractApp());
}

class ContractApp extends StatelessWidget {
  const ContractApp({super.key});

  @override
  Widget build(BuildContext context) {
    const graphite = Color(0xFF30343B);
    const background = Color(0xFFF4F5F7);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Мои договоры',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: graphite,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: graphite,
          elevation: 0,
        ),
      ),
      home: const ContractsHomePage(),
    );
  }
}

String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

DateTime? parseDate(String? value) {
  if (value == null || value.isEmpty) return null;

  final parts = value.split('.');
  if (parts.length != 3) return null;

  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);

  if (day == null || month == null || year == null) {
    return null;
  }

  try {
    final date = DateTime(year, month, day);
    if (date.day != day ||
        date.month != month ||
        date.year != year) {
      return null;
    }
    return date;
  } catch (_) {
    return null;
  }
}

const List<String> contractStatuses = [
  'Черновик',
  'Действует',
  'Завершён',
];

Color statusColor(String status) {
  switch (status) {
    case 'Действует':
      return const Color(0xFF247A50);
    case 'Завершён':
      return Colors.grey.shade700;
    default:
      return const Color(0xFF9A6B13);
  }
}

class ContractsHomePage extends StatefulWidget {
  const ContractsHomePage({super.key});

  @override
  State<ContractsHomePage> createState() =>
      _ContractsHomePageState();
}

class _ContractsHomePageState extends State<ContractsHomePage> {
  static const String _storageKey = 'saved_contracts';

  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, String>> _contracts = [];
  String _search = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString(_storageKey);

      List<Map<String, String>> contracts;

      if (savedData != null) {
        final decoded = jsonDecode(savedData) as List<dynamic>;

        contracts = decoded.map((item) {
          final contract =
              Map<String, String>.from(item as Map);

          // Добавляем новые поля старым договорам.
          // Существующие данные при этом сохраняются.
          contract.putIfAbsent('startDate', () => '');
          contract.putIfAbsent('endDate', () => '');
          contract.putIfAbsent('status', () => 'Черновик');

          return contract;
        }).toList();

        await _saveContracts(contracts);
      } else {
        contracts = [
          {
            'number': 'ДОГ-001',
            'name': 'Договор на оказание услуг',
            'client': 'Иванова Анна',
            'date': '20.10.2026',
            'startDate': '',
            'endDate': '',
            'status': 'Действует',
          },
          {
            'number': 'ДОГ-002',
            'name': 'Договор сотрудничества',
            'client': 'Петров Максим',
            'date': '18.10.2026',
            'startDate': '',
            'endDate': '',
            'status': 'Черновик',
          },
          {
            'number': 'ДОГ-003',
            'name': 'Договор аренды',
            'client': 'Сидорова Мария',
            'date': '15.10.2026',
            'startDate': '',
            'endDate': '',
            'status': 'Завершён',
          },
        ];

        await _saveContracts(contracts);
      }

      if (!mounted) return;

      setState(() {
        _contracts = contracts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось загрузить сохранённые договоры',
          ),
        ),
      );
    }
  }

  Future<void> _saveContracts(
    List<Map<String, String>> contracts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(contracts));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openContract(Map<String, String> contract) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ContractDetailsPage(
          contract: contract,
          onEdit: () => _editContract(contract),
          onDelete: () => _deleteContract(contract),
          onStatusChanged: (status) {
            _changeStatus(contract, status);
          },
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    Map<String, String> contract,
    String status,
  ) async {
    final updatedContracts = _contracts.map((item) {
      if (identical(item, contract)) {
        return <String, String>{
          ...item,
          'status': status,
        };
      }
      return item;
    }).toList();

    try {
      await _saveContracts(updatedContracts);

      if (!mounted) return;

      setState(() {
        _contracts = updatedContracts;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Статус договора сохранён'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить статус'),
        ),
      );
    }
  }

  Future<void> _editContract(
    Map<String, String> contract,
  ) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => ContractFormDialog(
        title: 'Редактировать договор',
        contract: contract,
      ),
    );

    if (result == null || !mounted) return;

    final updatedContracts = _contracts.map((item) {
      if (identical(item, contract)) {
        return <String, String>{
          ...item,
          'name': result['name']!,
          'client': result['client']!,
          'startDate': result['startDate'] ?? '',
          'endDate': result['endDate'] ?? '',
          'status': result['status'] ?? 'Черновик',
        };
      }
      return item;
    }).toList();

    try {
      await _saveContracts(updatedContracts);

      if (!mounted) return;

      setState(() {
        _contracts = updatedContracts;
      });

      // Возвращаемся к списку, чтобы увидеть обновлённые данные.
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Изменения сохранены'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить изменения'),
        ),
      );
    }
  }

  Future<void> _deleteContract(
    Map<String, String> contract,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Удалить договор?'),
          content: Text(
            'Договор «${contract['name']}» будет удалён. '
            'Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final updatedContracts = _contracts
        .where((item) => !identical(item, contract))
        .toList();

    try {
      await _saveContracts(updatedContracts);

      if (!mounted) return;

      setState(() {
        _contracts = updatedContracts;
      });

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Договор удалён'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось удалить договор'),
        ),
      );
    }
  }

  Future<void> _showAddContractDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const ContractFormDialog(
        title: 'Новый договор',
      ),
    );

    if (result == null || !mounted) return;

    final nextNumber = _contracts.fold<int>(
          0,
          (maxNumber, contract) {
            final match = RegExp(
              r'^ДОГ-(\d+)$',
            ).firstMatch(contract['number'] ?? '');

            final number =
                int.tryParse(match?.group(1) ?? '') ?? 0;

            return number > maxNumber ? number : maxNumber;
          },
        ) +
        1;

    final newContract = <String, String>{
      'number':
          'ДОГ-${nextNumber.toString().padLeft(3, '0')}',
      'name': result['name']!,
      'client': result['client']!,
      'date': formatDate(DateTime.now()),
      'startDate': result['startDate'] ?? '',
      'endDate': result['endDate'] ?? '',
      'status': result['status'] ?? 'Черновик',
    };

    final updatedContracts = [
      newContract,
      ..._contracts,
    ];

    try {
      await _saveContracts(updatedContracts);

      if (!mounted) return;

      setState(() {
        _contracts = updatedContracts;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Договор сохранён'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось сохранить договор'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.toLowerCase();

    final filteredContracts = _contracts.where((contract) {
      return contract.values.any(
        (value) => value.toLowerCase().contains(query),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Мои договоры',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить список',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Управление документами',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF30343B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Все ваши договоры в одном месте',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _search = value.trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Поиск по договору или клиенту',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isLoading
                          ? null
                          : _showAddContractDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Список договоров',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Всего: ${_contracts.length}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : filteredContracts.isEmpty
                          ? const Center(
                              child: Text('Договоры не найдены'),
                            )
                          : ListView.separated(
                              itemCount: filteredContracts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final contract =
                                    filteredContracts[index];

                                return _ContractCard(
                                  contract: contract,
                                  onTap: () {
                                    _openContract(contract);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContractFormDialog extends StatefulWidget {
  const ContractFormDialog({
    super.key,
    required this.title,
    this.contract,
  });

  final String title;
  final Map<String, String>? contract;

  @override
  State<ContractFormDialog> createState() =>
      _ContractFormDialogState();
}

class _ContractFormDialogState
    extends State<ContractFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _clientController;

  DateTime? _startDate;
  DateTime? _endDate;
  String _status = 'Черновик';

  @override
  void initState() {
    super.initState();

    final contract = widget.contract;

    _nameController = TextEditingController(
      text: contract?['name'] ?? '',
    );
    _clientController = TextEditingController(
      text: contract?['client'] ?? '',
    );

    _startDate = parseDate(contract?['startDate']);
    _endDate = parseDate(contract?['endDate']);

    final savedStatus = contract?['status'] ?? 'Черновик';
    _status = contractStatuses.contains(savedStatus)
        ? savedStatus
        : 'Черновик';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _clientController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate({required bool isStart}) async {
    final currentDate = isStart ? _startDate : _endDate;
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: currentDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStart
          ? 'Выберите дату начала'
          : 'Выберите дату окончания',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (selected == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = selected;
      } else {
        _endDate = selected;
      }
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final client = _clientController.text.trim();

    if (name.isEmpty || client.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Заполни название договора и ФИО клиента',
          ),
        ),
      );
      return;
    }

    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Дата окончания не может быть раньше даты начала',
          ),
        ),
      );
      return;
    }

    Navigator.pop(context, <String, String>{
      'name': name,
      'client': client,
      'startDate':
          _startDate == null ? '' : formatDate(_startDate!),
      'endDate':
          _endDate == null ? '' : formatDate(_endDate!),
      'status': _status,
    });
  }

  Widget _dateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              '$label: ${date == null ? 'Не выбрана' : formatDate(date)}',
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
          ),
        ),
        if (date != null)
          IconButton(
            tooltip: 'Очистить дату',
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Название договора',
                  hintText: 'Например, договор услуг',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientController,
                decoration: const InputDecoration(
                  labelText: 'ФИО клиента',
                ),
              ),
              const SizedBox(height: 20),
              _dateButton(
                label: 'Дата начала',
                date: _startDate,
                onPressed: () => _chooseDate(isStart: true),
                onClear: () {
                  setState(() => _startDate = null);
                },
              ),
              const SizedBox(height: 8),
              _dateButton(
                label: 'Дата окончания',
                date: _endDate,
                onPressed: () => _chooseDate(isStart: false),
                onClear: () {
                  setState(() => _endDate = null);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Статус договора',
                  border: OutlineInputBorder(),
                ),
                items: contractStatuses.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _ContractCard extends StatelessWidget {
  const _ContractCard({
    required this.contract,
    required this.onTap,
  });

  final Map<String, String> contract;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = contract['status'] ?? 'Черновик';
    final color = statusColor(status);
    final startDate = contract['startDate'] ?? '';
    final endDate = contract['endDate'] ?? '';

    return Card(
      color: Colors.white,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF30343B),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contract['name'] ?? 'Без названия',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${contract['number'] ?? ''} · '
                      '${contract['client'] ?? ''}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Создан: ${contract['date'] ?? '—'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (startDate.isNotEmpty ||
                        endDate.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Действует: ${startDate.isEmpty ? '—' : startDate}'
                        ' — ${endDate.isEmpty ? '—' : endDate}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContractDetailsPage extends StatelessWidget {
  const ContractDetailsPage({
    super.key,
    required this.contract,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final Map<String, String> contract;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final status = contract['status'] ?? 'Черновик';
    final color = statusColor(status);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Карточка договора',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: Colors.grey.shade200,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 44,
                          color: Color(0xFF30343B),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          contract['name'] ?? 'Без названия',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          contract['number'] ?? 'Без номера',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Номер договора',
                          value: contract['number'] ?? '—',
                        ),
                        _DetailRow(
                          label: 'Название',
                          value: contract['name'] ?? '—',
                        ),
                        _DetailRow(
                          label: 'Клиент',
                          value: contract['client'] ?? '—',
                        ),
                        _DetailRow(
                          label: 'Дата создания',
                          value: contract['date'] ?? '—',
                        ),
                        _DetailRow(
                          label: 'Дата начала',
                          value: (contract['startDate'] ?? '')
                                  .isEmpty
                              ? 'Не указана'
                              : contract['startDate']!,
                        ),
                        _DetailRow(
                          label: 'Дата окончания',
                          value: (contract['endDate'] ?? '')
                                  .isEmpty
                              ? 'Не указана'
                              : contract['endDate']!,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Статус договора',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: contractStatuses.map((item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              onStatusChanged(value);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Текущий статус: $status',
                              style: TextStyle(color: color),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Редактировать договор'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить договор'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(
                      color: Colors.red.shade200,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Вернуться к договорам'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
