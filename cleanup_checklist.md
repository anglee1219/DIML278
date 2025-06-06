# Pre-Deployment Cleanup Checklist

## ✅ Cleanup Order (Do in this sequence)

### Step 1: Firestore Collections
- [ ] Delete all documents in `entries` collection (all DIML posts)
- [ ] Delete all documents in `groups` collection (all test groups) 
- [ ] Delete all documents in `users` collection (all user profiles)

### Step 2: Firebase Authentication
- [ ] Go to Authentication → Users tab
- [ ] Select all test users and delete them

### Step 3: Firebase Storage  
- [ ] Go to Storage tab
- [ ] Delete all uploaded images/media files

### Step 4: Local App Cache
- [ ] Uninstall and reinstall app on test devices
- [ ] Or clear app data in simulator

## ✅ Post-Cleanup Testing

### Critical Tests:
- [ ] New user can register successfully
- [ ] Login screen works
- [ ] Profile building flow completes
- [ ] Onboarding tutorial appears for new users
- [ ] Empty states display correctly:
  - [ ] "No groups yet" in GroupListView
  - [ ] "No DIML memories yet" in MyCapsuleView
  - [ ] Loading states work properly

### App Doesn't Crash When:
- [ ] Opening with no data
- [ ] Loading empty collections
- [ ] Creating first group
- [ ] Taking first photo

## 🚀 Ready for Deployment

Once all tests pass:
- [ ] App handles fresh install gracefully
- [ ] No test data remnants
- [ ] All user flows work from scratch
- [ ] Production Firebase project is clean

## 🆘 Emergency Recovery (If Something Breaks)

If you need to quickly add test data back:

```swift
// Quick test users for emergency
let testUsers = [
    "test1@example.com",
    "test2@example.com"
]

// Quick test group
{
  "name": "Test Group",
  "members": [...],
  "currentInfluencerId": "...",
  "promptFrequency": "sixHours"
}
```

## 📝 Notes

- This is a one-way operation - deleted data cannot be recovered
- Consider exporting important data before deletion
- Test on a single device first
- Make sure you have app store credentials ready for deployment 