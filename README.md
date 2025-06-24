# 🍽️ AI POS System

> **Advanced Flutter Point of Sale System with Comprehensive Order Management**

[![Flutter](https://img.shields.io/badge/Flutter-Framework-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-Language-blue?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Windows-lightgrey)](https://flutter.dev/multi-platform)

A professional-grade Point of Sale system built with Flutter, featuring advanced order management, comprehensive printer configuration, and intelligent responsive design algorithms.

## ✨ Features

### 🎯 **Core Functionality**
- **Multi-platform Support**: iOS, Android, macOS, Windows, and Web
- **Real-time Order Management**: Live order tracking with status updates
- **Advanced Database Integration**: SQLite with foreign key constraints
- **User Management**: Role-based access (Admin, Server, Kitchen staff)
- **Table Management**: Dynamic table assignment and status tracking

### 📱 **Advanced UI/UX**
- **Mathematical Grid Optimization**: 4-factor scoring algorithm for perfect layout
- **Smooth Interpolation Sizing**: Real-time UI adaptation to any screen size
- **Responsive Design**: Seamless scaling from mobile to large desktop displays
- **Professional Styling**: Dynamic shadows, colors, and spacing that scale proportionally

### 🖨️ **Printer Configuration System**
- **Network Scanning**: Automatic discovery of network printers (192.168.x.x)
- **Manual Setup**: Complete IP/port configuration with printer type selection
- **Epson Thermal Support**: 8+ Epson thermal printer models with 80mm paper
- **Station Management**: Dedicated configurations for Kitchen, Tandoor, Curry, etc.
- **Real-time Testing**: Connection testing and test print capabilities

### 📊 **Order Management**
- **Cancellation Tracking**: Complete audit trail showing who cancelled orders
- **Detailed Order Views**: Comprehensive order information with customer details
- **Order History**: Timeline of all status changes with timestamps
- **Payment Integration**: Multiple payment methods and transaction tracking
- **Kitchen Status**: Real-time kitchen order status and preparation tracking

### 🏪 **Restaurant Features**
- **Reservation System**: Table booking and customer management
- **Menu Management**: Dynamic menu items with categories and modifiers
- **Inventory Tracking**: Real-time stock management
- **Analytics & Reports**: Comprehensive sales and performance analytics
- **Multi-location Support**: Centralized management for restaurant chains

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0 or higher)
- Dart SDK (3.0 or higher)
- iOS development: Xcode 12+
- Android development: Android Studio with API 21+

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/varunkumar/ai_pos_system.git
   cd ai_pos_system
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   # For macOS
   flutter run -d macos
   
   # For iOS
   flutter run -d ios
   
   # For Android
   flutter run -d android
   ```

### Initial Setup

1. **First Run**: The app will automatically initialize the database
2. **Admin User**: Default admin credentials are created automatically
3. **Menu Setup**: Add your menu items through the admin panel
4. **Printer Configuration**: Configure your thermal printers via Settings

## 🏗️ Architecture

### Project Structure
```
lib/
├── models/          # Data models (Order, User, MenuItem, etc.)
├── services/        # Business logic and API services
├── screens/         # UI screens and pages
├── widgets/         # Reusable UI components
└── utils/           # Utility functions and helpers
```

### Key Technologies
- **Frontend**: Flutter with Material Design 3
- **Database**: SQLite with sqflite package
- **State Management**: Provider pattern
- **Printing**: Thermal printer integration
- **Networking**: HTTP and network scanning
- **Platform Integration**: Multi-platform device APIs

## 📈 Performance Features

### Optimization Algorithms
- **Grid Layout Scoring**: 40% tile size + 25% space utilization + 20% balance + 15% efficiency
- **Smooth Interpolation**: Linear interpolation for all UI elements (160px-300px range)
- **Content-aware Layout**: Automatic switching between centered and scrollable layouts
- **Real-time Adaptation**: Dynamic column count optimization based on screen constraints

### Database Performance
- **Advanced Caching**: Intelligent order loading with 51+ orders successfully managed
- **Foreign Key Integrity**: Complete referential integrity across all tables
- **Transaction Management**: Atomic operations for data consistency
- **Optimized Queries**: Efficient JOIN operations for complex data retrieval

## 🔧 Configuration

### Printer Setup
1. Navigate to Settings → Printer Configuration
2. Choose your station (Kitchen, Tandoor, Curry, etc.)
3. Select Manual Setup or Network Scan
4. Configure IP address and port (typically 9100)
5. Test connection and print sample

### Database Configuration
The system automatically manages database schema and migrations:
- **Foreign Keys**: Enabled for data integrity
- **Indexes**: Optimized for query performance
- **Backup**: Automatic local storage

## 📱 Screenshots

*Screenshots and demo videos coming soon...*

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the [Wiki](../../wiki) for detailed guides
- **Issues**: Report bugs via [GitHub Issues](../../issues)
- **Discussions**: Join [GitHub Discussions](../../discussions) for questions

## 🎯 Roadmap

- [ ] Cloud synchronization
- [ ] Advanced analytics dashboard
- [ ] Mobile app optimization
- [ ] Integration with payment gateways
- [ ] Multi-language support
- [ ] Advanced reporting features

## 👨‍💻 Author

**Varun Kumar**
- Email: varun.kan@gmail.com
- GitHub: [@varunkumar](https://github.com/varunkumar)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- SQLite for robust database functionality
- All contributors and testers who helped improve this system

---

**Built with ❤️ using Flutter**
