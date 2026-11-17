import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/check_screen.dart';
import 'screens/history_screen.dart';
import 'screens/learn_screen.dart';
import 'state/history_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 3 startup: load the engine (bundled rules, or a copy cached by
  // Phase 4) and the saved history before the first frame draws.
  final store = HistoryStore();
  await store.init();

  runApp(ScamShieldApp(store: store));
}

class ScamShieldApp extends StatelessWidget {
  final HistoryStore store;

  const ScamShieldApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    // One store for the whole app: Check and History tabs both
    // read from (and write to) the same source of truth.
    return ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        title: 'Scam Shield',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            brightness: Brightness.dark,
            seedColor: const Color(0xFF10B981),
            primary: const Color(0xFFE5B842),
            surface: const Color(0xFF0E231C),
          ),
          scaffoldBackgroundColor: const Color(0xFF071510),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: const Color(0xFF143328),
            contentTextStyle: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        ),
        home: const HomeShell(),
      ),
    );
  }
}

/// The 3-tab shell: Check / History / Learn.
///
/// The Result screen is NOT a tab - it is pushed on top of this shell
/// with Navigator.push when the big CHECK button is tapped.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  // IndexedStack keeps all three tabs alive, so switching tabs
  // never loses what the user was doing.
  static const _screens = [
    CheckScreen(),
    HistoryScreen(),
    LearnScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Phase 4.5: listen for app resume -> auto-sync rules.
    WidgetsBinding.instance.addObserver(this);
    // Phase 4: the first frame always paints with the current rules,
    // then we quietly ask FastAPI for newer ones in the background.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HistoryStore>().syncRules();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Zero-F5: returning to the app refreshes rules (syncRules itself
    // is silent-offline; the 15s throttle lives in syncBeforeCheck).
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<HistoryStore>().syncRules();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071510),
      appBar: AppBar(
        toolbarHeight: 62,
        backgroundColor: const Color(0xFF071510),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Consumer<HistoryStore>(
            builder: (context, store, _) => Row(
              children: [
                // Warm Gold Rounded-Square Shield Badge
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5B842),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF071510),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Scam Shield',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF8FAFC),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Live Rules Pill ("● Rules v5 (16)")
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E231C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1F3D32)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Scam Protection Active',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.65),
            radius: 1.1,
            colors: [Color(0xFF0F2E22), Color(0xFF071510)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: IndexedStack(index: _index, children: _screens),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1E17),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: const Color(0xFF1D3B30)),
                ),
                child: Row(
                  children: [
                    _PillNavItem(
                      icon: Icons.shield_outlined,
                      activeIcon: Icons.shield_rounded,
                      label: 'Check',
                      selected: _index == 0,
                      onTap: () => setState(() => _index = 0),
                    ),
                    _PillNavItem(
                      icon: Icons.history_rounded,
                      activeIcon: Icons.history_rounded,
                      label: 'History',
                      selected: _index == 1,
                      onTap: () => setState(() => _index = 1),
                    ),
                    _PillNavItem(
                      icon: Icons.menu_book_outlined,
                      activeIcon: Icons.menu_book_rounded,
                      label: 'Learn',
                      selected: _index == 2,
                      onTap: () => setState(() => _index = 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? const Color(0xFF34D399) : const Color(0xFF94A3B8);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF15392B) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
