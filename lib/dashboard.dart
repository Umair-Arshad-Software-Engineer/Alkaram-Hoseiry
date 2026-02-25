import 'package:alkaram_hosiery/services/employee_services.dart';
import 'package:flutter/material.dart';
import 'EmployeeManagementPage.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  final RealtimeDatabaseService _databaseService = RealtimeDatabaseService();
  Map<String, dynamic> _statistics = {
    'total': 0,
    'monthly': 0,
    'daily': 0,
    'perPiece': 0,
  };
  bool _isLoading = true;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Design tokens
  static const Color _bgPrimary = Color(0xFF0D1117);
  static const Color _bgSecondary = Color(0xFF161B22);
  static const Color _bgCard = Color(0xFF1C2333);
  static const Color _accentAmber = Color(0xFFF0A500);
  static const Color _accentTeal = Color(0xFF00B4D8);
  static const Color _accentGreen = Color(0xFF3FB950);
  static const Color _accentPurple = Color(0xFF8B5CF6);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF7D8590);
  static const Color _borderColor = Color(0xFF30363D);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _loadStatistics();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    final stats = await _databaseService.getStatistics();
    setState(() {
      _statistics = stats;
      _isLoading = false;
    });
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: _accentAmber,
          strokeWidth: 2,
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),
                    _buildSectionLabel('WORKFORCE OVERVIEW'),
                    const SizedBox(height: 14),
                    _buildStatsGrid(),
                    const SizedBox(height: 32),
                    _buildSectionLabel('QUICK NAVIGATION'),
                    const SizedBox(height: 14),
                    _buildActionGrid(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: _bgSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _borderColor),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            color: _bgSecondary,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentAmber.withOpacity(0.04),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                top: 10,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accentAmber.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _accentAmber,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Al-Karam Hosiery',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        'Employee Management System',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: _accentAmber,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Dashboard',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _textSecondary, size: 20),
          onPressed: () {
            setState(() => _isLoading = true);
            _fadeController.reset();
            _slideController.reset();
            _loadStatistics();
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: _borderColor),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatConfig(
        label: 'Total Employees',
        value: _statistics['total'].toString(),
        icon: Icons.groups_rounded,
        color: _accentAmber,
        trend: 'Active employees',
      ),
      _StatConfig(
        label: 'Monthly Wage',
        value: _statistics['monthly'].toString(),
        icon: Icons.calendar_month_rounded,
        color: _accentTeal,
        trend: 'Salaried',
      ),
      _StatConfig(
        label: 'Daily Wage',
        value: _statistics['daily'].toString(),
        icon: Icons.today_rounded,
        color: _accentGreen,
        trend: 'Daily workers',
      ),
      _StatConfig(
        label: 'Per Piece',
        value: _statistics['perPiece'].toString(),
        icon: Icons.inventory_2_rounded,
        color: _accentPurple,
        trend: 'Production',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) => _buildStatCard(stats[i]),
    );
  }

  Widget _buildStatCard(_StatConfig stat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: stat.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(stat.icon, color: stat.color, size: 17),
              ),
              Text(
                stat.value,
                style: TextStyle(
                  color: stat.color,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.label,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat.trend,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    final actions = [
      _ActionConfig(
        title: 'All Employees',
        subtitle: 'View & manage all staff',
        icon: Icons.people_alt_rounded,
        color: _accentAmber,
        tab: 0,
      ),
      _ActionConfig(
        title: 'Monthly Staff',
        subtitle: 'Salaried employees',
        icon: Icons.calendar_month_rounded,
        color: _accentTeal,
        tab: 1,
      ),
      _ActionConfig(
        title: 'Daily Workers',
        subtitle: 'Daily wage staff',
        icon: Icons.today_rounded,
        color: _accentGreen,
        tab: 2,
      ),
      _ActionConfig(
        title: 'Per Piece',
        subtitle: 'Production workers',
        icon: Icons.inventory_2_rounded,
        color: _accentPurple,
        tab: 3,
      ),
    ];

    return Column(
      children: actions
          .map((action) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildActionTile(action),
      ))
          .toList(),
    );
  }

  Widget _buildActionTile(_ActionConfig action) {
    return Material(
      color: _bgCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: action.color.withOpacity(0.08),
        highlightColor: action.color.withOpacity(0.04),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeManagementPage(
                initialTab: action.tab,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: action.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: _textSecondary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatConfig {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  const _StatConfig({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
  });
}

class _ActionConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int tab;
  const _ActionConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tab,
  });
}