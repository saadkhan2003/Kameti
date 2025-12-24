# Data Safety Questionnaire Answers

For Google Play's Data Safety section, use these answers:

## Data Collection

### Does your app collect or share any user data?
**Yes**

### Is all collected data encrypted in transit?
**Yes** (Firebase uses HTTPS)

### Do you provide a way for users to request data deletion?
**Yes** (In-app account deletion)

---

## Data Types Collected

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| **Email address** | ✅ Yes | ❌ No | Account management |
| **Name** | ✅ Yes | ❌ No | Display name |
| **App activity** | ✅ Yes | ❌ No | App functionality |
| **App info and performance** | ✅ Yes | ❌ No | Analytics, crash reports |

---

## Data Usage Purposes

| Purpose | Used |
|---------|------|
| Account management | ✅ Yes |
| Analytics | ✅ Yes (Firebase) |
| App functionality | ✅ Yes |
| Fraud prevention | ❌ No |
| Personalization | ❌ No |
| Advertising | ❌ No |

---

## Data Handling

| Question | Answer |
|----------|--------|
| Is data encrypted in transit? | ✅ Yes |
| Can users request data deletion? | ✅ Yes |
| Is data shared with third parties? | ❌ No |

---

## Third-Party SDKs Used

| SDK | Purpose | Data Collected |
|-----|---------|----------------|
| Firebase Auth | Authentication | Email |
| Firebase Firestore | Database | User content |
| Firebase Analytics | Analytics | Usage data |

---

## Notes for Play Console

When filling out the Data Safety form:
1. Select "App functionality" as primary purpose
2. Mention Firebase SDKs under third-party services
3. Mark data as NOT shared with third parties
4. Enable "Users can request data deletion"
