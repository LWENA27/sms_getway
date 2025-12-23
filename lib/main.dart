import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/tenant_service.dart';
import 'services/local_data_service.dart';
import 'screens/contacts_screen.dart';
import 'screens/bulk_sms_screen.dart';
import 'screens/sms_logs_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tenant_selector_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    debugPrint('✅ Supabase initialized successfully!');
  } catch (e) {
    debugPrint('❌ Supabase initialization error: $e');
  }

  // Initialize TenantService
  await TenantService().initialize();

  // Initialize LocalDataService (offline-first)
  await LocalDataService().initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      // Use a key to force complete rebuild when theme changes
      // This prevents animation interpolation errors during theme transitions
      key: ValueKey('app_${themeProvider.isDarkMode}'),
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper to handle authentication and tenant selection state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingTenant = true;
  bool _needsTenantSelection = false;
  List<TenantModel> _tenants = [];

  @override
  void initState() {
    super.initState();
    _checkAuthAndTenant();
  }

  Future<void> _checkAuthAndTenant() async {
    final session = Supabase.instance.client.auth.currentSession;
    final tenantService = TenantService();

    if (session == null) {
      // Not logged in
      setState(() {
        _isCheckingTenant = false;
        _needsTenantSelection = false;
      });
      return;
    }

    // User is logged in, check if tenant is already selected
    if (tenantService.hasTenant) {
      // Tenant already selected, proceed to home
      setState(() {
        _isCheckingTenant = false;
        _needsTenantSelection = false;
      });
      return;
    }

    // Load tenants for user
    final hasAccess = await tenantService.loadTenantsForUser(session.user.id);

    if (!hasAccess || tenantService.tenantsCount == 0) {
      // No access - will show error on home page or redirect to login
      setState(() {
        _isCheckingTenant = false;
        _needsTenantSelection = false;
      });
      return;
    }

    // Check if user needs to pick tenant (2+ tenants)
    if (tenantService.shouldShowTenantPicker) {
      setState(() {
        _tenants = tenantService.tenants;
        _needsTenantSelection = true;
        _isCheckingTenant = false;
      });
    } else {
      // Single tenant, already auto-selected
      setState(() {
        _isCheckingTenant = false;
        _needsTenantSelection = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    // Show loading while checking tenant
    if (_isCheckingTenant) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading workspace...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Not logged in
    if (session == null) {
      return const LoginPage();
    }

    // Needs tenant selection (2+ tenants)
    if (_needsTenantSelection && _tenants.isNotEmpty) {
      return TenantSelectorScreen(
        tenants: _tenants,
      );
    }

    // Logged in with tenant selected
    return const HomePage();
  }
}

/// Login Page
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('SMS Gateway'),
      //   elevation: 0,
      // ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.1),
            // Logo or Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sms,
                size: 50,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            Text(
              'SMS Gateway',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.paddingSmall),
            Text(
              'Professional Bulk SMS Management',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.08),
            // Email field
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            // Password field
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: AppTheme.paddingLarge),
            // Error message
            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingMedium),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.errorColor),
                ),
                child: Text(
                  errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.errorColor,
                      ),
                ),
              ),
            if (errorMessage != null)
              const SizedBox(height: AppTheme.paddingLarge),
            // Login button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _login,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Login'),
              ),
            ),
            const SizedBox(height: AppTheme.paddingMedium),
            // Sign up link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                GestureDetector(
                  onTap: isLoading ? null : _signup,
                  child: Text(
                    'Sign Up',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'Email and password are required';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth
          .signInWithPassword(
            email: emailController.text,
            password: passwordController.text,
          )
          .timeout(const Duration(seconds: 10));

      if (response.user != null && mounted) {
        debugPrint('✅ Login successful: ${response.user!.email}');

        // Load tenants for user
        final tenantService = TenantService();
        final hasAccess =
            await tenantService.loadTenantsForUser(response.user!.id);

        if (!hasAccess || tenantService.tenantsCount == 0) {
          setState(() {
            errorMessage =
                'You do not have access to SMS Gateway. Contact your administrator.';
            isLoading = false;
          });
          // Sign out since user has no access
          await Supabase.instance.client.auth.signOut();
          return;
        }

        if (mounted) {
          // Check if user needs to pick tenant (2+ tenants)
          if (tenantService.shouldShowTenantPicker) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => TenantSelectorScreen(
                  tenants: tenantService.tenants,
                ),
              ),
            );
          } else {
            // Single tenant, already auto-selected
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Login failed: ${e.toString()}';
      });
      debugPrint('❌ Login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _signup() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'Email and password are required';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth
          .signUp(
            email: emailController.text,
            password: passwordController.text,
          )
          .timeout(const Duration(seconds: 10));

      if (response.user != null && mounted) {
        debugPrint('✅ Sign up successful: ${response.user!.email}');
        setState(() {
          errorMessage = 'Account created! Please login.';
        });
        emailController.clear();
        passwordController.clear();
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Sign up failed: ${e.toString()}';
      });
      debugPrint('❌ Sign up error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

/// Home Page (Main Dashboard)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? currentUserEmail;
  String? currentTenantName;
  int contactCount = 0;
  int groupCount = 0;
  int smsLogCount = 0;
  bool isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      final tenantService = TenantService();
      final tenantId = tenantService.tenantId;

      if (authUser != null && tenantId != null) {
        setState(() {
          currentUserEmail = authUser.email;
          currentTenantName = tenantService.tenantName;
        });

        // Pull initial data from Supabase to local DB
        await LocalDataService().loadTenantData(tenantId);

        // Load counts from local database (offline-first)
        final counts = await LocalDataService().getDashboardCounts();

        if (mounted) {
          setState(() {
            contactCount = counts['contacts'] ?? 0;
            groupCount = counts['groups'] ?? 0;
            smsLogCount = counts['smsLogs'] ?? 0;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboard(),
      const ContactsScreen(),
      BulkSmsScreen(
        onNavigateToLogs: () {
          setState(() {
            _currentIndex = 3; // Navigate to Logs tab
          });
        },
      ),
      const SmsLogsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Gateway'),
        elevation: 0,
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.send),
            label: 'Send',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildDashboard() {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : RefreshIndicator(
            onRefresh: () async {
              _loadData();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.paddingLarge),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome! 👋',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(
                            height: AppTheme.paddingSmall,
                          ),
                          Text(
                            currentTenantName ?? 'Workspace',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentUserEmail ?? 'User',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.paddingLarge),
                  // Statistics
                  Text(
                    'Quick Stats',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTheme.paddingMedium),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppTheme.paddingMedium,
                    crossAxisSpacing: AppTheme.paddingMedium,
                    children: [
                      _buildStatCard(
                        context,
                        icon: Icons.contacts,
                        label: 'Contacts',
                        value: '$contactCount',
                        color: Colors.blue,
                      ),
                      _buildStatCard(
                        context,
                        icon: Icons.group,
                        label: 'Groups',
                        value: '$groupCount',
                        color: Colors.green,
                      ),
                      _buildStatCard(
                        context,
                        icon: Icons.mail,
                        label: 'SMS Logs',
                        value: '$smsLogCount',
                        color: Colors.orange,
                      ),
                      _buildStatCard(
                        context,
                        icon: Icons.info,
                        label: 'Status',
                        value: 'Active',
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: AppTheme.paddingSmall),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: color),
            ),
            const SizedBox(height: AppTheme.paddingSmall),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool isDone,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 32),
            const SizedBox(width: AppTheme.paddingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              isDone ? Icons.check_circle : Icons.schedule,
              color: isDone ? Colors.green : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}
