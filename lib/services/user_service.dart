import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import 'database_service.dart';

class UserService with ChangeNotifier {
  final SharedPreferences _prefs;
  final DatabaseService _databaseService;
  List<User> _users = [];
  User? _currentUser;
  static const String _usersKey = 'users';

  UserService(this._prefs, this._databaseService) {
    _loadUsers();
  }

  /// Load users from database
  Future<void> _loadUsers() async {
    try {
      if (_databaseService.isWeb) {
        await _loadWebUsers();
      } else {
        await _loadSQLiteUsers();
      }
      
      // Ensure admin user exists with proper permissions
      await _ensureAdminUserExists();
      
      debugPrint('Loaded ${_users.length} users from database');
    } catch (e) {
      debugPrint('Error loading users: $e');
      
      // Create default admin user if loading fails
      await _createDefaultAdminUser();
    }
  }

  /// Ensure admin user exists with proper permissions
  Future<void> _ensureAdminUserExists() async {
    try {
      // Look for admin user
      final adminUser = _users.where((user) => user.id == 'admin').firstOrNull;
      
      if (adminUser == null) {
        // Create admin user
        debugPrint('🔧 Creating admin user with PIN 7165 and full admin access');
        final newAdminUser = User(
          id: 'admin',
          name: 'Admin',
          role: UserRole.admin,
          pin: '7165',
          adminPanelAccess: true,
          isActive: true,
        );
        
        await _saveUserToDatabase(newAdminUser);
        _users.add(newAdminUser);
        
        debugPrint('✅ Admin user created with PIN 7165 and full admin access');
      } else {
        // Check if admin user needs to be updated (role, access, or PIN)
        if (adminUser.role != UserRole.admin || 
            !adminUser.adminPanelAccess || 
            adminUser.pin != '7165') {
          debugPrint('🔧 Updating admin user to have full admin access and correct PIN');
          
          final updatedAdmin = adminUser.copyWith(
            role: UserRole.admin,
            adminPanelAccess: true,
            pin: '7165',
            isActive: true,
          );
          
          await _updateUserInDatabase(updatedAdmin);
          
          // Update in memory
          final adminIndex = _users.indexWhere((user) => user.id == 'admin');
          if (adminIndex != -1) {
            _users[adminIndex] = updatedAdmin;
          }
          
          // Update current user if it's the admin
          if (_currentUser?.id == 'admin') {
            _currentUser = updatedAdmin;
          }
          
          debugPrint('✅ Admin user updated with PIN 7165 and full admin access');
        } else {
          debugPrint('✅ Admin user already has full admin access and correct PIN');
        }
      }
    } catch (e) {
      debugPrint('❌ Error ensuring admin user exists: $e');
    }
  }

  /// Create a default admin user if none exists
  Future<void> _createDefaultAdminUser() async {
    try {
      debugPrint('🔧 Creating default admin user...');
      
      final adminUser = User(
        id: 'admin',
        name: 'Admin',
        role: UserRole.admin,
        pin: '7165',
        adminPanelAccess: true,
        isActive: true,
      );
      
      await _saveUserToDatabase(adminUser);
      _users.add(adminUser);
      
      debugPrint('✅ Default admin user created successfully');
    } catch (e) {
      debugPrint('❌ Error creating default admin user: $e');
    }
  }

  Future<void> _loadWebUsers() async {
    try {
      final webUsers = await _databaseService.getWebUsers();
      _users = webUsers.map((userMap) {
        return User(
          id: userMap['id'],
          name: userMap['name'],
          role: UserRole.values.firstWhere(
            (e) => e.toString().split('.').last == userMap['role'],
            orElse: () => UserRole.server,
          ),
          pin: userMap['pin'],
          isActive: userMap['is_active'] == true,
          adminPanelAccess: userMap['admin_panel_access'] == true,
          createdAt: DateTime.parse(userMap['created_at']),
          lastLogin: userMap['last_login'] != null ? DateTime.parse(userMap['last_login']) : null,
        );
      }).toList();
      debugPrint('Loaded ${_users.length} users from web storage');
    } catch (e) {
      debugPrint('Error loading users from database: $e');
      _users = [];
    }
  }

