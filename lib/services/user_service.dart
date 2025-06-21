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
  static const String _usersKey = 'users';

  UserService(this._prefs, this._databaseService) {
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      // First, try to load users from SQLite database
      await _loadUsersFromDatabase();
      
      // If no users in database, try to migrate from SharedPreferences
      if (_users.isEmpty) {
        await _migrateUsersFromSharedPreferences();
      }
      
      // If still no users, create default users
      if (_users.isEmpty) {
        await _createDefaultUsers();
      }
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during user load: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during user load: $e');
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      // Fall back to creating default users
      await _createDefaultUsers();
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during fallback: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during fallback: $e');
      }
    }
  }

  Future<void> _loadUsersFromDatabase() async {
    try {
      final db = await _databaseService.database;
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
        User(id: 'admin', name: 'Admin', role: UserRole.admin, pin: '1234'),
        User(id: 'server1', name: 'Server 1', role: UserRole.server, pin: '1111'),
        User(id: 'server2', name: 'Server 2', role: UserRole.server, pin: '2222'),
      ];
      
      for (final user in defaultUsers) {
        await _saveUserToDatabase(user);
      }
      
      _users = defaultUsers;
      debugPrint('Default users created successfully');
    } catch (e) {
      debugPrint('Error creating default users: $e');
    }
  }

  Future<void> _saveUserToDatabase(User user) async {
    try {
      final db = await _databaseService.database;
      await db.insert(
        'users',
        {
          'id': user.id,
          'name': user.name,
          'role': user.role.toString().split('.').last,
          'pin': user.pin,
          'is_active': user.isActive ? 1 : 0,
          'created_at': user.createdAt.toIso8601String(),
          'last_login': user.lastLogin?.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving user to database: $e');
      rethrow;
    }
  }

  Future<void> _updateUserInDatabase(User user) async {
    try {
      final db = await _databaseService.database;
      await db.update(
        'users',
        {
          'name': user.name,
          'role': user.role.toString().split('.').last,
          'pin': user.pin,
          'is_active': user.isActive ? 1 : 0,
          'last_login': user.lastLogin?.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (e) {
      debugPrint('Error updating user in database: $e');
      rethrow;
    }
  }

  Future<void> _deleteUserFromDatabase(String userId) async {
    try {
      final db = await _databaseService.database;
      await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );
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
      await db.delete('users');
      
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

  List<User> get users {
    return _users;
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