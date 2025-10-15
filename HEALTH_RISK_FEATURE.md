# Health Risk Monitoring Feature

## Overview
The Health Risk Monitor is a new feature added to the Civic Fraud Protection app that analyzes text content (SMS messages, social media posts, etc.) to detect potential community health risks and early warning signs of disease outbreaks, contamination, or medical emergencies.

## Features

### 🏥 Health Risk Detection Categories

1. **Disease Outbreaks**
   - Detects mentions of epidemics, pandemics, outbreaks
   - Identifies specific diseases: cholera, dengue, typhoid, COVID-19, etc.
   - Keywords: "outbreak", "epidemic", "many sick", "virus spreading", etc.

2. **Food & Water Contamination**
   - Food poisoning incidents
   - Contaminated water supplies
   - Waterborne and foodborne disease mentions
   - Keywords: "food poisoning", "contaminated water", "bad food", etc.

3. **Environmental Health Hazards**
   - Air pollution and air quality issues
   - Chemical leaks and toxic fumes
   - Radiation and hazardous materials
   - Keywords: "air pollution", "chemical leak", "toxic fumes", etc.

4. **Medical Emergencies**
   - Hospital capacity issues
   - Medicine/vaccine shortages
   - Healthcare system crises
   - Keywords: "hospital full", "medicine shortage", "no beds available", etc.

5. **Symptom Clusters**
   - Multiple people sick in an area
   - Mass illness events
   - Community-wide health concerns
   - Keywords: "everyone sick", "whole family sick", "neighborhood sick", etc.

### ⚕️ Risk Levels

- **🔴 HIGH RISK** (Red): Immediate attention required
  - Disease outbreak detected
  - Multiple high-priority keywords found
  - Confidence: 85%+
  - Triggers: Notification + Alert saved to database

- **🟠 MEDIUM RISK** (Orange): Monitor situation closely
  - Moderate health concerns detected
  - Some concerning keywords present
  - Confidence: 60-85%
  - Triggers: Alert saved to database

- **🔵 LOW RISK** (Blue): Minor health mention
  - General health-related text
  - Confidence: 30-60%
  - No action triggered

### 📊 Features

1. **Text Analysis**
   - Manual text input analysis
   - Paste any message/text for instant health risk assessment
   - Real-time keyword detection

2. **SMS Integration**
   - Automatic health risk scanning of incoming SMS (optional)
   - Detects health risks in device messages
   - Notifications for high-risk messages

3. **Statistics Dashboard**
   - Total health alerts tracked
   - Breakdown by risk level (High/Medium/Low)
   - Recent alerts list

4. **Smart Recommendations**
   - Context-aware action items based on detected risk category
   - Examples:
     - 🏥 Report to health authorities
     - 💧 Boil water before drinking
     - 😷 Wear masks and follow hygiene protocols
     - 📞 Contact emergency services

## How to Use

### From Dashboard
1. Open the app
2. Tap on the **Health Risk Monitor** card (teal colored)
3. Or use the menu (⋮) → Select "Health Risk Monitor"

### Analyze Text
1. Open Health Risk Monitor screen
2. Enter or paste text in the input field
3. Tap "Analyze Text" button
4. View results:
   - Risk level and confidence score
   - Detected categories
   - Keywords found
   - Actionable recommendations

### View Statistics
- Top section shows overview:
  - Total alerts
  - High/Medium/Low risk counts
- Scroll down to see recent health alerts

### SMS Auto-Scan
- Automatically enabled in SMS Spam Detection screen
- Health risks are detected in incoming messages
- Notifications appear for medium/high risks
- Health risk indicator shown in message list

## Technical Details

### Files Added
```
lib/services/health_risk_service.dart    # Core detection logic
lib/screens/health_risk_screen.dart      # UI screen
```

### Files Modified
```
lib/screens/dashboard.dart               # Added health risk card + menu item
lib/screens/message_spam_screen.dart     # SMS integration
lib/main.dart                            # Added route
```

### Dependencies
- Uses existing `sqflite` database for storing alerts
- Integrates with existing notification system
- No additional packages required

### Database Integration
- Health alerts saved to existing `fraud_alerts` table
- Type: "Health Risk"
- Contains detected keywords and categories
- Accessible from Recent Alerts section

## Examples

### Example 1: Disease Outbreak
**Input Text:**
```
"Many people in our neighborhood are experiencing high fever and breathing 
problems. The clinic is full and they say there's an outbreak spreading fast."
```

**Result:**
- Risk Level: **HIGH**
- Confidence: 92%
- Categories: disease_outbreak, symptoms_cluster, medical_emergency
- Keywords: many people sick, high fever, breathing problems, outbreak, spreading fast, clinic full
- Recommendations:
  - 🏥 Report to local health authorities immediately
  - 😷 Follow hygiene protocols and wear masks
  - 🚫 Avoid crowded areas if possible
  - 📊 Monitor and document cases in your area
  - ⚠️ Share this information with neighbors

### Example 2: Water Contamination
**Input Text:**
```
"The water from the main supply has turned yellowish and many families 
are complaining of stomach infections after drinking it."
```

**Result:**
- Risk Level: **MEDIUM**
- Confidence: 73%
- Categories: food_water_contamination, symptoms_cluster
- Keywords: water supply, stomach infection, many families, contaminated
- Recommendations:
  - 💧 Boil drinking water before consumption
  - 🍲 Avoid eating outside food
  - 🚰 Report to water supply authority
  - 📊 Monitor and document cases in your area

### Example 3: Air Quality Issue
**Input Text:**
```
"Heavy smog today, lots of people having breathing issues and asthma attacks."
```

**Result:**
- Risk Level: **MEDIUM**
- Confidence: 68%
- Categories: environmental_health, symptoms_cluster
- Keywords: smog, breathing problems, asthma attack, lots of people
- Recommendations:
  - 🌬️ Stay indoors if air quality is poor
  - 😷 Use N95 masks if going outside
  - 📞 Contact environmental protection agency

## Privacy & Data

- All analysis happens locally on device
- No data sent to external servers
- Alerts stored in local database only
- User controls when to analyze text
- SMS auto-scan can be disabled

## Future Enhancements

Potential improvements for future versions:
- [ ] Machine learning model for better accuracy
- [ ] Multi-language support
- [ ] Location-based health risk mapping
- [ ] Integration with official health authority APIs
- [ ] Historical trend analysis
- [ ] Community reporting features
- [ ] Export health alerts for reporting

## Support

For issues or questions about the Health Risk Monitor feature, please refer to the main app documentation or contact support.

---

**Note:** This feature is designed to assist in early detection of community health risks. It should not replace official health advice or emergency services. Always consult healthcare professionals for medical concerns.
