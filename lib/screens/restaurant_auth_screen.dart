import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/multi_tenant_auth_service.dart';
import 'order_type_selection_screen.dart';

/// Restaurant authentication screen for multi-tenant POS system
/// Handles both restaurant registration and user login
class RestaurantAuthScreen extends StatefulWidget {
  const RestaurantAuthScreen({super.key});

  @override
  State<RestaurantAuthScreen> createState() => _RestaurantAuthScreenState();
}

class _RestaurantAuthScreenState extends State<RestaurantAuthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Controllers for registration
  final _regNameController = TextEditingController();
  final _regBusinessTypeController = TextEditingController();
  final _regAddressController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regAdminUserController = TextEditingController();
  final _regAdminPasswordController = TextEditingController();

  // Controllers for login
  final _loginEmailController = TextEditingController();
  final _loginUserController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Form keys
  final _registrationFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();

  // UI state
  bool _obscureRegPassword = true;
  bool _obscureLoginPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _regNameController.dispose();
    _regBusinessTypeController.dispose();
    _regAddressController.dispose();
    _regPhoneController.dispose();
    _regEmailController.dispose();
    _regAdminUserController.dispose();
    _regAdminPasswordController.dispose();
    _loginEmailController.dispose();
    _loginUserController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive header sizing
        final isTablet = constraints.maxWidth > 600;
        final logoSize = isTablet ? 90.0 : 70.0;
        final iconSize = isTablet ? 45.0 : 35.0;
        
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 24,
            vertical: isTablet ? 32 : 20,
          ),
          child: Column(
            children: [
              // App Logo
              Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isTablet ? 24 : 18),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: isTablet ? 20 : 16),

              // Title
              Text(
                'Restaurant POS',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 32 : 24,
                      letterSpacing: 0.5,
                    ),
              ),
              SizedBox(height: isTablet ? 12 : 8),

              Text(
                'Multi-Tenant Point of Sale System',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: isTablet ? 16 : 14,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Register Restaurant'),
                Tab(text: 'Login'),
              ],
              labelColor: const Color(0xFF667eea),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF667eea),
              indicatorWeight: 3,
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRegistrationTab(),
                _buildLoginTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationTab() {
    return Consumer<MultiTenantAuthService>(
      builder: (context, authService, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Responsive form width - constrain on larger screens
            final formWidth = constraints.maxWidth > 800 
                ? 500.0  // Fixed width for tablets
                : constraints.maxWidth > 600 
                    ? constraints.maxWidth * 0.8  // 80% width for medium screens
                    : constraints.maxWidth - 48;  // Full width minus padding for phones
            
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: Center(
                child: SizedBox(
                  width: formWidth,
                  child: Form(
                    key: _registrationFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Register Your Restaurant',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Restaurant Name
                        _buildTextField(
                          controller: _regNameController,
                          label: 'Restaurant Name',
                          icon: Icons.restaurant,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Restaurant name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Business Type
                        _buildTextField(
                          controller: _regBusinessTypeController,
                          label: 'Business Type (e.g., Fine Dining, Fast Food)',
                          icon: Icons.business,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Business type is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Address
                        _buildTextField(
                          controller: _regAddressController,
                          label: 'Address',
                          icon: Icons.location_on,
                          maxLines: 2,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Address is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        _buildTextField(
                          controller: _regPhoneController,
                          label: 'Phone Number',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Phone number is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email
                        _buildTextField(
                          controller: _regEmailController,
                          label: 'Email Address',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Email is required';
                            }
                            if (!value!.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Admin User Setup',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                        ),
                        const SizedBox(height: 16),

                        // Admin Username
                        _buildTextField(
                          controller: _regAdminUserController,
                          label: 'Admin Username',
                          icon: Icons.admin_panel_settings,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Admin username is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Admin Password
                        _buildTextField(
                          controller: _regAdminPasswordController,
                          label: 'Admin Password',
                          icon: Icons.lock,
                          obscureText: _obscureRegPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureRegPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureRegPassword = !_obscureRegPassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Password is required';
                            }
                            if (value!.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Error message
                        if (authService.lastError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              authService.lastError!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),

                        // Register Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: authService.isLoading ? null : _handleRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: authService.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Register Restaurant',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoginTab() {
    return Consumer<MultiTenantAuthService>(
      builder: (context, authService, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Responsive form width - constrain on larger screens
            final formWidth = constraints.maxWidth > 800 
                ? 450.0  // Slightly smaller width for login (fewer fields)
                : constraints.maxWidth > 600 
                    ? constraints.maxWidth * 0.8  // 80% width for medium screens
                    : constraints.maxWidth - 48;  // Full width minus padding for phones
            
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: Center(
                child: SizedBox(
                  width: formWidth,
                  child: Form(
                    key: _loginFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Restaurant Login',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Restaurant Email
                        _buildTextField(
                          controller: _loginEmailController,
                          label: 'Restaurant Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Restaurant email is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // User ID
                        _buildTextField(
                          controller: _loginUserController,
                          label: 'User ID',
                          icon: Icons.person,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'User ID is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        _buildTextField(
                          controller: _loginPasswordController,
                          label: 'Password',
                          icon: Icons.lock,
                          obscureText: _obscureLoginPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureLoginPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureLoginPassword = !_obscureLoginPassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Password is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Error message
                        if (authService.lastError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              authService.lastError!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),

                        // Login Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: authService.isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: authService.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Help text
                        Text(
                          'New restaurant? Switch to the Register tab to create your account.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Registered Restaurants Info
                        if (authService.registeredRestaurants.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'Registered Restaurants',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          ...authService.registeredRestaurants.map((restaurant) => 
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.restaurant, color: Colors.grey.shade600),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          restaurant.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          restaurant.email,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      _loginEmailController.text = restaurant.email;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Use',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 16), // Optimize font size
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Better padding
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        // Add subtle elevation effect
        isDense: true,
      ),
    );
  }

  Future<void> _handleRegistration() async {
    if (!_registrationFormKey.currentState!.validate()) return;

    final authService = Provider.of<MultiTenantAuthService>(context, listen: false);

    final success = await authService.registerRestaurant(
      name: _regNameController.text.trim(),
      businessType: _regBusinessTypeController.text.trim(),
      address: _regAddressController.text.trim(),
      phone: _regPhoneController.text.trim(),
      email: _regEmailController.text.trim(),
      adminUserId: _regAdminUserController.text.trim(),
      adminPassword: _regAdminPasswordController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurant registered successfully! You can now login.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Switch to login tab
      _tabController.animateTo(1);
      
      // Pre-fill login form
      _loginEmailController.text = _regEmailController.text.trim();
      _loginUserController.text = _regAdminUserController.text.trim();
    }
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final authService = Provider.of<MultiTenantAuthService>(context, listen: false);

    final success = await authService.login(
      restaurantEmail: _loginEmailController.text.trim(),
      userId: _loginUserController.text.trim(),
      password: _loginPasswordController.text.trim(),
    );

    if (success && mounted) {
      // Navigate to POS dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const OrderTypeSelectionScreen(),
        ),
      );
    }
  }
} 