import Foundation
import UserNotifications

enum PromptFrequency: String, Codable {
    case once = "Once per day"
    case twice = "Twice per day"
    case thrice = "Three times per day"
    
    var numberOfPrompts: Int {
        switch self {
        case .once: return 1
        case .twice: return 2
        case .thrice: return 3
        }
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound], completionHandler: { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        })
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
            
            var timeSlots: [(TimeOfDay, TimeWindow)] = []
            
            // Determine time slots based on frequency
            switch frequency {
            case .once:
                // Randomly choose morning, afternoon, or night
                let randomPeriod = [TimeOfDay.morning, .afternoon, .night].randomElement()!
                switch randomPeriod {
                case .morning:
                    timeSlots = [(randomPeriod, TimeWindow.morning)]
                case .afternoon:
                    timeSlots = [(randomPeriod, TimeWindow.afternoon)]
                case .night:
                    timeSlots = [(randomPeriod, TimeWindow.night)]
                }
                
            case .twice:
                // Choose two random non-repeating periods
                let periods = Array(Set([TimeOfDay.morning, .afternoon, .night]).shuffled().prefix(2))
                timeSlots = periods.map { period in
                    switch period {
                    case .morning: return (period, TimeWindow.morning)
                    case .afternoon: return (period, TimeWindow.afternoon)
                    case .night: return (period, TimeWindow.night)
                    }
                }
                
            case .thrice:
                // Use all three periods in order
                timeSlots = [
                    (.morning, TimeWindow.morning),
                    (.afternoon, TimeWindow.afternoon),
                    (.night, TimeWindow.night)
                ]
            }
            
            // Create a dispatch group to track when all notifications are scheduled
            let group = DispatchGroup()
            
            // Schedule notifications for each time slot
            for (timeOfDay, window) in timeSlots {
                group.enter()
                self.scheduleNotification(
                    for: timeOfDay,
                    window: window,
                    userId: influencerId,
                    type: .prompt,
                    completion: {
                        group.leave()
                    }
                )
            }
            
            // When all notifications are scheduled, check the results
            group.notify(queue: .main) {
                completion?()
            }
        }
    }
    
    private func findValidTime(in window: TimeWindow, baseDate: Date) -> Date? {
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            // Get random hour and minute within the window
            let hour = Int.random(in: window.start...window.end)
            let minute = Int.random(in: 0...59)
            
            // Create date components
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = 0
            
            // Create the date
            if let date = calendar.date(from: dateComponents),
               window.isValidTime(hour, minute),
               notificationManager.canSchedule(at: date, in: window) {
                return date
            }
            
            attempts += 1
        }
        
        return nil
    }
    
    private func scheduleNotification(for timeOfDay: TimeOfDay, window: TimeWindow, userId: String, type: NotificationType, completion: @escaping () -> Void) {
        guard let prompt = promptManager.getRandomPrompt(for: timeOfDay) else {
            completion()
            return
        }
        
        // Get tomorrow's date
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        
        // Find a valid time for the notification
        guard let scheduledDate = findValidTime(in: window, baseDate: tomorrow) else {
            print("Could not find valid time for \(timeOfDay) notification")
            completion()
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Time for your \(timeOfDay) reflection!"
        content.body = prompt
        content.sound = .default
        
        // Get date components for the scheduled date
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: scheduledDate)
        
        // Create a unique but consistent identifier for this time period
        let identifier = "\(type.rawValue)_\(userId)_\(timeOfDay)_\(dateComponents.year!)\(dateComponents.month!)\(dateComponents.day!)"
        
        // Format time for logging
        let timeString = String(format: "%02d:%02d", dateComponents.hour!, dateComponents.minute!)
        print("Scheduling \(timeOfDay) notification for tomorrow at \(timeString) local time")
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling \(timeOfDay) notification: \(error)")
            } else {
                if let date = trigger.nextTriggerDate() {
                    let formatter = DateFormatter()
                    formatter.timeZone = TimeZone.current
                    formatter.dateFormat = "MMM d, h:mm a"
                    print("Successfully scheduled \(timeOfDay) notification for \(formatter.string(from: date))")
                }
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
        print("\nTesting Once per day:")
        let checkNotifications: () -> Void = { [weak self] in
            self?.checkPendingNotifications(completion: { [weak self] in
                self?.runResponseNotificationTest(influencer: influencer, members: members)
            })
        }
        
        schedulePrompts(
            for: .once,
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