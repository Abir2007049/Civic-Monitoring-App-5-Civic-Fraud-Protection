# Package Recommendations Feature

## Overview
Smart telecom package recommendation system that analyzes your actual usage patterns (call logs and SMS) to suggest optimal data, voice, and SMS packages.

## Features

### 📊 Usage Analysis
- **Outgoing Call Minutes**: Tracks total minutes and call count
- **Sent Messages**: Counts SMS you've sent
- **Data Estimation**: Provides approximate data usage estimate
- **Flexible Period**: Analyze last 7, 15, or 30 days

### 💰 Smart Recommendations
The system generates personalized package suggestions:
- **7-Day Packages**: Short-term needs
- **15-Day Packages**: Bi-weekly plans (often marked as RECOMMENDED)
- **30-Day Packages**: Monthly subscriptions with best value
- **Light User Packages**: For minimal usage (< 30 mins, < 50 SMS)
- **Unlimited Packages**: For heavy users (> 500 mins or > 10GB)

### 📱 Package Details
Each recommendation includes:
- Data allowance (GB)
- Call minutes
- SMS count
- Validity period (7/15/30 days)
- Estimated price in BDT (৳)
- Usage-based description

## How It Works

### Analysis Algorithm
1. **Fetch Data**:
   - Reads call logs (filters outgoing calls only)
   - Reads sent SMS messages
   - Filters by selected time period

2. **Calculate Averages**:
   - Daily call minutes = Total minutes / Days
   - Daily SMS = Total SMS / Days
   - Daily data = Estimated GB / Days

3. **Project Usage**:
   - For each package duration (7/15/30 days)
   - Multiply daily average × days
   - Add buffer (10-20% extra) to avoid overages

4. **Round to Standard Packages**:
   - Data: 1GB, 2GB, 3GB, 5GB, 10GB, 15GB, 20GB
   - Minutes: 30, 50, 100, 200, 300, 500, 1000, 2000
   - SMS: 50, 100, 200, 500, 1000

5. **Calculate Pricing**:
   - Base formula: (Data × 15) + (Minutes/100 × 10) + (SMS/100 × 5)
   - Apply duration discounts: 15% for monthly, 10% for bi-weekly
   - Round to nearest 10 BDT

## Usage Example

### Scenario 1: Light User
**Your Usage (30 days)**:
- Outgoing: 45 minutes (12 calls)
- Sent SMS: 35 messages
- Data: ~4.3 GB

**Recommended**: Bi-Weekly Plus
- 2GB data, 50 mins, 100 SMS, 15 days
- Price: ৳80

### Scenario 2: Regular User
**Your Usage (30 days)**:
- Outgoing: 320 minutes (68 calls)
- Sent SMS: 125 messages
- Data: ~4.3 GB

**Recommended**: Bi-Weekly Plus
- 5GB data, 500 mins, 200 SMS, 15 days
- Price: ৳150

### Scenario 3: Heavy User
**Your Usage (30 days)**:
- Outgoing: 1200 minutes (245 calls)
- Sent SMS: 450 messages
- Data: ~4.3 GB

**Recommended**: Unlimited Pro
- Unlimited data, calls & SMS, 30 days
- Price: ৳999

## Screen Navigation

### From Dashboard:
- Tap the purple "Package Recommendations" card
- Or use the menu (top-right) → "Package Recommendations"

### In-Screen Features:
- **Period Selector**: Switch between 7/15/30 day analysis
- **Usage Stats Card**: See your actual usage
- **Package Cards**: View all recommendations
- **View Details Button**: See full package breakdown
- **Refresh Button**: Re-analyze latest data

## UI Highlights

### Color Coding
- **Purple Card**: Package Recommendations feature
- **Green Badge**: "RECOMMENDED" tag on best-value package
- **Bold Border**: Recommended packages have 2px green border

### Icons
- 📊 Analytics icon for usage stats
- 📞 Phone for call minutes
- 💬 SMS for messages
- 📶 Data usage for GB
- 🎁 Gift card for packages

## Data Privacy
- All analysis is done **locally on your device**
- No usage data is sent to external servers
- Only reads outgoing calls and sent SMS (respects your privacy)
- Requires Phone and SMS permissions

## Pricing Model
The estimated prices use a simple formula and can be customized in `telecom_analysis_service.dart`:

```dart
double _estimatePrice(int dataGB, int mins, int sms, int days) {
  double base = 0;
  base += dataGB * 15.0;        // ৳15 per GB
  base += (mins / 100) * 10.0;  // ৳10 per 100 minutes
  base += (sms / 100) * 5.0;    // ৳5 per 100 SMS
  
  // Duration discounts
  if (days >= 30) base *= 0.85;      // 15% off monthly
  else if (days >= 15) base *= 0.90; // 10% off bi-weekly
  
  return (base / 10).ceil() * 10.0;  // Round to nearest ৳10
}
```

## Technical Details

### Files Created
1. **lib/services/telecom_analysis_service.dart**
   - `TelecomAnalysisService`: Main analysis engine
   - `UsageStats`: Model for usage data
   - `PackageRecommendation`: Model for package details

2. **lib/screens/package_recommendation_screen.dart**
   - Main UI screen
   - Period selector (7/15/30 days)
   - Usage stats card
   - Package recommendations list
   - Package details dialog

### Integration Points
- **main.dart**: Route `/package_recommendations`
- **dashboard.dart**: 
  - Purple quick access card
  - Menu item with purple icon
  - Navigation handler

## Future Enhancements
- [ ] Real mobile data usage tracking (requires additional permissions)
- [ ] Price comparison with actual operator rates
- [ ] Historical usage trends chart
- [ ] Export recommendations to PDF/image
- [ ] Direct purchase links (operator-specific)
- [ ] Family/shared package recommendations
- [ ] Roaming package suggestions based on travel patterns

## Quick Start

1. **Open the App** → Dashboard
2. **Tap** "Package Recommendations" card (purple)
3. **Select** analysis period (7/15/30 days)
4. **View** your usage stats
5. **Browse** recommended packages
6. **Tap** "View Details" for full breakdown

The system will automatically analyze your call logs and SMS to provide personalized recommendations!

---

**Note**: This feature analyzes **outgoing calls** and **sent SMS** only. Incoming calls and received messages are not counted as they don't typically affect your package limits.
