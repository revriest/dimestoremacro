# Privacy Policy for BareMacros

**Last Updated:** January 3, 2026

## Overview
BareMacros ("the App") is a nutrition tracking application that respects your privacy. We believe your data belongs to you, which is why everything stays on your device.

## Our Philosophy
**We don't collect, store, or sell your personal information. Period.**

All your data is stored locally on your device using SQLite database and SharedPreferences. We have no servers, no cloud storage, and no user accounts.

## What Data Stays On Your Device

The following data is stored **locally on your device only**:
- Daily macro entries (protein, carbs, fat, calories)
- Custom food items you create
- Your macro targets and goals
- Date-specific nutrition logs
- App preferences and settings

**We cannot access this data.** It never leaves your device.

## Third-Party Services

### USDA FoodData Central API
When you search for foods, the app queries the USDA FoodData Central public API. This may log:
- Search query text (e.g., "chicken breast")
- Timestamp of request
- Your IP address (standard for any internet request)

We do not control USDA's servers or have access to their logs.  
USDA Privacy Policy: https://www.usda.gov/privacy-policy

### OpenFoodFacts API
When you scan barcodes, the app queries OpenFoodFacts, a free and open database. This may log:
- Barcode numbers scanned
- Timestamp of request
- Your IP address

OpenFoodFacts is a non-profit community project.  
Terms of Use: https://world.openfoodfacts.org/terms-of-use

## Your Data, Your Control

### Export Your Data
All your data is in a SQLite database on your device:
- **iOS:** `~/Library/Application Support/baremacros.db`
- **Android:** `/data/data/com.baremacros/databases/baremacros.db`

You can extract this file using standard device backup tools.

### Delete Your Data
Uninstalling the app **permanently deletes** all local data. There is no cloud backup or remote storage to worry about.

## App Permissions

### Required:
- **Internet:** To search food databases (USDA, OpenFoodFacts)

### Optional:
- **Camera:** Only if you choose to scan barcodes (can be denied)

### Never Used:
- Location tracking
- Contacts access
- Microphone
- Photo library (except camera for barcode scanner)
- Background location
- Analytics or tracking SDKs

## What We Don't Do

❌ We don't create user accounts  
❌ We don't collect email addresses  
❌ We don't track your behavior  
❌ We don't sell data to third parties  
❌ We don't show targeted ads  
❌ We don't use analytics tools  
❌ We don't have a marketing database  

## Children's Privacy
BareMacros does not knowingly collect information from anyone under 13. The app is designed for general audiences interested in nutrition tracking.

## Changes to This Policy
We may update this policy to reflect changes in the app or legal requirements. Updates will be posted here with a new "Last Updated" date.

Check back periodically for changes.

## International Users

### GDPR (European Union)
Since we don't collect or process personal data on servers, most GDPR obligations don't apply. However, your rights:
- **Right to Access:** Your data is already on your device
- **Right to Delete:** Uninstall the app
- **Right to Portability:** Export the SQLite file
- **Right to Object:** You control all data locally

### CCPA (California)
We don't sell personal information. We don't share personal information. We don't collect personal information beyond what stays on your device.

## Contact Us

Questions about this privacy policy?

- **Email:** support@baremacros.com
- **GitHub:** https://github.com/revriest/dimestoremacro

We'll respond within 48 hours.

---

**The Bottom Line:**  
BareMacros is built on the principle that your nutrition data is private. We designed the app so that even if we wanted to access your data, we couldn't. It's all on your device, under your control.
