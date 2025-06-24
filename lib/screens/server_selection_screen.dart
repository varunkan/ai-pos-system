import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/table.dart' as restaurant_table;
import 'package:ai_pos_system/services/user_service.dart';
import 'package:ai_pos_system/services/table_service.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/reservation_service.dart';
import 'package:ai_pos_system/models/reservation.dart';
import 'package:ai_pos_system/screens/order_type_selection_screen.dart';
import 'package:ai_pos_system/screens/daily_bookings_screen.dart';
import 'package:ai_pos_system/widgets/back_button.dart';

class ServerSelectionScreen extends StatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  State<ServerSelectionScreen> createState() => _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends State<ServerSelectionScreen> {
  List<User> _serverUsers = [];
  bool _isLoading = true;
  Map<String, List<restaurant_table.Table>> _serverTables = {};

  @override
  void initState() {
    super.initState();
    _loadServerUsers();
  }

  Future<void> _loadServerUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final tableService = Provider.of<TableService>(context, listen: false);
      
      final allUsers = await userService.getUsers();
      final serverUsers = allUsers.where((user) => user.role == UserRole.server && user.isActive).toList();
      
      // Load active tables for each server
      final Map<String, List<restaurant_table.Table>> serverTables = {};
      for (final server in serverUsers) {
        final tables = await tableService.getTablesForUser(server.id);
        // Only include occupied or reserved tables
        final activeTables = tables.where((table) => 
          table.status == restaurant_table.TableStatus.occupied || 
          table.status == restaurant_table.TableStatus.reserved
        ).toList();
        serverTables[server.id] = activeTables;
      }
      
      setState(() {
        _serverUsers = serverUsers;
        _serverTables = serverTables;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading server users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectServer(User serverUser) {
    // Provide haptic feedback for selection
    HapticFeedback.lightImpact();
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTypeSelectionScreen(user: serverUser),
      ),
    );
  }

