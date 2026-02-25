import 'package:alkaram_hosiery/services/production_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'models/employee_models.dart';
import 'models/production_record.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────────────────────
class _AppColors {
  static const bg = Color(0xFF0D0F14);
  static const surface = Color(0xFF151820);
  static const surfaceElevated = Color(0xFF1C2030);
  static const border = Color(0xFF252A3A);
  static const borderLight = Color(0xFF2E3448);

  static const amber = Color(0xFFF5A623);
  static const amberDim = Color(0x33F5A623);
  static const amberGlow = Color(0x1AF5A623);

  static const green = Color(0xFF2DD4A0);
  static const greenDim = Color(0x202DD4A0);
  static const greenGlow = Color(0x102DD4A0);

  static const blue = Color(0xFF4A9EFF);
  static const blueDim = Color(0x204A9EFF);

  static const red = Color(0xFFFF5A5A);
  static const redDim = Color(0x20FF5A5A);

  static const textPrimary = Color(0xFFEEF0F6);
  static const textSecondary = Color(0xFF8B91A8);
  static const textMuted = Color(0xFF4E5468);
}

class _AppTextStyles {
  static const displayLarge = TextStyle(
    fontFamily: 'Courier',
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: _AppColors.textPrimary,
    letterSpacing: -1.5,
  );

  static const headingMd = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: _AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: _AppColors.textSecondary,
    letterSpacing: 1.2,
  );

  static const mono = TextStyle(
    fontFamily: 'Courier',
    fontSize: 13,
    color: _AppColors.textSecondary,
    letterSpacing: 0.5,
  );
}

// ─────────────────────────────────────────────────────────────
//  Main Page
// ─────────────────────────────────────────────────────────────
class ProductionTrackingPage extends StatefulWidget {
  final PerPieceEmployee employee;
  const ProductionTrackingPage({super.key, required this.employee});

  @override
  State<ProductionTrackingPage> createState() => _ProductionTrackingPageState();
}

