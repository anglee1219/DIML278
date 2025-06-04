import Foundation
import UserNotifications

enum PromptFrequency: String, Codable, CaseIterable {
    case testing = "Every minute (testing)"
    case hourly = "Every hour"
    case threeHours = "Every 3 hours"
    case sixHours = "Every 6 hours"
    
    var numberOfPrompts: Int {
        switch self {
        case .testing: return 10 // 10 prompts for testing
        case .hourly: return 12 // Roughly 12 prompts in a 12-hour active day
        case .threeHours: return 4 // 4 prompts in 12 hours
        case .sixHours: return 2 // 2 prompts in 12 hours
        }
    }
    
    var intervalHours: Int {
        switch self {
        case .testing: return 0 // Special case for minute intervals
        case .hourly: return 1
        case .threeHours: return 3
        case .sixHours: return 6
        }
    }
    
    var intervalMinutes: Int {
        switch self {
        case .testing: return 1
        case .hourly: return 60
        case .threeHours: return 180
        case .sixHours: return 360
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

enum NotificationType: String {
    case prompt = "prompt"
    case response = "response"
}

struct TimeWindow {
    let start: Int
    let end: Int
    let minimumSpacing: Int // minimum minutes between notifications
    
    func isValidTime(_ hour: Int, _ minute: Int) -> Bool {
        return hour >= start && hour <= end
    }
    
    static let morning = TimeWindow(start: 7, end: 11, minimumSpacing: 60)
    static let afternoon = TimeWindow(start: 12, end: 16, minimumSpacing: 60)
    static let night = TimeWindow(start: 17, end: 21, minimumSpacing: 60)
}

class NotificationManager {
    static let shared = NotificationManager()
    private var scheduledTimes: [(Date, TimeWindow)] = []
    
    func canSchedule(at date: Date, in window: TimeWindow) -> Bool {
        // Remove old scheduled times
        scheduledTimes = scheduledTimes.filter { $0.0 > Date() }
        
        // Check if the proposed time conflicts with any existing notifications
        for (existingDate, existingWindow) in scheduledTimes {
            let difference = abs(date.timeIntervalSince(existingDate))
            if difference < Double(existingWindow.minimumSpacing * 60) {
                return false
            }
        }
        
        // Add the new time if it's valid
        scheduledTimes.append((date, window))
        return true
    }
    
    func clear() {
        scheduledTimes.removeAll()
    }
}

class PromptScheduler {
    static let shared = PromptScheduler()
    private let promptManager = PromptManager.shared
    private let notificationManager = NotificationManager.shared
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }()
    
    private init() {
        // Permission is now handled in AppDelegate, no need to request again here
        print("🔔 PromptScheduler initialized")
    }
    
    func schedulePrompts(for frequency: PromptFrequency, influencerId: String, completion: (() -> Void)? = nil) {
        // Clear notification manager state
        notificationManager.clear()
        
        // First, remove ALL existing notifications for this influencer
        removeExistingNotifications(for: influencerId, type: .prompt) {
            guard let currentUserId = UserDefaults.standard.string(forKey: "currentUserId"),
                  currentUserId == influencerId else {
                completion?()
                return
            }
            
            // Handle testing frequency differently
            if frequency == .testing {
                self.scheduleTestingPrompts(userId: influencerId, completion: completion)
                return
            }
            
            // Create a dispatch group to track when all notifications are scheduled
            let group = DispatchGroup()
            
            // Schedule notifications based on frequency throughout the day
            let activeDayStart = 7 // 7 AM
            let activeDayEnd = 21   // 9 PM (14 hour active day)
            let intervalHours = frequency.intervalHours
            
            // Calculate how many notifications to schedule
            let totalActiveHours = activeDayEnd - activeDayStart
            let notificationCount = totalActiveHours / intervalHours
            
            for i in 0..<notificationCount {
                group.enter()
                
                // Calculate the hour for this notification
                let notificationHour = activeDayStart + (i * intervalHours)
                
                // Determine which time period this falls into
                let timeOfDay: TimeOfDay
                if notificationHour < 12 {
                    timeOfDay = .morning
                } else if notificationHour < 17 {
                    timeOfDay = .afternoon
                } else {
                    timeOfDay = .night
                }
                
                // Schedule notification for this specific hour
                self.scheduleHourlyNotification(
                    for: timeOfDay,
                    at: notificationHour,
                    userId: influencerId,
                    completion: {
                        group.leave()
                    }
                )
            }
            
            // When all notifications are scheduled, complete
            group.notify(queue: .main) {
                completion?()
            }
        }
    }
    
    private func scheduleTestingPrompts(userId: String, completion: (() -> Void)? = nil) {
        print("📱 Scheduling testing prompts (every minute)")
        
        let group = DispatchGroup()
        let numberOfPrompts = 10 // Test with 10 prompts
        
        for i in 0..<numberOfPrompts {
            group.enter()
            
            let content = UNMutableNotificationContent()
            content.title = "🧪 Test Prompt #\(i + 1)"
            content.body = "Time to answer your DIML prompt!"
            content.sound = .default
            
            // Schedule each prompt 1 minute apart, starting from 1 minute from now
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval((i + 1) * 60), // Every minute
                repeats: false
            )
            
            let identifier = "test_prompt_\(userId)_\(i)_\(Date().timeIntervalSince1970)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Error scheduling test prompt \(i + 1): \(error)")
                } else {
                    print("✅ Scheduled test prompt \(i + 1) for \(i + 1) minute(s) from now")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("🎉 All testing prompts scheduled!")
            completion?()
        }
    }
    
