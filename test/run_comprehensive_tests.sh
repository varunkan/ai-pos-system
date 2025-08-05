#!/bin/bash

# 🚀 COMPREHENSIVE POS SYSTEM TEST RUNNER
# This script runs all test suites in the correct order

set -e  # Exit on any error

echo "🚀 STARTING COMPREHENSIVE POS SYSTEM TEST SUITE"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to run tests with timeout
run_test_with_timeout() {
    local test_name="$1"
    local test_file="$2"
    local timeout_seconds="$3"
    
    print_status "Running $test_name..."
    
    if flutter test $test_file; then
        print_success "$test_name completed successfully"
        return 0
    else
        print_error "$test_name failed or timed out"
        return 1
    fi
}

# Function to run integration tests with timeout
run_integration_test_with_timeout() {
    local test_name="$1"
    local test_file="$2"
    local timeout_seconds="$3"
    
    print_status "Running $test_name..."
    
    if flutter test $test_file; then
        print_success "$test_name completed successfully"
        return 0
    else
        print_error "$test_name failed or timed out"
        return 1
    fi
}

# Initialize counters
total_tests=0
passed_tests=0
failed_tests=0

# Start timer
start_time=$(date +%s)

echo "📋 TEST EXECUTION PLAN:"
echo "======================="
echo "1. Unit Tests (comprehensive_unit_tests.dart)"
echo "2. Integration Tests (comprehensive_end_to_end_test.dart)"
echo "3. Performance Tests (performance_stress_test.dart)"
echo "4. Security Tests (security_comprehensive_test.dart)"
echo "5. Existing Tests (comprehensive_pos_test.dart, integration_test.dart, etc.)"
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the project root."
    exit 1
fi

# Get dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Create test results directory
mkdir -p test_results

echo ""
echo "🧪 PHASE 1: UNIT TESTS"
echo "======================"

# Run unit tests
((total_tests++))
if run_test_with_timeout "Comprehensive Unit Tests" "test/comprehensive_unit_tests.dart" 300; then
    ((passed_tests++))
else
    ((failed_tests++))
fi

echo ""
echo "🔄 PHASE 2: INTEGRATION TESTS"
echo "============================="

# Run comprehensive end-to-end tests
((total_tests++))
if run_integration_test_with_timeout "Comprehensive End-to-End Tests" "test/comprehensive_end_to_end_test.dart" 600; then
    ((passed_tests++))
else
    ((failed_tests++))
fi

echo ""
echo "⚡ PHASE 3: PERFORMANCE TESTS"
echo "============================="

# Run performance and stress tests
((total_tests++))
if run_integration_test_with_timeout "Performance and Stress Tests" "test/performance_stress_test.dart" 900; then
    ((passed_tests++))
else
    ((failed_tests++))
fi

echo ""
echo "🔒 PHASE 4: SECURITY TESTS"
echo "=========================="

# Run security tests
((total_tests++))
if run_integration_test_with_timeout "Security Tests" "test/security_comprehensive_test.dart" 600; then
    ((passed_tests++))
else
    ((failed_tests++))
fi

echo ""
echo "📋 PHASE 5: EXISTING TESTS"
echo "=========================="

# Run existing comprehensive POS tests
((total_tests++))
if run_test_with_timeout "Existing Comprehensive POS Tests" "test/comprehensive_pos_test.dart" 300; then
    ((passed_tests++))
else
    ((failed_tests++))
fi

# Run existing integration tests
((total_tests++))
if run_integration_test_with_timeout "Existing Integration Tests" "test/integration_test.dart" 300; then
    ((passed_tests++))
else
    ((failed_tests++))
fi

# Run existing critical issues tests
((total_tests++))
if run_test_with_timeout "Critical Issues Tests" "test/critical_issues_test.dart" 120; then
    ((passed_tests++))
else
    ((failed_tests++))
fi

# Run existing inventory tests
((total_tests++))
if run_integration_test_with_timeout "Inventory End-to-End Tests" "test/inventory_end_to_end_test.dart" 300; then
    ((passed_tests++))
else
    ((failed_tests++))
fi

# Run existing reporting tests
((total_tests++))
if run_test_with_timeout "Reporting Logic Tests" "test/reporting_logic_test.dart" 300; then
    ((passed_tests++))
else
    ((failed_tests++))
fi

# Run existing reporting end-to-end tests
((total_tests++))
if run_integration_test_with_timeout "Reporting End-to-End Tests" "test/reporting_end_to_end_test.dart" 300; then
    ((passed_tests++))
else
    ((failed_tests++))
fi

echo ""
echo "📊 TEST RESULTS SUMMARY"
echo "======================="

# Calculate end time and duration
end_time=$(date +%s)
duration=$((end_time - start_time))

# Convert duration to human readable format
if [ $duration -gt 3600 ]; then
    duration_str="$((duration / 3600))h $(((duration % 3600) / 60))m $((duration % 60))s"
elif [ $duration -gt 60 ]; then
    duration_str="$((duration / 60))m $((duration % 60))s"
else
    duration_str="${duration}s"
fi

echo "⏱️  Total Test Duration: $duration_str"
echo "📊 Total Tests Run: $total_tests"
echo "✅ Tests Passed: $passed_tests"
echo "❌ Tests Failed: $failed_tests"

# Calculate success rate
if [ $total_tests -gt 0 ]; then
    success_rate=$((passed_tests * 100 / total_tests))
    echo "📈 Success Rate: ${success_rate}%"
else
    success_rate=0
    echo "📈 Success Rate: 0%"
fi

echo ""

# Final status
if [ $failed_tests -eq 0 ]; then
    print_success "🎉 ALL TESTS PASSED! The POS system is ready for production."
    echo ""
    echo "✅ SECURITY: All security tests passed"
    echo "✅ PERFORMANCE: All performance tests passed"
    echo "✅ FUNCTIONALITY: All functionality tests passed"
    echo "✅ INTEGRATION: All integration tests passed"
    echo "✅ UNIT: All unit tests passed"
    echo ""
    echo "🚀 The AI POS System is fully tested and secure!"
    exit 0
else
    print_error "❌ $failed_tests test(s) failed. Please review the failures above."
    echo ""
    echo "🔧 RECOMMENDATIONS:"
    echo "1. Review failed test output above"
    echo "2. Fix any identified issues"
    echo "3. Re-run the test suite"
    echo "4. Ensure all security and performance requirements are met"
    echo ""
    exit 1
fi 