class _ProductionTrackingPageState extends State<ProductionTrackingPage>
    with TickerProviderStateMixin {
  final ProductionServiceRealtime _productionService = ProductionServiceRealtime();
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _piecesController = TextEditingController();

  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  bool _isSessionActive = false;
  ActiveProductionSession? _activeSession;
  double _productionRate = 1.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkActiveSession();
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _piecesController.dispose();
    _pulseController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _checkActiveSession() {
    _productionService.getActiveSession(widget.employee.id).listen((session) {
      setState(() {
        _activeSession = session;
        _isSessionActive = session != null;
      });
    });
  }

  int _calculatePiecesFromInput() => int.tryParse(_piecesController.text) ?? 0;
  int _calculatePiecesFromMinutes() {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    if (minutes == 0 || _productionRate <= 0) return 0;
    return (minutes / _productionRate).floor();
  }

  // ─── Snackbar Helpers ───────────────────────────────────────
  void _showSnack(String msg, {Color color = _AppColors.green, int seconds = 3}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: _AppColors.textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: _AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        duration: Duration(seconds: seconds),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ─── Actions ────────────────────────────────────────────────
  Future<void> _startSession() async {
    HapticFeedback.mediumImpact();
    try {
      await _productionService.startProductionSession(widget.employee);
      _showSnack('Production session started');
    } catch (e) {
      _showSnack('Error: $e', color: _AppColors.red);
    }
  }

  Future<void> _addPieces() async {
    final pieces = int.tryParse(_piecesController.text);
    if (pieces == null || pieces <= 0) {
      _showSnack('Enter a valid piece count', color: _AppColors.amber);
      return;
    }
    try {
      await _productionService.updatePiecesInSession(widget.employee.id, pieces);
      _piecesController.clear();
      HapticFeedback.lightImpact();
      _showSnack(
        '+$pieces pieces  ·  ${(pieces * widget.employee.ratePerPiece).toStringAsFixed(2)} earned',
      );
    } catch (e) {
      _showSnack('Error: $e', color: _AppColors.red);
    }
  }

  Future<void> _addProductionTime() async {
    final minutes = int.tryParse(_minutesController.text);
    if (minutes == null || minutes <= 0) {
      _showSnack('Enter valid minutes', color: _AppColors.amber);
      return;
    }
    final piecesToAdd = (minutes / _productionRate).floor();
    if (piecesToAdd <= 0) {
      _showSnack(
        'Need ${_productionRate.toStringAsFixed(1)} min/pc. Not enough time.',
        color: _AppColors.amber,
        seconds: 4,
      );
      return;
    }
    try {
      await _productionService.updatePiecesInSession(widget.employee.id, piecesToAdd);
      final remaining = minutes - (piecesToAdd * _productionRate);
      _minutesController.clear();
      HapticFeedback.lightImpact();
      _showSnack(
        '+$piecesToAdd pieces'
            '${remaining > 0 ? '  ·  ${remaining.toStringAsFixed(1)} min leftover' : ''}'
            '  ·  ${(piecesToAdd * widget.employee.ratePerPiece).toStringAsFixed(2)}',
        seconds: 4,
      );
    } catch (e) {
      _showSnack('Error: $e', color: _AppColors.red);
    }
  }

  Future<void> _endSession() async {
    final totalEarnings = widget.employee.ratePerPiece * _activeSession!.piecesProduced;
    final confirm = await _showConfirmSheet(
      title: 'End Session',
      subtitle:
      '${_activeSession!.piecesProduced} pieces  ·  ${totalEarnings.toStringAsFixed(2)} earned',
      confirmLabel: 'End Session',
      confirmColor: _AppColors.green,
    );
    if (confirm == true) {
      try {
        await _productionService.endProductionSession(widget.employee.id);
        _showSnack('Session saved successfully');
      } catch (e) {
        _showSnack('Error: $e', color: _AppColors.red);
      }
    }
  }

  Future<void> _cancelSession() async {
    final confirm = await _showConfirmSheet(
      title: 'Discard Session',
      subtitle: 'All progress will be permanently lost.',
      confirmLabel: 'Discard',
      confirmColor: _AppColors.red,
    );
    if (confirm == true) {
      try {
        await _productionService.cancelProductionSession(widget.employee.id);
        _showSnack('Session discarded', color: _AppColors.amber);
      } catch (e) {
        _showSnack('Error: $e', color: _AppColors.red);
      }
    }
  }

  Future<bool?> _showConfirmSheet({
    required String title,
    required String subtitle,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _AppTextStyles.headingMd.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(color: _AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _OutlineBtn(
                    label: 'Go Back',
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SolidBtn(
                    label: confirmLabel,
                    color: confirmColor,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _AppColors.bg,
        colorScheme: const ColorScheme.dark(primary: _AppColors.amber),
      ),
      child: Scaffold(
        backgroundColor: _AppColors.bg,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverAppBar(innerBoxIsScrolled),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveTab(),
              _buildHistoryTab(),
              _buildStatsTab(),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: _AppColors.bg,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _AppColors.textSecondary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 60, bottom: 60),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.employee.name.toUpperCase(),
              style: _AppTextStyles.headingMd.copyWith(fontSize: 16),
            ),
            Text(
              'PRODUCTION TRACKER',
              style: _AppTextStyles.label.copyWith(color: _AppColors.amber, fontSize: 9),
            ),
          ],
        ),
        background: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _AppColors.amberGlow,
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _AppColors.amberDim,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _AppColors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, size: 14, color: _AppColors.amber),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.employee.ratePerPiece.toStringAsFixed(2)} / pc',
                      style: const TextStyle(
                        color: _AppColors.amber,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: _buildTabBar(),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      height: 40,
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _AppColors.border),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _AppColors.borderLight),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        dividerColor: Colors.transparent,
        labelColor: _AppColors.textPrimary,
        unselectedLabelColor: _AppColors.textMuted,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        tabs: const [
          Tab(text: 'ACTIVE'),
          Tab(text: 'HISTORY'),
          Tab(text: 'STATS'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  ACTIVE TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildActiveTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: _isSessionActive ? _buildActiveSessionUI() : _buildStartSessionUI(),
    );
  }

  Widget _buildStartSessionUI() {
    return Column(
      children: [
        const SizedBox(height: 32),
        // Idle state indicator
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _AppColors.amberGlow,
                boxShadow: [
                  BoxShadow(
                    color: _AppColors.amber.withOpacity(0.15 * _pulseAnimation.value),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 48, color: _AppColors.amber),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'No Active Session',
          style: _AppTextStyles.headingMd.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 6),
        const Text(
          'Configure your production rate and begin tracking',
          style: TextStyle(color: _AppColors.textSecondary, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // Rate config card
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PRODUCTION RATE', style: _AppTextStyles.label),
              const SizedBox(height: 16),
              _DarkTextField(
                initialValue: _productionRate.toString(),
                label: 'Minutes per Piece',
                suffix: 'min/pc',
                icon: Icons.speed_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final r = double.tryParse(v);
                  if (r != null && r > 0) setState(() => _productionRate = r);
                },
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Estimated hourly output',
                value: '${(60 / _productionRate).toStringAsFixed(1)} pcs/hr',
                valueColor: _AppColors.blue,
              ),
              _InfoRow(
                label: 'Estimated hourly earnings',
                value:
                '${(60 / _productionRate * widget.employee.ratePerPiece).toStringAsFixed(2)}/hr',
                valueColor: _AppColors.green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SolidBtn(
          label: 'Start Session',
          color: _AppColors.amber,
          textColor: _AppColors.bg,
          icon: Icons.play_arrow_rounded,
          onTap: _startSession,
          large: true,
        ),
      ],
    );
  }

  Widget _buildActiveSessionUI() {
    final earnings = widget.employee.ratePerPiece * (_activeSession?.piecesProduced ?? 0);
    final duration = DateTime.now().difference(_activeSession!.startTime);

    return Column(
      children: [
        const SizedBox(height: 8),

        // ── Live Metrics ──────────────────────────────────────
        _Card(
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _AppColors.green.withOpacity(_pulseAnimation.value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE SESSION  ·  ${_timeFormat.format(_activeSession!.startTime)}',
                    style: _AppTextStyles.label.copyWith(color: _AppColors.green),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(duration),
                    style: _AppTextStyles.mono.copyWith(color: _AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Big earnings display
              Center(
                child: Column(
                  children: [
                    const Text('CURRENT EARNINGS', style: _AppTextStyles.label),
                    const SizedBox(height: 8),
                    Text(
                      '${earnings.toStringAsFixed(2)}',
                      style: _AppTextStyles.displayLarge.copyWith(
                        color: _AppColors.green,
                        fontSize: 48,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: _AppColors.border, height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'PIECES',
                      value: '${_activeSession!.piecesProduced}',
                      icon: Icons.inventory_2_outlined,
                      color: _AppColors.amber,
                    ),
                  ),
                  Container(width: 1, height: 48, color: _AppColors.border),
                  Expanded(
                    child: _MetricTile(
                      label: 'RATE',
                      value: '${widget.employee.ratePerPiece.toStringAsFixed(2)}',
                      icon: Icons.sell_outlined,
                      color: _AppColors.blue,
                    ),
                  ),
                  Container(width: 1, height: 48, color: _AppColors.border),
                  Expanded(
                    child: _MetricTile(
                      label: 'PCS/HR',
                      value: duration.inMinutes > 0
                          ? (((_activeSession!.piecesProduced) / duration.inMinutes) * 60)
                          .toStringAsFixed(1)
                          : '—',
                      icon: Icons.trending_up_rounded,
                      color: _AppColors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Add Pieces Directly ───────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _AppColors.amberDim,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_box_outlined, size: 16, color: _AppColors.amber),
                  ),
                  const SizedBox(width: 10),
                  const Text('ADD PIECES DIRECTLY', style: _AppTextStyles.label),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _DarkTextField(
                      controller: _piecesController,
                      label: 'Piece Count',
                      suffix: 'pcs',
                      icon: Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SolidBtn(
                    label: 'Add',
                    color: _AppColors.amber,
                    textColor: _AppColors.bg,
                    onTap: _addPieces,
                  ),
                ],
              ),
              if (_piecesController.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                _EarningsPreview(
                  pieces: _calculatePiecesFromInput(),
                  rate: widget.employee.ratePerPiece,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Add via Time ──────────────────────────────────────
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _AppColors.blueDim,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.timer_outlined, size: 16, color: _AppColors.blue),
                  ),
                  const SizedBox(width: 10),
                  const Text('ADD VIA TIME', style: _AppTextStyles.label),
                ],
              ),
              const SizedBox(height: 16),
              _DarkTextField(
                initialValue: _productionRate.toString(),
                label: 'Minutes per Piece',
                suffix: 'min/pc',
                icon: Icons.speed_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final r = double.tryParse(v);
                  if (r != null && r > 0) setState(() => _productionRate = r);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _DarkTextField(
                      controller: _minutesController,
                      label: 'Minutes Worked',
                      suffix: 'min',
                      icon: Icons.hourglass_empty_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SolidBtn(
                    label: 'Add',
                    color: _AppColors.blue,
                    textColor: Colors.white,
                    onTap: _addProductionTime,
                  ),
                ],
              ),
              if (_minutesController.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                _EarningsPreview(
                  pieces: _calculatePiecesFromMinutes(),
                  rate: widget.employee.ratePerPiece,
                  minuteLabel:
                  '${_minutesController.text} min ÷ ${_productionRate.toStringAsFixed(1)} min/pc',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Session Actions ───────────────────────────────────
        Row(
          children: [
            _OutlineBtn(
              label: 'Discard',
              color: _AppColors.red,
              icon: Icons.delete_outline_rounded,
              onTap: _cancelSession,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SolidBtn(
                label: 'End & Save Session',
                color: _AppColors.green,
                textColor: _AppColors.bg,
                icon: Icons.save_alt_rounded,
                onTap: _endSession,
                large: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  HISTORY TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    return StreamBuilder<List<ProductionRecord>>(
      stream: _productionService.getEmployeeProductionRecords(widget.employee.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) return _buildEmptyHistoryState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: records.length,
          itemBuilder: (context, index) => _buildHistoryCard(records[index], index),
        );
      },
    );
  }

  Widget _buildHistoryCard(ProductionRecord record, int index) {
    final earnings = record.totalEarnings;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          iconColor: _AppColors.textSecondary,
          collapsedIconColor: _AppColors.textMuted,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _AppColors.borderLight),
            ),
            child: Center(
              child: Text(
                '${record.piecesProduced}',
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.w700,
                  color: _AppColors.amber,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          title: Text(
            '${earnings.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _AppColors.green,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                _dateFormat.format(record.startTime),
                style: _AppTextStyles.label.copyWith(color: _AppColors.textMuted, fontSize: 10),
              ),
              Text(
                '${_timeFormat.format(record.startTime)} → ${_timeFormat.format(record.endTime)}',
                style: const TextStyle(color: _AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _AppColors.border)),
              ),
              child: Column(
                children: [
                  _ExpandedDetailRow('Duration', '${record.durationInMinutes} min',
                      Icons.timer_outlined, _AppColors.blue),
                  _ExpandedDetailRow('Rate per Piece', '${record.ratePerPiece.toStringAsFixed(2)}',
                      Icons.sell_outlined, _AppColors.amber),
                  _ExpandedDetailRow('Total Earnings', '${earnings.toStringAsFixed(2)}',
                      Icons.account_balance_wallet_outlined, _AppColors.green),
                  _ExpandedDetailRow('Avg Pieces / Hr',
                      '${record.piecesPerHour.toStringAsFixed(1)} / hr', Icons.speed_rounded,
                      _AppColors.textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  STATS TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _productionService.getEmployeeProductionStats(widget.employee.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
        if (!snapshot.hasData) return _buildLoadingState();

        final s = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('OVERVIEW', style: _AppTextStyles.label),
              const SizedBox(height: 12),

              // Big total earnings
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A2A1E), Color(0xFF0D1510)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _AppColors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL EARNINGS', style: _AppTextStyles.label),
                    const SizedBox(height: 8),
                    Text(
                      '${s['totalEarnings']}',
                      style: _AppTextStyles.displayLarge.copyWith(
                        color: _AppColors.green,
                        fontSize: 44,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'across ${s['totalSessions']} sessions',
                      style: const TextStyle(color: _AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Grid of stat cards
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  _StatGridCard(
                    label: 'TOTAL PIECES',
                    value: '${s['totalPieces']}',
                    icon: Icons.inventory_2_outlined,
                    color: _AppColors.amber,
                  ),
                  _StatGridCard(
                    label: 'SESSIONS',
                    value: '${s['totalSessions']}',
                    icon: Icons.history_rounded,
                    color: _AppColors.blue,
                  ),
                  _StatGridCard(
                    label: 'AVG PCS/HR',
                    value: (s['averagePiecesPerHour'] as double).toStringAsFixed(1),
                    icon: Icons.speed_rounded,
                    color: _AppColors.green,
                  ),
                  _StatGridCard(
                    label: 'AVG PCS/SESSION',
                    value: (s['averagePiecesPerSession'] as double).toStringAsFixed(1),
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFFB06EFF),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Utility states ────────────────────────────────────────
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: _AppColors.amber,
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text('Loading...', style: TextStyle(color: _AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _AppColors.red),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style: TextStyle(color: _AppColors.textPrimary, fontSize: 16)),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(color: _AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _OutlineBtn(label: 'Retry', onTap: () => setState(() {})),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _AppColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: _AppColors.border),
            ),
            child: const Icon(Icons.history_rounded, size: 48, color: _AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          const Text('No Production History',
              style: TextStyle(
                  color: _AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 17)),
          const SizedBox(height: 8),
          const Text('Complete a session to see records here',
              style: TextStyle(color: _AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          _OutlineBtn(
            label: 'Go to Active',
            icon: Icons.play_arrow_rounded,
            onTap: () => _tabController.animateTo(0),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inHours)}:${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}';
  }
}

// ─────────────────────────────────────────────────────────────
//  Reusable Widgets
// ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _AppColors.border),
    ),
    child: child,
  );
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String suffix;
  final IconData icon;
  final TextInputType keyboardType;
  final void Function(String)? onChanged;

  const _DarkTextField({
    this.controller,
    this.initialValue,
    required this.label,
    required this.suffix,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      keyboardType: keyboardType,
      style: const TextStyle(color: _AppColors.textPrimary, fontSize: 15),
      cursorColor: _AppColors.amber,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _AppColors.textSecondary, fontSize: 13),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: _AppColors.textMuted, fontSize: 12),
        prefixIcon: Icon(icon, size: 18, color: _AppColors.textMuted),
        filled: true,
        fillColor: _AppColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _AppColors.amber, width: 1.5),
        ),
      ),
    );
  }
}

class _SolidBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final VoidCallback onTap;
  final bool large;

  const _SolidBtn({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.icon,
    required this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: large ? 52 : 48,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: large ? 15 : 14,
                letterSpacing: 0.3,
                color: textColor,
              )),
        ],
      ),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  const _OutlineBtn({
    required this.label,
    this.color = _AppColors.borderLight,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color == _AppColors.borderLight ? _AppColors.textSecondary : color,
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    ),
  );
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile(
      {required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            fontFamily: 'Courier',
          )),
      Text(label, style: _AppTextStyles.label.copyWith(fontSize: 9)),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _AppColors.textSecondary, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: valueColor, fontWeight: FontWeight.w600, fontSize: 13,
                fontFamily: 'Courier')),
      ],
    ),
  );
}

