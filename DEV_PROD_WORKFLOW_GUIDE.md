# 🚀 AI POS System - Development & Production Workflow Guide

## 📋 **Overview**

This guide explains how to use the **Development** and **Production** environment setup for your AI POS System. This professional workflow ensures:

- ✅ **Separate environments** for development and production
- ✅ **Safe development** without affecting production
- ✅ **Easy promotion** of tested changes to production
- ✅ **Environment-specific configurations** (databases, APIs, features)
- ✅ **Professional deployment pipeline**

## 🏗️ **Environment Structure**

```
ai_pos_system/          # Production Environment
├── lib/
│   ├── main.dart       # Production main entry
│   ├── main_prod.dart  # Production-specific entry
│   ├── main_dev.dart   # Development-specific entry
│   └── config/
│       └── environment_config.dart  # Environment settings
├── scripts/
│   ├── dev_workflow.sh # Development workflow management
│   ├── build_dev.sh    # Development builds
│   └── build_prod.sh   # Production builds
└── ...

ai-pos-dev/             # Development Environment
├── [Copy of production with dev settings]
└── ...
```

## 🔄 **Development Workflow**

### **Step 1: Initialize Development Environment**
```bash
# From production directory
./scripts/dev_workflow.sh init-dev
```

This creates a separate development environment with:
- Independent git repository
- Development-specific configurations
- Test data and experimental features enabled

### **Step 2: Sync Latest from Production**
```bash
# Get the latest changes from production
./scripts/dev_workflow.sh sync-from-prod
```

This ensures your development environment has the latest production code.

### **Step 3: Switch to Development Environment**
```bash
# Switch to development directory
./scripts/dev_workflow.sh switch-dev
```

### **Step 4: Make Changes and Test**
```bash
# Run in development mode
flutter run -d macos --target=lib/main_dev.dart
```

**Development Features:**
- 🔧 Enhanced debugging and logging
- 🧪 Test data automatically loaded
- 🖨️ Printer simulation enabled
- ⏱️ Slower sync intervals for testing
- 🎯 Experimental features enabled

### **Step 5: Build and Test Development Version**
```bash
# Build development version
./scripts/build_dev.sh
```

### **Step 6: Promote to Production**
```bash
# Switch back to production
./scripts/dev_workflow.sh switch-prod

# Promote changes from development
./scripts/dev_workflow.sh promote-to-prod
```

### **Step 7: Build Production Version**
```bash
# Build production version with optimizations
./scripts/build_prod.sh
```

## 🎯 **Environment Differences**

| Feature | Development | Production |
|---------|-------------|------------|
| **Database** | `ai_pos_dev.db` | `ai_pos_prod.db` |
| **App Name** | `AI POS System (DEV)` | `AI POS System` |
| **Version** | `2.0.0-dev` | `2.0.0` |
| **Debug Logs** | ✅ Enabled | ❌ Disabled |
| **Test Data** | ✅ Auto-loaded | ❌ Disabled |
| **Printer Simulation** | ✅ Enabled | ❌ Real printers only |
| **Sync Interval** | 60 seconds | 30 seconds |
| **Printer Timeout** | 30 seconds | 15 seconds |
| **Experimental Features** | ✅ Enabled | ❌ Disabled |
| **Error Reporting** | ❌ Disabled | ✅ Enabled |
| **Performance Monitoring** | ❌ Disabled | ✅ Enabled |

## 🛠️ **Available Commands**

### **Development Workflow Commands**
```bash
./scripts/dev_workflow.sh init-dev          # Initialize development environment
./scripts/dev_workflow.sh sync-from-prod    # Sync latest from production
./scripts/dev_workflow.sh promote-to-prod   # Promote changes to production
./scripts/dev_workflow.sh switch-dev        # Switch to development
./scripts/dev_workflow.sh switch-prod       # Switch to production
./scripts/dev_workflow.sh build-prod        # Build production versions
./scripts/dev_workflow.sh test              # Run tests
./scripts/dev_workflow.sh status            # Show environment status
./scripts/dev_workflow.sh help              # Show help
```

### **Build Commands**
```bash
./scripts/build_dev.sh    # Build development version
./scripts/build_prod.sh   # Build production version
```

## 📱 **Running the App**

### **Development Mode**
```bash
# Switch to development
./scripts/dev_workflow.sh switch-dev

# Run in development mode
flutter run -d macos --target=lib/main_dev.dart
flutter run -d ios --target=lib/main_dev.dart
flutter run -d android --target=lib/main_dev.dart
```

### **Production Mode**
```bash
# Switch to production
./scripts/dev_workflow.sh switch-prod

# Run in production mode
flutter run -d macos --target=lib/main_prod.dart
flutter run -d ios --target=lib/main_prod.dart
flutter run -d android --target=lib/main_prod.dart
```

## 🔧 **Environment Configuration**

The environment configuration is managed in `lib/config/environment_config.dart`:

```dart
// Set environment
EnvironmentConfig.setEnvironment(Environment.development);

// Access environment-specific settings
String dbName = EnvironmentConfig.databaseName;
bool debugLogs = EnvironmentConfig.enableDebugLogs;
String appName = EnvironmentConfig.appName;
```

## 📊 **Best Practices**

### **Development Workflow**
1. **Always work in development environment** for new features
2. **Test thoroughly** before promoting to production
3. **Use meaningful commit messages** in development
4. **Sync from production regularly** to stay up-to-date
5. **Run tests** before promoting changes

### **Production Deployment**
1. **Never make direct changes** to production code
2. **Always promote from development** after testing
3. **Run production builds** before deployment
4. **Test production builds** on target devices
5. **Keep production environment stable**

### **Git Workflow**
1. **Development repository**: Independent commits for features
2. **Production repository**: Only promoted, tested changes
3. **Clear separation**: Never mix development and production commits
4. **Backup strategy**: Both environments are git repositories

## 🚨 **Important Notes**

### **Database Separation**
- Development and production use **separate databases**
- Changes in development **do not affect** production data
- Production data is **never touched** during development

### **Configuration Management**
- Environment-specific settings are **automatically applied**
- No manual configuration changes needed
- Settings are **type-safe** and **centralized**

### **Security**
- Production environment has **enhanced security**
- Development environment has **relaxed security** for testing
- **Never commit sensitive data** to either repository

## 🆘 **Troubleshooting**

### **Common Issues**

**Issue**: Development environment not found
```bash
# Solution: Reinitialize development environment
./scripts/dev_workflow.sh init-dev
```

**Issue**: Sync conflicts
```bash
# Solution: Resolve conflicts manually, then promote
git status  # Check conflicts
# Resolve conflicts
git add .
git commit -m "Resolve sync conflicts"
./scripts/dev_workflow.sh promote-to-prod
```

**Issue**: Build failures
```bash
# Solution: Clean and rebuild
flutter clean
flutter pub get
./scripts/build_dev.sh  # or build_prod.sh
```

### **Getting Help**
```bash
# Show all available commands
./scripts/dev_workflow.sh help

# Check environment status
./scripts/dev_workflow.sh status
```

## 🎉 **Success Metrics**

When using this workflow correctly, you should see:
- ✅ **Zero production bugs** from development work
- ✅ **Fast development cycles** with safe testing
- ✅ **Clean git history** with clear separation
- ✅ **Confident deployments** with tested changes
- ✅ **Professional development pipeline** suitable for teams

---

**🚀 Ready to start developing? Run `./scripts/dev_workflow.sh init-dev` to set up your development environment!** 