    private func scheduleHourlyNotification(for timeOfDay: TimeOfDay, at hour: Int, userId: String, completion: @escaping () -> Void) {
        guard let prompt = promptManager.getRandomPrompt(for: timeOfDay) else {
            completion()
            return
        }
        
        // Get today's date for scheduling throughout the influencer's day
        let today = Date()
        
        // Create date components for the specific hour
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: today)
        dateComponents.hour = hour
        dateComponents.minute = Int.random(in: 0...59) // Random minute within the hour
        dateComponents.second = 0
        
        // Create the scheduled date
        guard let scheduledDate = calendar.date(from: dateComponents) else {
            print("Could not create date for hour \(hour)")
            completion()
            return
        }
        
        // If the time has already passed today, schedule for tomorrow
        let finalDate = scheduledDate < Date() ? 
            calendar.date(byAdding: .day, value: 1, to: scheduledDate)! : 
            scheduledDate
        
        let content = UNMutableNotificationContent()
        content.title = "Time for your reflection!"
        content.body = prompt
        content.sound = .default
        
        // Get final date components
        let finalComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: finalDate)
        
        // Create identifier
        let identifier = "prompt_\(userId)_\(hour)_\(finalComponents.year!)\(finalComponents.month!)\(finalComponents.day!)"
        
        // Format time for logging
        let timeString = String(format: "%02d:%02d", finalComponents.hour!, finalComponents.minute!)
        print("Scheduling prompt notification for \(finalDate > Date() ? "today" : "tomorrow") at \(timeString)")
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: finalComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification for hour \(hour): \(error)")
            } else {
                print("Successfully scheduled notification for hour \(hour)")
            }
            completion()
        }
    }
    
    // Send notification to all group members when influencer posts
    func notifyGroupMembers(groupId: String, influencerName: String, members: [User], completion: (() -> Void)? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "New DIML Post!"
        content.body = "\(influencerName) just shared their day in my life!"
        content.sound = .default
        
        // Create a dispatch group to track notifications
        let group = DispatchGroup()
        
        // Schedule notification for each member except the influencer
        for (index, member) in members.enumerated() {
            group.enter()
            
            // Create unique identifier for this notification
            let identifier = "response_\(groupId)_\(member.id)_\(Date().timeIntervalSince1970)"
            
            // Create trigger with a longer delay to ensure visibility in testing
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5.0 + Double(index), repeats: false)
            
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling response notification for member \(member.id): \(error)")
                } else {
                    print("Scheduled response notification for member \(member.id)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Add a delay before checking notifications to ensure they're all registered
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                completion?()
            }
        }
    }
    
    private func removeExistingNotifications(for userId: String, type: NotificationType, completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            // Remove notifications for this user and type
            let identifiersToRemove = requests.filter { request in
                request.identifier.contains("\(type.rawValue)_\(userId)")
            }.map { $0.identifier }
            
            if !identifiersToRemove.isEmpty {
                print("Removing \(identifiersToRemove.count) existing notifications for user \(userId)")
            }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            
            // Small delay to ensure notifications are removed before scheduling new ones
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
        }
    }
    
    // Send immediate notification when new prompt is unlocked
    func sendPromptUnlockedNotification(prompt: String, userId: String) {
        print("📱 sendPromptUnlockedNotification called")
        print("📱 prompt: '\(prompt)'")
        print("📱 userId: '\(userId)'")
        
        // Send notification immediately
        let content = UNMutableNotificationContent()
        content.title = "🔓 New Prompt Unlocked!"
        content.body = prompt
        content.sound = .default
        content.badge = 1
        
        print("📱 Creating notification with title: '\(content.title)'")
        print("📱 Creating notification with body: '\(content.body)'")
        
        // Send immediately with a 1 second delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        
        let identifier = "prompt_unlocked_\(userId)_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        print("📱 Adding notification request with identifier: \(identifier)")
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("📱 ❌ Error sending prompt unlock notification: \(error)")
                print("📱 ❌ Error details: \(error.localizedDescription)")
            } else {
                print("📱 ✅ Successfully added prompt unlock notification to queue")
                print("📱 ✅ Notification will appear in 1 second")
                
                // Double-check that the notification was actually scheduled
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    let promptUnlockRequests = requests.filter { $0.identifier.contains("prompt_unlocked") }
                    print("📱 📋 Total pending prompt unlock notifications: \(promptUnlockRequests.count)")
                    for req in promptUnlockRequests {
                        print("📱 📋 - \(req.identifier): '\(req.content.title)' - '\(req.content.body)'")
                    }
                }
            }
        }
    }
    
    func cancelAllPrompts() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func testScheduler() {
        print("\n=== Testing Prompt Scheduler ===")
        
        // Reset the PromptManager's used prompts before testing
        promptManager.resetUsedPrompts()
        
        // Create test users
        let influencer = User(id: "test_influencer", name: "Test Influencer")
        let member1 = User(id: "test_member1", name: "Test Member 1")
        let member2 = User(id: "test_member2", name: "Test Member 2")
        
        // Set current user as influencer for testing
        UserDefaults.standard.set(influencer.id, forKey: "currentUserId")
        
        // Clear notification manager state
        notificationManager.clear()
        
        // Remove all pending notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Wait a moment for notifications to be cleared, then start test
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.runPromptTest(influencer: influencer, members: [member1, member2])
        }
    }
    
    private func runPromptTest(influencer: User, members: [User]) {
        print("\nTesting Every 6 hours:")
        let checkNotifications: () -> Void = { [weak self] in
            self?.checkPendingNotifications(completion: { [weak self] in
                self?.runResponseNotificationTest(influencer: influencer, members: members)
            })
        }
        
        schedulePrompts(
            for: .sixHours,
            influencerId: influencer.id,
            completion: checkNotifications
        )
    }
    
    private func runResponseNotificationTest(influencer: User, members: [User]) {
        print("\nTesting response notification:")
        let completion: () -> Void = { [weak self] in
            self?.checkPendingNotifications(completion: {
                print("\n=== End of Test ===\n")
            })
        }
        
        notifyGroupMembers(
            groupId: "test_group",
            influencerName: influencer.name,
            members: members,
            completion: completion
        )
    }
    
    private func checkPendingNotifications(completion: (() -> Void)? = nil) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("\nPending Notifications:")
            print("Total scheduled notifications: \(requests.count)")
            
            // Separate prompts and responses
            let promptNotifications = requests.filter { $0.identifier.starts(with: "prompt_") }
            let responseNotifications = requests.filter { $0.identifier.starts(with: "response_") }
            
            // Sort and print prompt notifications
            if !promptNotifications.isEmpty {
                print("\nPrompt Notifications:")
                self.printSortedNotifications(promptNotifications)
            }
            
            // Sort and print response notifications
            if !responseNotifications.isEmpty {
                print("\nResponse Notifications:")
                self.printSortedNotifications(responseNotifications)
            }
            
            if requests.isEmpty {
                print("\nNo pending notifications found.")
            }
            
            // Add a delay before completing to ensure we can see all notifications
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                completion?()
            }
        }
    }
    
    private func printSortedNotifications(_ requests: [UNNotificationRequest]) {
        // First sort by notification type (prompts before responses)
        let sortedRequests = requests.sorted { req1, req2 in
            // First sort by type (prompts before responses)
            if req1.identifier.starts(with: "prompt_") && !req2.identifier.starts(with: "prompt_") {
                return true
            }
            if !req1.identifier.starts(with: "prompt_") && req2.identifier.starts(with: "prompt_") {
                return false
            }
            
            // Then sort by trigger time
            if let trigger1 = req1.trigger as? UNCalendarNotificationTrigger,
               let trigger2 = req2.trigger as? UNCalendarNotificationTrigger,
               let date1 = trigger1.nextTriggerDate(),
               let date2 = trigger2.nextTriggerDate() {
                return date1 < date2
            }
            
            // For time interval triggers, sort by interval
            if let trigger1 = req1.trigger as? UNTimeIntervalNotificationTrigger,
               let trigger2 = req2.trigger as? UNTimeIntervalNotificationTrigger {
                return trigger1.timeInterval < trigger2.timeInterval
            }
            
            return false
        }
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MMM d, h:mm a"
        
        for (index, request) in sortedRequests.enumerated() {
            print("\nNotification \(index + 1):")
            print("ID: \(request.identifier)")
            
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let date = trigger.nextTriggerDate() {
                print("Time: \(formatter.string(from: date))")
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                print("Trigger: In \(String(format: "%.1f", trigger.timeInterval)) seconds")
            }
            
            print("Title: \(request.content.title)")
            print("Body: \(request.content.body)")
        }
    }
} 