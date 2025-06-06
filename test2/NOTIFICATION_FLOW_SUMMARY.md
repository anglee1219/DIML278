# Prompt Unlock Notification Flow

## Overview
This document describes the complete implementation for handling prompt unlock notifications, including navigation, scrolling, and animation.

## Implementation Components

### 1. Notification Scheduling (EntryStore.swift)
- **Location**: `EntryStore.swift` - `scheduleNextPromptUnlockNotification()` method
- **Trigger**: Called when influencer uploads a photo/response
- **Frequency**: Based on group frequency (testing mode = 1 minute)
- **Content**: "🎉 New Prompt Unlocked!" with prompt text
- **Data**: Includes groupId, userId, groupName, prompt

### 2. Notification Tap Handling (test2App.swift)
- **Location**: `AppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)`
- **Detection**: Checks for `type = "prompt_unlock"`
- **Action**: Posts internal notification "NavigateToGroupAndUnlock"
- **Navigation**: Updates app state to navigate to specific group with unlock flags

### 3. Group Navigation (test2App.swift)
- **State Management**: Uses `shouldNavigateToGroup`, `targetGroupId`, `shouldTriggerUnlock`
- **Navigation**: Conditionally shows `GroupDetailViewWrapper` with unlock parameters
- **iOS Compatibility**: Handles both NavigationStack (iOS 16+) and NavigationView

### 4. GroupDetailViewWrapper
- **Initialization**: New constructor accepts `shouldTriggerUnlock` and `notificationUserInfo`
- **Pass-through**: Forwards parameters to `GroupDetailView`
- **Fallback**: Default constructor for normal usage

### 5. GroupDetailView - Notification Handling
- **New Properties**:
  - `cameFromNotification`: Boolean flag
  - `shouldTriggerNotificationUnlock`: Whether to trigger unlock sequence
  - `notificationPrompt`: Prompt text from notification

- **Constructor**: New initializer for notification handling

### 6. Unlock Sequence (GroupDetailView.onAppear)
When `cameFromNotification && shouldTriggerNotificationUnlock`:

1. **Verification**: Checks if user is influencer
2. **Prompt State**: Verifies current prompt is completed
3. **Feedback**: Shows unlock feedback banner
4. **Scroll**: Auto-scrolls to countdown timer (ID: "activePrompt")
5. **Animation**: Triggers unlock animation with haptic feedback
6. **Cleanup**: Resets notification flags

### 7. Unlock Animation (triggerPromptUnlockAnimation)
- **Haptic Feedback**: Heavy vibration for unlock start
- **Visual Effects**: Countdown refresh animation, sparkle effects
- **State Transitions**: Timer transforms into prompt card
- **Duration**: Multi-stage animation over ~3 seconds

## User Experience Flow

1. **Influencer uploads photo** → EntryStore schedules next unlock notification
2. **1 minute later** → Local notification fires: "🎉 New Prompt Unlocked!"
3. **User taps notification** → App opens (even if terminated)
4. **AppDelegate handles tap** → Parses notification data
5. **App navigates to group** → Opens specific GroupDetailView
6. **View detects notification flag** → Starts unlock sequence
7. **Auto-scroll to timer** → Shows "Next prompt unlocking in 0s"
8. **Haptic vibration** → Heavy impact feedback
9. **Unlock animation** → Timer transforms to prompt card
10. **Generate prompt card** → User can now answer new prompt

## Testing Instructions

1. **Setup**: Ensure user is influencer in testing group (1-minute frequency)
2. **Upload**: Take and upload a photo as influencer
3. **Wait**: Wait 1 minute with app backgrounded/terminated
4. **Notification**: Should receive "New Prompt Unlocked!" notification
5. **Tap**: Tap notification to open app
6. **Verify**: App should open to group, scroll to timer, vibrate, and show unlock animation

## Key Features

- **Works when app terminated**: Uses FCM push notifications
- **Automatic scrolling**: Finds and scrolls to countdown timer
- **Haptic feedback**: Provides satisfying unlock vibration
- **Visual feedback**: Enhanced animations with sparkle effects
- **State management**: Properly handles navigation and cleanup
- **iOS compatibility**: Works on all supported iOS versions

## Debug Logging

All major steps include detailed console logging prefixed with:
- `🔔 🎯` - Notification handling
- `🎬` - Animation sequences  
- `📍` - Scrolling actions
- `🔔 📸` - Regular notifications (uploads, reactions, comments)

## Files Modified

1. `test2/DIMLGroup/EntryStore.swift` - Notification scheduling
2. `test2/test2App.swift` - Notification tap handling and navigation
3. `test2/DIMLGroupScreens/GroupDetailView.swift` - Unlock sequence and animation 