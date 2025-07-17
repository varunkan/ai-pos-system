#!/usr/bin/env python3
"""
🚀 One-Click Free API Deployment
For non-technical users - deploy to cloud in 2 minutes
"""

import os
import sys
import json
import webbrowser
import subprocess
import platform
from pathlib import Path

def print_banner():
    """Print welcome banner"""
    print("=" * 60)
    print("🚀 ONE-CLICK FREE API DEPLOYMENT")
    print("Deploy to Cloud in 2 Minutes - No Computer Needed")
    print("=" * 60)
    print()

def get_user_input(prompt, default=""):
    """Get user input with default value"""
    if default:
        user_input = input(f"{prompt} [{default}]: ").strip()
        return user_input if user_input else default
    else:
        return input(f"{prompt}: ").strip()

def check_git_installed():
    """Check if Git is installed"""
    try:
        subprocess.run(['git', '--version'], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def check_node_installed():
    """Check if Node.js is installed"""
    try:
        subprocess.run(['node', '--version'], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def create_github_repo():
    """Guide user to create GitHub repository"""
    print("📦 Step 1: Create GitHub Repository")
    print("-" * 40)
    
    print("1. Opening GitHub...")
    webbrowser.open("https://github.com/new")
    
    input("Press Enter when you've created your GitHub repository...")
    
    repo_url = get_user_input("Enter your GitHub repository URL")
    if not repo_url:
        print("❌ Repository URL is required!")
        return None
    
    return repo_url

def setup_local_project():
    """Set up local project files"""
    print("\n📁 Step 2: Setting Up Project Files")
    print("-" * 40)
    
    # Create project directory
    project_dir = "free-restaurant-api"
    if os.path.exists(project_dir):
        print(f"⚠️ Directory {project_dir} already exists")
        choice = get_user_input("Delete and recreate? (y/n)", "y").lower()
        if choice == 'y':
            import shutil
            shutil.rmtree(project_dir)
        else:
            print("❌ Setup cancelled")
            return None
    
    os.makedirs(project_dir)
    os.chdir(project_dir)
    
    print(f"✅ Created project directory: {project_dir}")
    
    # Create package.json
    package_json = {
        "name": "free-restaurant-printing-api",
        "version": "1.0.0",
        "description": "🆓 Free cloud printing API for restaurants - $0 monthly cost",
        "main": "server.js",
        "scripts": {
            "start": "node server.js",
            "dev": "nodemon server.js"
        },
        "keywords": ["restaurant", "printing", "pos", "free", "cloud"],
        "author": "Restaurant POS System",
        "license": "MIT",
        "dependencies": {
            "express": "^4.18.2",
            "cors": "^2.8.5",
            "firebase-admin": "^11.11.0"
        },
        "engines": {
            "node": ">=16.0.0"
        }
    }
    
    with open("package.json", "w") as f:
        json.dump(package_json, f, indent=2)
    
    print("✅ Created package.json")
    
    # Create server.js
    server_js = '''const express = require('express');
const cors = require('cors');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin (optional)
let db = null;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    initializeApp({
      credential: cert(serviceAccount),
      databaseURL: process.env.FIREBASE_DATABASE_URL
    });
    db = getFirestore();
    console.log('✅ Firebase Admin initialized');
  } catch (error) {
    console.log('⚠️ Firebase Admin not configured, using in-memory storage');
  }
}

// In-memory storage
const inMemoryDB = {
  printJobs: new Map(),
  printers: new Map()
};

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'free-restaurant-printing',
    timestamp: new Date().toISOString()
  });
});

// Send print job
app.post('/api/print-jobs', async (req, res) => {
  try {
    const { orderId, restaurantId, targetPrinterId, items, orderData } = req.body;
    
    if (!orderId || !restaurantId || !targetPrinterId || !items) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields'
      });
    }
    
    const jobId = `job_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    const printJob = {
      id: jobId,
      orderId,
      restaurantId,
      targetPrinterId,
      items,
      orderData,
      status: 'pending',
      createdAt: new Date().toISOString()
    };
    
    if (db) {
      await db.collection('printJobs').doc(jobId).set(printJob);
    } else {
      inMemoryDB.printJobs.set(jobId, printJob);
    }
    
    console.log(`✅ Print job queued: ${orderId} → ${targetPrinterId}`);
    
    res.json({
      success: true,
      jobId,
      message: 'Print job queued successfully'
    });
    
  } catch (error) {
    console.error('❌ Error creating print job:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get print jobs for printer
app.get('/api/printers/:printerId/jobs', async (req, res) => {
  try {
    const { printerId } = req.params;
    const { status = 'pending' } = req.query;
    
    let jobs = [];
    
    if (db) {
      const snapshot = await db.collection('printJobs')
        .where('targetPrinterId', '==', printerId)
        .where('status', '==', status)
        .limit(10)
        .get();
      
      snapshot.forEach(doc => {
        jobs.push({ id: doc.id, ...doc.data() });
      });
    } else {
      jobs = Array.from(inMemoryDB.printJobs.values())
        .filter(job => job.targetPrinterId === printerId && job.status === status)
        .slice(0, 10);
    }
    
    res.json({
      success: true,
      jobs,
      count: jobs.length
    });
    
  } catch (error) {
    console.error('❌ Error getting print jobs:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Update print job status
app.put('/api/print-jobs/:jobId/status', async (req, res) => {
  try {
    const { jobId } = req.params;
    const { status } = req.body;
    
    if (!status) {
      return res.status(400).json({
        success: false,
        error: 'Status is required'
      });
    }
    
    const updateData = {
      status,
      updatedAt: new Date().toISOString()
    };
    
    if (db) {
      await db.collection('printJobs').doc(jobId).update(updateData);
    } else {
      const job = inMemoryDB.printJobs.get(jobId);
      if (job) {
        inMemoryDB.printJobs.set(jobId, { ...job, ...updateData });
      }
    }
    
    console.log(`✅ Print job ${jobId} status updated to: ${status}`);
    
    res.json({
      success: true,
      message: 'Print job status updated',
      jobId,
      status
    });
    
  } catch (error) {
    console.error('❌ Error updating print job status:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🆓 Free Restaurant Printing API running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
  console.log(`💡 Database: ${db ? 'firebase' : 'memory'}`);
});
'''
    
    with open("server.js", "w") as f:
        f.write(server_js)
    
    print("✅ Created server.js")
    
    # Create README.md
    readme_md = '''# 🆓 Free Restaurant Printing API

Zero cost cloud printing API for restaurants.

## Quick Deploy

1. Fork this repository
2. Deploy to Railway/Render/Heroku
3. Get your API URL
4. Configure your POS app

## API Endpoints

- `GET /api/health` - Health check
- `POST /api/print-jobs` - Send print job
- `GET /api/printers/:id/jobs` - Get print jobs
- `PUT /api/print-jobs/:id/status` - Update job status

## Free Deployment

- **Railway:** https://railway.app
- **Render:** https://render.com
- **Heroku:** https://heroku.com

## Cost: $0/month
'''
    
    with open("README.md", "w") as f:
        f.write(readme_md)
    
    print("✅ Created README.md")
    
    return True

def deploy_to_railway():
    """Deploy to Railway"""
    print("\n🚂 Step 3: Deploy to Railway (Free)")
    print("-" * 40)
    
    print("1. Opening Railway...")
    webbrowser.open("https://railway.app")
    
    print("2. Sign up with GitHub")
    print("3. Click 'New Project'")
    print("4. Choose 'Deploy from GitHub repo'")
    print("5. Select your repository")
    print("6. Railway will auto-deploy")
    
    input("Press Enter when deployment is complete...")
    
    api_url = get_user_input("Enter your Railway API URL")
    if not api_url:
        print("❌ API URL is required!")
        return None
    
    return api_url

def deploy_to_render():
    """Deploy to Render"""
    print("\n🎨 Step 3: Deploy to Render (Free)")
    print("-" * 40)
    
    print("1. Opening Render...")
    webbrowser.open("https://render.com")
    
    print("2. Sign up with GitHub")
    print("3. Click 'New +' → 'Web Service'")
    print("4. Connect your GitHub repository")
    print("5. Set build command: npm install")
    print("6. Set start command: npm start")
    print("7. Click 'Create Web Service'")
    
    input("Press Enter when deployment is complete...")
    
    api_url = get_user_input("Enter your Render API URL")
    if not api_url:
        print("❌ API URL is required!")
        return None
    
    return api_url

def deploy_to_heroku():
    """Deploy to Heroku"""
    print("\n⚡ Step 3: Deploy to Heroku (Free)")
    print("-" * 40)
    
    print("1. Opening Heroku...")
    webbrowser.open("https://heroku.com")
    
    print("2. Sign up with GitHub")
    print("3. Click 'New' → 'Create new app'")
    print("4. Connect your GitHub repository")
    print("5. Enable automatic deploys")
    print("6. Click 'Deploy Branch'")
    
    input("Press Enter when deployment is complete...")
    
    api_url = get_user_input("Enter your Heroku API URL")
    if not api_url:
        print("❌ API URL is required!")
        return None
    
    return api_url

def test_api(api_url):
    """Test the deployed API"""
    print(f"\n🧪 Step 4: Testing Your API")
    print("-" * 40)
    
    print(f"Testing API: {api_url}")
    
    try:
        import requests
        
        # Test health endpoint
        response = requests.get(f"{api_url}/api/health", timeout=10)
        
        if response.status_code == 200:
            print("✅ API is working!")
            print(f"Response: {response.json()}")
            return True
        else:
            print(f"❌ API test failed: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ API test failed: {e}")
        return False

def create_pos_config(api_url):
    """Create POS app configuration"""
    print(f"\n📱 Step 5: POS App Configuration")
    print("-" * 40)
    
    print("Configure your POS app with these details:")
    print()
    print(f"Service Type: Custom/Free")
    print(f"Service URL: {api_url}")
    print(f"API Key: (not needed for this setup)")
    print(f"Restaurant ID: your-restaurant-name")
    print()
    print("1. Open your POS app")
    print("2. Go to Admin Panel → Settings")
    print("3. Find 'Cloud Printing' or 'Internet Printing'")
    print("4. Enter the details above")
    print("5. Click 'Test Connection'")
    print("6. Click 'Save Settings'")

def main():
    """Main deployment function"""
    print_banner()
    
    print("This will help you deploy your free API to the cloud.")
    print("No computer needed at your restaurant!")
    print()
    
    # Check prerequisites
    if not check_git_installed():
        print("❌ Git is not installed. Please install Git first:")
        print("   https://git-scm.com/downloads")
        return
    
    if not check_node_installed():
        print("❌ Node.js is not installed. Please install Node.js first:")
        print("   https://nodejs.org/")
        return
    
    print("✅ Prerequisites check passed")
    print()
    
    # Choose deployment platform
    print("Choose your free deployment platform:")
    print("1. Railway (Recommended - easiest)")
    print("2. Render")
    print("3. Heroku")
    print("4. Exit")
    
    choice = get_user_input("Enter your choice (1-4)", "1")
    
    if choice == "4":
        print("Deployment cancelled.")
        return
    
    # Create GitHub repository
    repo_url = create_github_repo()
    if not repo_url:
        return
    
    # Setup local project
    if not setup_local_project():
        return
    
    # Initialize git and push
    try:
        print("\n📤 Pushing to GitHub...")
        subprocess.run(['git', 'init'], check=True)
        subprocess.run(['git', 'add', '.'], check=True)
        subprocess.run(['git', 'commit', '-m', 'Initial commit - Free Restaurant Printing API'], check=True)
        subprocess.run(['git', 'branch', '-M', 'main'], check=True)
        subprocess.run(['git', 'remote', 'add', 'origin', repo_url], check=True)
        subprocess.run(['git', 'push', '-u', 'origin', 'main'], check=True)
        print("✅ Pushed to GitHub successfully")
    except subprocess.CalledProcessError as e:
        print(f"❌ Git error: {e}")
        return
    
    # Deploy to chosen platform
    api_url = None
    
    if choice == "1":
        api_url = deploy_to_railway()
    elif choice == "2":
        api_url = deploy_to_render()
    elif choice == "3":
        api_url = deploy_to_heroku()
    
    if not api_url:
        return
    
    # Test API
    if test_api(api_url):
        # Create POS configuration
        create_pos_config(api_url)
        
        # Final success message
        print(f"\n🎉 DEPLOYMENT COMPLETE!")
        print("=" * 40)
        print("✅ Free API deployed successfully")
        print("✅ API is working and ready")
        print("✅ No computer needed at restaurant")
        print("✅ Zero monthly cost")
        print()
        print("📋 Next Steps:")
        print("1. Configure your POS app with the details above")
        print("2. Test by creating an order and clicking 'Send to Kitchen'")
        print("3. Start printing from anywhere!")
        print()
        print("💰 Your Savings:")
        print("• Monthly cost: $0 (vs $29-99 for paid services)")
        print("• First year savings: $348-1,188")
        print()
        print("🚀 You're ready to print from home for FREE!")
    else:
        print("\n❌ API deployment failed. Please check your deployment platform.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️ Deployment cancelled by user")
    except Exception as e:
        print(f"\n❌ Deployment failed: {e}")
        print("📞 For help, check the platform documentation")
    
    input("\nPress Enter to exit...") 