class _EarningsPreview extends StatelessWidget {
  final int pieces;
  final double rate;
  final String? minuteLabel;

  const _EarningsPreview({required this.pieces, required this.rate, this.minuteLabel});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _AppColors.greenDim,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _AppColors.green.withOpacity(0.2)),
    ),
    child: Column(
      children: [
        if (minuteLabel != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Calculation', style: TextStyle(color: _AppColors.textSecondary, fontSize: 12)),
              Text(minuteLabel!,
                  style: _AppTextStyles.mono.copyWith(fontSize: 11, color: _AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Pieces to add',
                style: TextStyle(color: _AppColors.textSecondary, fontSize: 13)),
            Text('$pieces pcs',
                style: const TextStyle(
                    color: _AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Earnings',
                style: TextStyle(color: _AppColors.textSecondary, fontSize: 13)),
            Text('${(pieces * rate).toStringAsFixed(2)}',
                style: const TextStyle(
                    color: _AppColors.green, fontWeight: FontWeight.w700, fontSize: 15,
                    fontFamily: 'Courier')),
          ],
        ),
      ],
    ),
  );
}

class _ExpandedDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ExpandedDetailRow(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, size: 15, color: color.withOpacity(0.7)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: _AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13,
                fontFamily: 'Courier')),
      ],
    ),
  );
}

class _StatGridCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatGridCard(
      {required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: _AppTextStyles.label.copyWith(fontSize: 9, color: color.withOpacity(0.7))),
          ],
        ),
        Text(value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFamily: 'Courier',
              letterSpacing: -0.5,
            )),
      ],
    ),
  );
}