  void _goBackToLanding() {
    // Navigate back to landing screen (pop until the first route)
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Select Server',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToLanding,
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _serverUsers.isEmpty
              ? _buildEmptyState()
              : _buildServerSelection(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Server Users Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Please add server users through the admin panel to continue with order management.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _goBackToLanding,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSelection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        
        // Calculate responsive dimensions
        final isTablet = screenWidth > 768;
        final isDesktop = screenWidth > 1200;
        
        // Determine layout parameters based on screen size
        final horizontalPadding = isDesktop ? 48.0 : isTablet ? 32.0 : 16.0;
        final verticalPadding = isDesktop ? 32.0 : isTablet ? 24.0 : 16.0;
        
        return Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Daily Bookings Section - Fixed height
              Container(
                height: isTablet ? 120 : 100,
                margin: const EdgeInsets.only(bottom: 24),
                child: _buildDailyBookingsTile(isTablet),
              ),
              
              // Section Header
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Select Server',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        fontSize: isTablet ? 24 : 20,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        '${_serverUsers.length} Server${_serverUsers.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Server Grid - Flexible to fill remaining space
              Expanded(
                child: _buildResponsiveServerGrid(screenWidth, screenHeight),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResponsiveServerGrid(double screenWidth, double screenHeight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Get precise available dimensions
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        final serverCount = _serverUsers.length;
        
        // Define ideal tile size ranges for optimal UX
        const double idealTileWidth = 220.0;    // Sweet spot for readability
        const double minTileWidth = 160.0;      // Minimum for usability
        const double maxTileWidth = 300.0;      // Maximum before waste of space
        
        // Calculate optimal grid configuration
        final gridConfig = _calculateOptimalGrid(
          availableWidth: availableWidth,
          availableHeight: availableHeight,
          serverCount: serverCount,
          idealTileWidth: idealTileWidth,
          minTileWidth: minTileWidth,
          maxTileWidth: maxTileWidth,
        );
        
        // Determine if we need scrolling
        final totalContentHeight = _calculateTotalGridHeight(
          rows: gridConfig.rows,
          itemHeight: gridConfig.itemHeight,
          spacing: gridConfig.spacing,
        );
        
        final needsScrolling = totalContentHeight > availableHeight;
        
        // Build the grid with optimal configuration
        Widget gridWidget = _buildServerGrid(
          gridConfig.columns,
          gridConfig.aspectRatio,
          gridConfig.spacing,
        );
        
        if (needsScrolling) {
          // Scrollable grid for content overflow
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: gridConfig.spacing, // Add bottom padding for scroll bounce
            ),
            child: gridWidget,
          );
        } else {
          // Centered grid with perfect fit
          return Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: availableWidth,
                maxHeight: totalContentHeight,
              ),
              child: gridWidget,
            ),
          );
        }
      },
    );
  }
  
  // Advanced grid calculation algorithm for perfect responsive behavior
  GridConfiguration _calculateOptimalGrid({
    required double availableWidth,
    required double availableHeight,
    required int serverCount,
    required double idealTileWidth,
    required double minTileWidth,
    required double maxTileWidth,
  }) {
    // Start with single column and expand
    GridConfiguration bestConfig = GridConfiguration(
      columns: 1,
      rows: serverCount,
      itemWidth: availableWidth,
      aspectRatio: 0.85,
      spacing: 16.0,
    );
    
    // Try different column configurations to find the best fit
    for (int columns = 1; columns <= serverCount && columns <= 8; columns++) {
      // Calculate spacing based on screen density
      double spacing = _calculateOptimalSpacing(availableWidth, columns);
      
      // Calculate tile width with this column count
      double tileWidth = (availableWidth - (spacing * (columns - 1))) / columns;
      
      // Skip if tiles would be too small
      if (tileWidth < minTileWidth) break;
      
      // Calculate rows needed
      int rows = (serverCount / columns).ceil();
      
      // Calculate aspect ratio based on tile size for optimal content fit
      double aspectRatio = _calculateOptimalAspectRatio(tileWidth);
      double itemHeight = tileWidth / aspectRatio;
      
      // Calculate total grid height
      double totalHeight = _calculateTotalGridHeight(
        rows: rows,
        itemHeight: itemHeight,
        spacing: spacing,
      );
      
      // Score this configuration based on multiple factors
      double score = _scoreGridConfiguration(
        tileWidth: tileWidth,
        totalHeight: totalHeight,
        availableHeight: availableHeight,
        columns: columns,
        serverCount: serverCount,
        idealTileWidth: idealTileWidth,
        maxTileWidth: maxTileWidth,
      );
      
      // Update best configuration if this scores higher
      if (score > bestConfig.score) {
        bestConfig = GridConfiguration(
          columns: columns,
          rows: rows,
          itemWidth: tileWidth,
          aspectRatio: aspectRatio,
          spacing: spacing,
          score: score,
        );
      }
      
      // Early termination if we found a perfect fit
      if (score >= 0.95) break;
    }
    
    return bestConfig;
  }
  
  double _calculateOptimalSpacing(double availableWidth, int columns) {
    // Dynamic spacing based on screen width and column density
    if (availableWidth < 500) {
      return 8.0;  // Tight spacing for very small screens
    } else if (availableWidth < 768) {
      return 12.0; // Mobile spacing
    } else if (availableWidth < 1024) {
      return 16.0; // Tablet spacing
    } else if (availableWidth < 1440) {
      return 20.0; // Desktop spacing
    } else {
      return 24.0; // Large desktop spacing
    }
  }
  
  double _calculateOptimalAspectRatio(double tileWidth) {
    // Dynamic aspect ratio based on tile size for optimal content display
    if (tileWidth < 180) {
      return 0.75; // Taller tiles for compact content
    } else if (tileWidth < 220) {
      return 0.80; // Slightly taller
    } else if (tileWidth < 260) {
      return 0.85; // Balanced proportions
    } else if (tileWidth < 300) {
      return 0.90; // Wider tiles can be slightly shorter
    } else {
      return 0.95; // Large tiles with more breathing room
    }
  }
  
  double _calculateTotalGridHeight({
    required int rows,
    required double itemHeight,
    required double spacing,
  }) {
    return (itemHeight * rows) + (spacing * (rows - 1));
  }
  
  double _scoreGridConfiguration({
    required double tileWidth,
    required double totalHeight,
    required double availableHeight,
    required int columns,
    required int serverCount,
    required double idealTileWidth,
    required double maxTileWidth,
  }) {
    double score = 0.0;
    
    // Factor 1: Tile size optimality (40% weight)
    double tileSizeScore = 1.0 - (tileWidth - idealTileWidth).abs() / idealTileWidth;
    tileSizeScore = tileSizeScore.clamp(0.0, 1.0);
    score += tileSizeScore * 0.4;
    
    // Factor 2: Space utilization (25% weight)
    double heightUtilization = totalHeight <= availableHeight ? 1.0 : availableHeight / totalHeight;
    score += heightUtilization * 0.25;
    
    // Factor 3: Grid balance (20% weight) - prefer more square-like grids
    int rows = (serverCount / columns).ceil();
    double balanceRatio = columns / rows;
    double balanceScore = 1.0 - (balanceRatio - 1.0).abs().clamp(0.0, 1.0);
    score += balanceScore * 0.2;
    
    // Factor 4: Column efficiency (15% weight) - avoid too many or too few columns
    double columnEfficiency = 1.0;
    if (columns == 1 && serverCount > 2) columnEfficiency = 0.7; // Single column is less efficient for multiple servers
    if (columns > serverCount) columnEfficiency = 0.5; // Too many columns
    score += columnEfficiency * 0.15;
    
    // Penalty for oversized tiles
    if (tileWidth > maxTileWidth) {
      score *= 0.8;
    }
    
    return score.clamp(0.0, 1.0);
  }
}

  Widget _buildServerGrid(int crossAxisCount, double childAspectRatio, double spacing) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: _serverUsers.length,
      itemBuilder: (context, index) {
        final serverUser = _serverUsers[index];
        return _buildServerTile(serverUser);
      },
    );
  }

  Widget _buildDailyBookingsTile(bool isTablet) {
    return Consumer<ReservationService>(
      builder: (context, reservationService, child) {
        final todaysReservations = reservationService.todaysReservations;
        final upcomingCount = todaysReservations.where((r) => 
          r.status != ReservationStatus.completed &&
          r.status != ReservationStatus.cancelled &&
          r.status != ReservationStatus.noShow
        ).length;
        
        return Card(
          elevation: 6,
          shadowColor: Colors.orange.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.orange.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DailyBookingsScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 16 : 12),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.event_seat,
                        color: Colors.white,
                        size: isTablet ? 28 : 24,
                      ),
                    ),
                    SizedBox(width: isTablet ? 20 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Today\'s Bookings',
                            style: TextStyle(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: isTablet ? 6 : 4),
                          Text(
                            upcomingCount > 0 
                                ? '$upcomingCount upcoming reservation${upcomingCount != 1 ? 's' : ''}'
                                : 'No upcoming reservations',
                            style: TextStyle(
                              fontSize: isTablet ? 15 : 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 16 : 12, 
                        vertical: isTablet ? 8 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: upcomingCount > 0 ? Colors.green : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (upcomingCount > 0 ? Colors.green : Colors.grey).withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$upcomingCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 12 : 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: isTablet ? 20 : 16,
                      color: Colors.orange.shade700,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildServerTile(User serverUser) {
    final activeTables = _serverTables[serverUser.id] ?? [];
    
    return Card(
      elevation: 4,
      shadowColor: Colors.blue.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: InkWell(
          onTap: () => _selectServer(serverUser),
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Precision responsive sizing based on exact tile dimensions
              final tileWidth = constraints.maxWidth;
              final tileHeight = constraints.maxHeight;
              
              // Calculate sizing parameters using smooth interpolation
              final responsiveParams = _calculateTileResponsiveParams(tileWidth, tileHeight);
              
              // Determine if this is the current server
              final isCurrentServer = Provider.of<UserService>(context, listen: false).currentUser?.id == serverUser.id;
              
                             return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: isCurrentServer ? Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ) : null,
                ),
                child: Padding(
                  padding: EdgeInsets.all(responsiveParams.padding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Server avatar with enhanced styling
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isCurrentServer ? Colors.amber : Theme.of(context).primaryColor).withOpacity(0.3),
                            blurRadius: responsiveParams.shadowBlur,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: isCurrentServer ? Colors.amber.shade600 : Theme.of(context).primaryColor,
                            radius: responsiveParams.avatarRadius,
                            child: Text(
                              serverUser.name[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: responsiveParams.avatarTextSize,
                              ),
                            ),
                          ),
                          if (isCurrentServer)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: responsiveParams.currentIndicatorSize,
                                height: responsiveParams.currentIndicatorSize,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: responsiveParams.currentIndicatorSize * 0.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: responsiveParams.verticalSpacing),
                    
                    // Server name with current indicator
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            serverUser.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: responsiveParams.nameSize,
                              color: isCurrentServer ? Colors.amber.shade700 : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isCurrentServer) ...[
                            SizedBox(height: responsiveParams.verticalSpacing * 0.5),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: responsiveParams.badgeHorizontalPadding,
                                vertical: responsiveParams.badgeVerticalPadding,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Text(
                                'YOU',
                                style: TextStyle(
                                  color: Colors.amber.shade700,
                                  fontSize: responsiveParams.badgeTextSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    SizedBox(height: responsiveParams.verticalSpacing),
                    
                    // Server role badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: responsiveParams.badgeHorizontalPadding,
                        vertical: responsiveParams.badgeVerticalPadding,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(responsiveParams.badgeBorderRadius),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Text(
                        'Server',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: responsiveParams.badgeTextSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: responsiveParams.verticalSpacing),
                    
                    // Active tables display
                    if (activeTables.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: responsiveParams.containerHorizontalPadding,
                          vertical: responsiveParams.containerVerticalPadding,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(responsiveParams.containerBorderRadius),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Active Tables',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: responsiveParams.tableTextSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: responsiveParams.verticalSpacing * 0.5),
                            Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: activeTables.take(6).map((table) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: responsiveParams.tableChipHorizontalPadding,
                                    vertical: responsiveParams.tableChipVerticalPadding,
                                  ),
                                  decoration: BoxDecoration(
                                    color: table.status == restaurant_table.TableStatus.occupied 
                                        ? Colors.orange.shade100 
                                        : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(responsiveParams.tableChipBorderRadius),
                                    border: Border.all(
                                      color: table.status == restaurant_table.TableStatus.occupied 
                                          ? Colors.orange.shade300 
                                          : Colors.blue.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    'T${table.number}',
                                    style: TextStyle(
                                      color: table.status == restaurant_table.TableStatus.occupied 
                                          ? Colors.orange.shade700 
                                          : Colors.blue.shade700,
                                      fontSize: responsiveParams.tableChipTextSize,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            if (activeTables.length > 6) ...[
                              SizedBox(height: responsiveParams.verticalSpacing * 0.3),
                              Text(
                                '+${activeTables.length - 6} more',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: responsiveParams.tableChipTextSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      // No active tables
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsiveParams.containerHorizontalPadding, 
                          vertical: responsiveParams.containerVerticalPadding,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(responsiveParams.containerBorderRadius),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: responsiveParams.iconSize,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: responsiveParams.verticalSpacing * 0.5),
                            Text(
                              'No active tables',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: responsiveParams.tableTextSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  // Calculate responsive parameters for server tile based on dimensions
  TileResponsiveParams _calculateTileResponsiveParams(double width, double height) {
    // Define size breakpoints
    const double verySmallWidth = 160.0;
    const double smallWidth = 200.0;
    const double mediumWidth = 240.0;
    const double largeWidth = 280.0;
    
    // Calculate interpolation factor (0.0 to 1.0)
    double factor = ((width - verySmallWidth) / (largeWidth - verySmallWidth)).clamp(0.0, 1.0);
    
    // Smooth interpolation for all parameters
    return TileResponsiveParams(
      avatarRadius: _lerp(20.0, 40.0, factor),
      avatarTextSize: _lerp(12.0, 24.0, factor),
      nameSize: _lerp(13.0, 19.0, factor),
      badgeTextSize: _lerp(9.0, 13.0, factor),
      tableTextSize: _lerp(8.0, 12.0, factor),
      tableChipTextSize: _lerp(7.0, 11.0, factor),
      iconSize: _lerp(10.0, 16.0, factor),
      
      padding: _lerp(6.0, 18.0, factor),
      verticalSpacing: _lerp(4.0, 12.0, factor),
      
      badgeHorizontalPadding: _lerp(6.0, 14.0, factor),
      badgeVerticalPadding: _lerp(2.0, 6.0, factor),
      badgeBorderRadius: _lerp(6.0, 12.0, factor),
      
      containerHorizontalPadding: _lerp(4.0, 12.0, factor),
      containerVerticalPadding: _lerp(3.0, 8.0, factor),
      containerBorderRadius: _lerp(4.0, 10.0, factor),
      
      tableChipHorizontalPadding: _lerp(2.0, 6.0, factor),
      tableChipVerticalPadding: _lerp(1.0, 3.0, factor),
      tableChipBorderRadius: _lerp(2.0, 5.0, factor),
      
      shadowBlur: _lerp(4.0, 12.0, factor),
      currentIndicatorSize: _lerp(16.0, 24.0, factor),
    );
  }
  
  // Linear interpolation helper
  double _lerp(double start, double end, double factor) {
    return start + (end - start) * factor;
  }
}

// Responsive parameters for server tiles
class TileResponsiveParams {
  final double avatarRadius;
  final double avatarTextSize;
  final double nameSize;
  final double badgeTextSize;
  final double tableTextSize;
  final double tableChipTextSize;
  final double iconSize;
  
  final double padding;
  final double verticalSpacing;
  
  final double badgeHorizontalPadding;
  final double badgeVerticalPadding;
  final double badgeBorderRadius;
  
  final double containerHorizontalPadding;
  final double containerVerticalPadding;
  final double containerBorderRadius;
  
  final double tableChipHorizontalPadding;
  final double tableChipVerticalPadding;
  final double tableChipBorderRadius;
  
  final double shadowBlur;
  final double currentIndicatorSize;
  
  const TileResponsiveParams({
    required this.avatarRadius,
    required this.avatarTextSize,
    required this.nameSize,
    required this.badgeTextSize,
    required this.tableTextSize,
    required this.tableChipTextSize,
    required this.iconSize,
    required this.padding,
    required this.verticalSpacing,
    required this.badgeHorizontalPadding,
    required this.badgeVerticalPadding,
    required this.badgeBorderRadius,
    required this.containerHorizontalPadding,
    required this.containerVerticalPadding,
    required this.containerBorderRadius,
    required this.tableChipHorizontalPadding,
    required this.tableChipVerticalPadding,
    required this.tableChipBorderRadius,
    required this.shadowBlur,
    required this.currentIndicatorSize,
  });
}

// Configuration class for grid layout
class GridConfiguration {
  final int columns;
  final int rows;
  final double itemWidth;
  final double aspectRatio;
  final double spacing;
  final double score;
  
  GridConfiguration({
    required this.columns,
    required this.rows,
    required this.itemWidth,
    required this.aspectRatio,
    required this.spacing,
    this.score = 0.0,
  });
  
  double get itemHeight => itemWidth / aspectRatio;
}