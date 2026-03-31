import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/omuz_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/resume_provider.dart';

class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});

  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _pageCtrl = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6;
  bool _saving = false;

  // Step 1: Current job
  final _jobCtrl = TextEditingController();
  int? _selectedUserId;

  // Step 2: Personal info
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _patronymicCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _gender = '';
  DateTime? _birthday;

  // Step 3: Education level
  String _educationLevel = '';

  // Step 4: Education institutions
  final List<Map<String, String>> _educationList = [];

  // Step 5: Skills
  final Set<String> _selectedSkills = {};

  // Step 6: Work experience
  final List<Map<String, String>> _workList = [];

  @override
  void initState() {
    super.initState();
    final prov = context.read<ResumeProvider>();
    final auth = context.read<AuthProvider>();
    Future.microtask(() async {
      await prov.loadChoices();
      if (auth.isStaff) {
        await prov.loadAdminUsers();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _jobCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _patronymicCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageCtrl.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _save();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageCtrl.animateToPage(_currentStep,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _save() async {
    if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and surname are required')),
      );
      return;
    }
    final isStaff = context.read<AuthProvider>().isStaff;
    if (isStaff && _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a user for this resume')),
      );
      return;
    }

    setState(() => _saving = true);
    final prov = context.read<ResumeProvider>();
    final emailTrim = _emailCtrl.text.trim();
    final data = <String, dynamic>{
      'current_job': _jobCtrl.text.trim(),
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'patronymic': _patronymicCtrl.text.trim(),
      'gender': _gender,
      'education_level': _educationLevel,
      'skills': _selectedSkills.toList(),
      'education': List<Map<String, String>>.from(_educationList),
      'work_experience': List<Map<String, String>>.from(_workList),
    };
    if (emailTrim.isNotEmpty) data['email'] = emailTrim;
    if (_birthday != null) {
      data['birthday'] = _birthday!.toIso8601String().substring(0, 10);
    }
    if (isStaff) data['user_id'] = _selectedUserId;
    final id = await prov.createResume(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume created!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${prov.lastError ?? "unknown"}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final prov = context.watch<ResumeProvider>();
    final isStaff = context.watch<AuthProvider>().isStaff;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Resume'),
        leading: _currentStep > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back)
            : IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: OmuzPage.background(
        context: context,
        child: Column(
          children: [
            _buildStepIndicator(cs),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _stepJob(isStaff, prov),
                  _stepPersonalInfo(cs),
                  _stepEducationLevel(prov, cs),
                  _stepEducationPlaces(cs),
                  _stepSkills(prov, cs),
                  _stepWorkExperience(cs),
                ],
              ),
            ),
            _buildBottomBar(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          final isActive = i <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive ? cs.primary : cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme cs) {
    final isLast = _currentStep == _totalSteps - 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _saving ? null : _next,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : Text(isLast ? 'Save' : 'Continue'),
        ),
      ),
    );
  }

  // ── Step 1: Current Job ──

  Widget _stepJob(bool isStaff, ResumeProvider prov) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What is your current job?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _jobCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Software Engineer',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          ),
          if (isStaff) ...[
            const SizedBox(height: 16),
            Text('Which user?',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedUserId,
              decoration: InputDecoration(
                hintText: 'Select a user',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              items: prov.adminUsers.map((u) {
                final id = (u['id'] as num).toInt();
                final name =
                    '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                final phone = u['phone']?.toString() ?? '';
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(
                    name.isNotEmpty ? '$name ($phone)' : phone,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedUserId = v),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 2: Personal Info ──

  Widget _stepPersonalInfo(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _inputField(_lastNameCtrl, 'Surname'),
          const SizedBox(height: 12),
          _inputField(_firstNameCtrl, 'Name'),
          const SizedBox(height: 12),
          _inputField(_patronymicCtrl, 'Patronymic'),
          const SizedBox(height: 12),
          _inputField(_emailCtrl, 'Email', type: TextInputType.emailAddress),
          const SizedBox(height: 16),
          Text('Gender', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              _genderChip('male', 'Male', cs),
              const SizedBox(width: 12),
              _genderChip('female', 'Female', cs),
            ],
          ),
          const SizedBox(height: 16),
          Text('Birthday', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickBirthday,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_birthday != null
                ? '${_birthday!.day}.${_birthday!.month.toString().padLeft(2, '0')}.${_birthday!.year}'
                : 'Select date'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, {TextInputType? type}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }

  Widget _genderChip(String value, String label, ColorScheme cs) {
    final selected = _gender == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _gender = value),
      selectedColor: cs.primaryContainer,
    );
  }

  Future<void> _pickBirthday() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (dt != null) setState(() => _birthday = dt);
  }

  // ── Step 3: Education Level ──

  Widget _stepEducationLevel(ResumeProvider prov, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What is your level of education?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ...prov.educationLevelChoices.map((el) {
            final val = el['value'] as String;
            final label = el['label'] as String;
            final selected = _educationLevel == val;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChoiceChip(
                label: SizedBox(width: double.infinity, child: Text(label)),
                selected: selected,
                onSelected: (_) => setState(() => _educationLevel = val),
                selectedColor: cs.primaryContainer,
                showCheckmark: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Step 4: Education Places ──

  Widget _stepEducationPlaces(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where did you study?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._educationList.asMap().entries.map((entry) {
            final i = entry.key;
            final edu = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(edu['institution'] ?? ''),
                subtitle: Text('${edu['faculty'] ?? ''} - ${edu['graduation_year'] ?? ''}'),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  onPressed: () => setState(() => _educationList.removeAt(i)),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _addEducation,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _addEducation() {
    final instCtrl = TextEditingController();
    final facCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Education', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            _sheetField(instCtrl, 'Institution name'),
            const SizedBox(height: 12),
            _sheetField(facCtrl, 'Faculty'),
            const SizedBox(height: 12),
            _sheetField(specCtrl, 'Specialization'),
            const SizedBox(height: 12),
            _sheetField(yearCtrl, 'Graduation year', type: TextInputType.number),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (instCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _educationList.add({
                      'institution': instCtrl.text.trim(),
                      'faculty': facCtrl.text.trim(),
                      'specialization': specCtrl.text.trim(),
                      'graduation_year': yearCtrl.text.trim(),
                    });
                  });
                }
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 5: Skills ──

  Widget _stepSkills(ResumeProvider prov, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What skills do you have?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('You can select up to 30 skills',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prov.skillChoices.map((skill) {
              final selected = _selectedSkills.contains(skill);
              return FilterChip(
                label: Text(skill),
                selected: selected,
                selectedColor: cs.primaryContainer,
                onSelected: (val) {
                  setState(() {
                    if (val && _selectedSkills.length < 30) {
                      _selectedSkills.add(skill);
                    } else {
                      _selectedSkills.remove(skill);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('My skills (${_selectedSkills.length}/30)',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ── Step 6: Work Experience ──

  Widget _stepWorkExperience(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where have you worked?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._workList.asMap().entries.map((entry) {
            final i = entry.key;
            final job = entry.value;
            final end = job['end_date']?.isNotEmpty == true ? job['end_date'] : 'Present';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${job['position']}'),
                subtitle: Text('${job['company']} | ${job['start_date']} - $end'),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  onPressed: () => setState(() => _workList.removeAt(i)),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _addWork,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _addWork() {
    final posCtrl = TextEditingController();
    final compCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    bool isCurrent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Work Experience', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              _sheetField(posCtrl, 'Position'),
              const SizedBox(height: 12),
              _sheetField(compCtrl, 'Company'),
              const SizedBox(height: 12),
              _sheetField(startCtrl, 'Start date (e.g. March 2020)'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      enabled: !isCurrent,
                      decoration: InputDecoration(
                        labelText: 'End date',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Current'),
                    selected: isCurrent,
                    onSelected: (v) => setBS(() {
                      isCurrent = v;
                      if (v) endCtrl.clear();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (posCtrl.text.trim().isNotEmpty && compCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      _workList.add({
                        'position': posCtrl.text.trim(),
                        'company': compCtrl.text.trim(),
                        'start_date': startCtrl.text.trim(),
                        'end_date': isCurrent ? '' : endCtrl.text.trim(),
                      });
                    });
                  }
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController ctrl, String label, {TextInputType? type}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }
}