  Future<void> _loadSQLiteUsers() async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;
      
      final List<Map<String, dynamic>> userMaps = await db.query('users');
      
      _users = userMaps.map((userMap) {
        return User(
          id: userMap['id'],
          name: userMap['name'],
          role: UserRole.values.firstWhere(
            (e) => e.toString().split('.').last == userMap['role'],
            orElse: () => UserRole.server,
          ),
          pin: userMap['pin'],
          isActive: userMap['is_active'] == 1,
          adminPanelAccess: userMap['admin_panel_access'] == 1,
          createdAt: DateTime.parse(userMap['created_at']),
          lastLogin: userMap['last_login'] != null ? DateTime.parse(userMap['last_login']) : null,
        );
      }).toList();
      
      debugPrint('Loaded ${_users.length} users from database');
    } catch (e) {
      debugPrint('Error loading users from database: $e');
      _users = [];
    }
  }

  Future<void> _migrateUsersFromSharedPreferences() async {
    try {
      final String? usersJson = _prefs.getString(_usersKey);
      if (usersJson != null) {
        final List<dynamic> usersList = jsonDecode(usersJson);
        final List<User> prefsUsers = usersList.map((user) => User.fromJson(user)).toList();
        
        if (prefsUsers.isNotEmpty) {
          debugPrint('Migrating ${prefsUsers.length} users from SharedPreferences to database');
          
          for (final user in prefsUsers) {
            await _saveUserToDatabase(user);
          }
          
          _users = prefsUsers;
          
          // Clear from SharedPreferences after successful migration
          await _prefs.remove(_usersKey);
          debugPrint('Migration completed successfully');
        }
      }
    } catch (e) {
      debugPrint('Error migrating users from SharedPreferences: $e');
    }
  }

  Future<void> _createDefaultUsers() async {
    try {
      debugPrint('Creating default users');
      final defaultUsers = [
        User(id: 'admin', name: 'Admin', role: UserRole.admin, pin: '7165', adminPanelAccess: true),
        User(id: 'server1', name: 'Server 1', role: UserRole.server, pin: '1111'),
        User(id: 'server2', name: 'Server 2', role: UserRole.server, pin: '2222'),
        // Add 2 more dummy servers
        User(id: 'server3', name: 'Emma Thompson', role: UserRole.server, pin: '3333'),
        User(id: 'server4', name: 'Alex Johnson', role: UserRole.server, pin: '4444'),
      ];
      
      for (final user in defaultUsers) {
        await _saveUserToDatabase(user);
      }
      
      _users = defaultUsers;
      debugPrint('Default users created successfully');
      
      // Ensure admin user has full admin access
      await _ensureAdminUserHasFullAccess();
    } catch (e) {
      debugPrint('Error creating default users: $e');
    }
  }

  /// Ensures the admin user has full admin access
  Future<void> _ensureAdminUserHasFullAccess() async {
    try {
      final adminUser = _users.where((user) => user.id == 'admin').firstOrNull;
      
      if (adminUser == null) {
        // Create admin user if it doesn't exist
        debugPrint('🔧 Creating admin user with full access');
        final newAdmin = User(
          id: 'admin',
          name: 'Admin',
          role: UserRole.admin,
          pin: '7165',
          adminPanelAccess: true,
          isActive: true,
        );
        
        await _saveUserToDatabase(newAdmin);
        _users.add(newAdmin);
        
        debugPrint('✅ Admin user created with PIN 7165 and full access');
      } else {
        // Check if admin user needs to be updated (role, access, or PIN)
        if (adminUser.role != UserRole.admin || 
            !adminUser.adminPanelAccess || 
            adminUser.pin != '7165') {
          debugPrint('🔧 Updating admin user to have full admin access and correct PIN');
          
          final updatedAdmin = adminUser.copyWith(
            role: UserRole.admin,
            adminPanelAccess: true,
            pin: '7165',
            isActive: true,
          );
          
          await _updateUserInDatabase(updatedAdmin);
          
          // Update in memory
          final adminIndex = _users.indexWhere((user) => user.id == 'admin');
          if (adminIndex != -1) {
            _users[adminIndex] = updatedAdmin;
          }
          
          // Update current user if it's the admin
          if (_currentUser?.id == 'admin') {
            _currentUser = updatedAdmin;
          }
          
          debugPrint('✅ Admin user updated with PIN 7165 and full access');
        } else {
          debugPrint('✅ Admin user already has full admin access and correct PIN');
        }
      }
    } catch (e) {
      debugPrint('❌ Error ensuring admin user has full access: $e');
    }
  }

  /// Manually fix admin permissions - can be called if admin access is broken
  Future<void> fixAdminPermissions() async {
    try {
      debugPrint('🔧 Manually fixing admin permissions...');
      
      // Remove any existing admin user
      _users.removeWhere((user) => user.id == 'admin');
      
      // Create new admin user with proper permissions
      final adminUser = User(
        id: 'admin',
        name: 'Admin',
        role: UserRole.admin,
        pin: '7165',
        adminPanelAccess: true,
        isActive: true,
      );
      
      await _saveUserToDatabase(adminUser);
      _users.add(adminUser);
      
      debugPrint('✅ Admin permissions fixed successfully');
      
      // Notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during admin fix: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during admin fix: $e');
      }
    } catch (e) {
      debugPrint('❌ Error fixing admin permissions: $e');
    }
  }

  /// Creates additional dummy servers for testing
  Future<void> createDummyServers() async {
    try {
      debugPrint('Creating dummy servers...');
      
      // Check if dummy servers already exist
      final existingEmma = _users.where((u) => u.id == 'server3').isNotEmpty;
      final existingAlex = _users.where((u) => u.id == 'server4').isNotEmpty;
      
      if (existingEmma && existingAlex) {
        debugPrint('Dummy servers already exist');
        return;
      }
      
      final dummyServers = [
        User(id: 'server3', name: 'Emma Thompson', role: UserRole.server, pin: '3333'),
        User(id: 'server4', name: 'Alex Johnson', role: UserRole.server, pin: '4444'),
      ];
      
      for (final server in dummyServers) {
        if (!_users.any((u) => u.id == server.id)) {
          await _saveUserToDatabase(server);
          _users.add(server);
        }
      }
      
      debugPrint('✅ Dummy servers created successfully');
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during dummy server creation: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during dummy server creation: $e');
      }
    } catch (e) {
      debugPrint('❌ Error creating dummy servers: $e');
    }
  }

  Future<void> _saveUserToDatabase(User user) async {
    try {
      if (_databaseService.isWeb) {
        // Web platform - use Hive storage with consistent data format
        await _databaseService.saveWebUser({
          'id': user.id,
          'name': user.name,
          'role': user.role.toString().split('.').last,
          'pin': user.pin,
          'is_active': user.isActive ? 1 : 0,
          'admin_panel_access': user.adminPanelAccess ? 1 : 0, // Ensure admin panel access is saved
          'created_at': user.createdAt.toIso8601String(),
          'last_login': user.lastLogin?.toIso8601String(),
        });
      } else {
        // Mobile/Desktop platform - use SQLite
        final db = await _databaseService.database;
        if (db == null) return;
        
        await db.insert(
          'users',
          {
            'id': user.id,
            'name': user.name,
            'role': user.role.toString().split('.').last,
            'pin': user.pin,
            'is_active': user.isActive ? 1 : 0,
            'admin_panel_access': user.adminPanelAccess ? 1 : 0, // Ensure admin panel access is saved
            'created_at': user.createdAt.toIso8601String(),
            'last_login': user.lastLogin?.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint('Error saving user to database: $e');
      rethrow;
    }
  }

  Future<void> _updateUserInDatabase(User user) async {
    try {
      if (_databaseService.isWeb) {
        // Web platform - use Hive storage
        await _databaseService.saveWebUser({
          'id': user.id,
          'name': user.name,
          'role': user.role.toString().split('.').last,
          'pin': user.pin,
          'is_active': user.isActive ? 1 : 0,
          'admin_panel_access': user.adminPanelAccess ? 1 : 0,
          'created_at': user.createdAt.toIso8601String(),
          'last_login': user.lastLogin?.toIso8601String(),
        });
      } else {
        // Mobile/Desktop platform - use SQLite
        final db = await _databaseService.database;
        if (db == null) return;
        
        await db.update(
          'users',
          {
            'id': user.id,
            'name': user.name,
            'role': user.role.toString().split('.').last,
            'pin': user.pin,
            'is_active': user.isActive ? 1 : 0,
            'admin_panel_access': user.adminPanelAccess ? 1 : 0,
            'created_at': user.createdAt.toIso8601String(),
            'last_login': user.lastLogin?.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [user.id],
        );
      }
      debugPrint('✅ Updated user in database: ${user.name}');
    } catch (e) {
      debugPrint('❌ Failed to update user in database: $e');
      rethrow;
    }
  }

  Future<void> _deleteUserFromDatabase(String userId) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        await db.delete(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
        );
      }
    } catch (e) {
      debugPrint('Error deleting user from database: $e');
      rethrow;
    }
  }

  Future<void> saveUsers(List<User> users) async {
    try {
      for (final user in users) {
        await _saveUserToDatabase(user);
      }
      _users = users;
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during save users: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during save users: $e');
      }
    } catch (e) {
      throw Exception('Failed to save users: $e');
    }
  }

  /// Clears all existing users and saves the new list
  Future<void> clearAndSaveUsers(List<User> users) async {
    try {
      final db = await _databaseService.database;
      if (db != null) {
        await db.delete('users');
      }
      
      for (final user in users) {
        await _saveUserToDatabase(user);
      }
      
      _users = users;
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during clear and save users: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during clear and save users: $e');
      }
    } catch (e) {
      throw Exception('Failed to clear and save users: $e');
    }
  }

  /// Gets all users
  List<User> get users => List.unmodifiable(_users);

  /// Gets the current logged-in user
  User? get currentUser => _currentUser;

  /// Sets the current user and notifies listeners
  void setCurrentUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Validates user credentials and returns the user if valid
  User? validateUserCredentials(String id, String pin) {
    try {
      return _users.firstWhere((user) => user.id == id && user.pin == pin && user.isActive);
    } catch (e) {
      return null;
    }
  }

  /// Grants full admin access to a user (both role and admin panel access)
  Future<bool> grantFullAdminAccess(String userId) async {
    try {
      final userIndex = _users.indexWhere((user) => user.id == userId);
      if (userIndex == -1) {
        debugPrint('❌ User not found: $userId');
        return false;
      }

      final user = _users[userIndex];
      final updatedUser = user.copyWith(
        role: UserRole.admin,
        adminPanelAccess: true,
      );
      
      // Update in database
      await _updateUserInDatabase(updatedUser);
      
      // Update in memory
      _users[userIndex] = updatedUser;
      
      // Update current user if it's the same user
      if (_currentUser?.id == userId) {
        _currentUser = updatedUser;
      }
      
      notifyListeners();
      debugPrint('✅ Granted full admin access to user: ${user.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to grant full admin access: $e');
      return false;
    }
  }

  /// Grants admin panel access to a user
  Future<bool> grantAdminPanelAccess(String userId) async {
    try {
      final userIndex = _users.indexWhere((user) => user.id == userId);
      if (userIndex == -1) {
        debugPrint('❌ User not found: $userId');
        return false;
      }

      final user = _users[userIndex];
      final updatedUser = user.copyWith(adminPanelAccess: true);
      
      // Update in database
      await _updateUserInDatabase(updatedUser);
      
      // Update in memory
      _users[userIndex] = updatedUser;
      
      // Update current user if it's the same user
      if (_currentUser?.id == userId) {
        _currentUser = updatedUser;
      }
      
      notifyListeners();
      debugPrint('✅ Granted admin panel access to user: ${user.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to grant admin panel access: $e');
      return false;
    }
  }

  /// Revokes admin panel access from a user
  Future<bool> revokeAdminPanelAccess(String userId) async {
    try {
      final userIndex = _users.indexWhere((user) => user.id == userId);
      if (userIndex == -1) {
        debugPrint('❌ User not found: $userId');
        return false;
      }

      final user = _users[userIndex];
      final updatedUser = user.copyWith(adminPanelAccess: false);
      
      // Update in database
      await _updateUserInDatabase(updatedUser);
      
      // Update in memory
      _users[userIndex] = updatedUser;
      
      // Update current user if it's the same user
      if (_currentUser?.id == userId) {
        _currentUser = updatedUser;
      }
      
      notifyListeners();
      debugPrint('✅ Revoked admin panel access from user: ${user.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to revoke admin panel access: $e');
      return false;
    }
  }

  /// Checks if the current user can access admin panel
  bool get currentUserCanAccessAdminPanel {
    return _currentUser?.canAccessAdminPanel ?? false;
  }

  /// Gets all users with admin panel access
  List<User> get usersWithAdminAccess {
    return _users.where((user) => user.canAccessAdminPanel).toList();
  }

  Future<List<User>> getUsers() async {
    return _users;
  }

  Future<void> addUser(User user) async {
    // Check if user with same ID already exists
    if (_users.any((u) => u.id == user.id)) {
      throw Exception('User with this ID already exists');
    }
    
    // Check if PIN is already in use
    if (_users.any((u) => u.pin == user.pin)) {
      throw Exception('PIN is already in use by another user');
    }
    
    // Validate user data
    if (user.name.trim().isEmpty) {
      throw Exception('User name cannot be empty');
    }
    
    if (user.pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(user.pin)) {
      throw Exception('PIN must be exactly 4 digits');
    }
    
    try {
      await _saveUserToDatabase(user);
      _users.add(user);
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during add user: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during add user: $e');
      }
    } catch (e) {
      throw Exception('Failed to add user: $e');
    }
  }

  Future<void> updateUser(User user) async {
    try {
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index == -1) {
        throw Exception('User not found');
      }
      
      // Check if PIN is already in use by another user
      final existingUserWithPin = _users.where((u) => u.id != user.id && u.pin == user.pin).firstOrNull;
      if (existingUserWithPin != null) {
        throw Exception('PIN is already in use by user ${existingUserWithPin.name}');
      }
      
      // Validate user data
      if (user.name.trim().isEmpty) {
        throw Exception('User name cannot be empty');
      }
      
      if (user.pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(user.pin)) {
        throw Exception('PIN must be exactly 4 digits');
      }
      
      await _updateUserInDatabase(user);
      _users[index] = user;
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during update user: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during update user: $e');
      }
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      // Don't allow deleting the last admin user
      final adminUsers = _users.where((u) => u.role == UserRole.admin).toList();
      final userToDelete = _users.firstWhere((u) => u.id == userId);
      
      if (userToDelete.role == UserRole.admin && adminUsers.length <= 1) {
        throw Exception('Cannot delete the last admin user');
      }
      
      await _deleteUserFromDatabase(userId);
      _users.removeWhere((u) => u.id == userId);
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during delete user: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during delete user: $e');
      }
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  Future<void> updateLastLogin(String userId) async {
    try {
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        final updatedUser = _users[index].copyWith(lastLogin: DateTime.now());
        await _updateUserInDatabase(updatedUser);
        _users[index] = updatedUser;
        
        // Safely notify listeners
        try {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            try {
              notifyListeners();
            } catch (e) {
              debugPrint('Error notifying listeners during update last login: $e');
            }
          });
        } catch (e) {
          debugPrint('Error scheduling notification during update last login: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to update last login: $e');
    }
  }

  User? getUserById(String userId) {
    try {
      return _users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  User? authenticateUser(String pin) {
    try {
      return _users.firstWhere((user) => user.pin == pin && user.isActive);
    } catch (e) {
      return null;
    }
  }

  List<User> getUsersByRole(UserRole role) {
    return _users.where((user) => user.role == role).toList();
  }

  List<User> getActiveUsers() {
    return _users.where((user) => user.isActive).toList();
  }
} 