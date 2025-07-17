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
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // App Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Restaurant POS',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          Text(
            'Multi-Tenant Point of Sale System',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
          ),
        ],
      ),
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Admin Credentials Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Credentials',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'These will be used to access your restaurant\'s POS system',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blue.shade600,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Admin User ID
                      _buildTextField(
                        controller: _regAdminUserController,
                        label: 'Admin User ID',
                        icon: Icons.person,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Admin user ID is required';
                          }
                          if (value!.length < 3) {
                            return 'User ID must be at least 3 characters';
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
                          onPressed: () {
                            setState(() {
                              _obscureRegPassword = !_obscureRegPassword;
                            });
                          },
                          icon: Icon(
                            _obscureRegPassword ? Icons.visibility : Icons.visibility_off,
                          ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Error message
                if (authService.lastError != null)
                  Container(
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

                if (authService.lastError != null) const SizedBox(height: 16),

                // Register Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authService.isLoading ? null : _handleRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
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
        );
      },
    );
  }

  Widget _buildLoginTab() {
    return Consumer<MultiTenantAuthService>(
      builder: (context, authService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                    onPressed: () {
                      setState(() {
                        _obscureLoginPassword = !_obscureLoginPassword;
                      });
                    },
                    icon: Icon(
                      _obscureLoginPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Error message
                if (authService.lastError != null)
                  Container(
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

                if (authService.lastError != null) const SizedBox(height: 16),

                // Login Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authService.isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF764ba2),
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

                // Registered Restaurants Info
                if (authService.registeredRestaurants.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Registered Restaurants',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF667eea),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Use',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
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