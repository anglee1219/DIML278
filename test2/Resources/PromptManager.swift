import Foundation

enum TimeOfDay {
    case morning
    case afternoon
    case night
    
    static func current() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        default: return .night
        }
    }
}

class PromptManager {
    private var morningPrompts: [String]
    private var afternoonPrompts: [String]
    private var nightPrompts: [String]
    
    private var usedPrompts: Set<String> = []
    
    static let shared = PromptManager()
    
    private init() {
        // Initialize with empty arrays
        morningPrompts = []
        afternoonPrompts = []
        nightPrompts = []
        
        loadPrompts()
    }
    
    private func loadPrompts() {
        guard let path = Bundle.main.path(forResource: "Prompts", ofType: "csv") else {
            print("Error: Could not find Prompts.csv")
            return
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            var rows = content.components(separatedBy: .newlines)
            
            // Remove empty rows
            rows = rows.filter { !$0.isEmpty }
            
            // Skip header row
            for row in rows.dropFirst() {
                // Use CSV parsing to handle quotes correctly
                let columns = parseCSVRow(row)
                if columns.count >= 3 {
                    if !columns[0].isEmpty { morningPrompts.append(cleanPrompt(columns[0])) }
                    if !columns[1].isEmpty { afternoonPrompts.append(cleanPrompt(columns[1].trimmingCharacters(in: .whitespaces))) }
                    if !columns[2].isEmpty { nightPrompts.append(cleanPrompt(columns[2])) }
                }
            }
        } catch {
            print("Error loading prompts: \(error)")
        }
    }
    
    private func parseCSVRow(_ row: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        
        for char in row {
            switch char {
            case "\"":
                insideQuotes.toggle()
            case ",":
                if !insideQuotes {
                    columns.append(currentColumn)
                    currentColumn = ""
                } else {
                    currentColumn.append(char)
                }
            default:
                currentColumn.append(char)
            }
        }
        
        // Add the last column
        columns.append(currentColumn)
        
        return columns
    }
    
    private func cleanPrompt(_ prompt: String) -> String {
        // Remove surrounding quotes and extra whitespace
        var cleaned = prompt.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        return cleaned
    }
    
    func getRandomPrompt(for timeOfDay: TimeOfDay) -> String? {
        let prompts: [String]
        switch timeOfDay {
        case .morning:
            prompts = morningPrompts
        case .afternoon:
            prompts = afternoonPrompts
        case .night:
            prompts = nightPrompts
        }
        
        // Filter out used prompts
        let availablePrompts = prompts.filter { !usedPrompts.contains($0) }
        
        // If all prompts have been used, reset the used prompts
        if availablePrompts.isEmpty {
            usedPrompts.removeAll()
            return prompts.randomElement()
        }
        
        // Get a random prompt and mark it as used
        if let selectedPrompt = availablePrompts.randomElement() {
            usedPrompts.insert(selectedPrompt)
            return selectedPrompt
        }
        
        return nil
    }
    
    func resetUsedPrompts() {
        usedPrompts.removeAll()
    }
    
    // Get the number of remaining unused prompts for a specific time of day
    func remainingPrompts(for timeOfDay: TimeOfDay) -> Int {
        let prompts: [String]
        switch timeOfDay {
        case .morning:
            prompts = morningPrompts
        case .afternoon:
            prompts = afternoonPrompts
        case .night:
            prompts = nightPrompts
        }
        
        return prompts.filter { !usedPrompts.contains($0) }.count
    }
    
    // Test function to verify the prompt system
    func testPromptSystem() {
        print("\n=== Testing Prompt System ===")
        
        // Print total number of prompts loaded
        print("\nTotal prompts loaded:")
        print("Morning prompts: \(morningPrompts.count)")
        print("Afternoon prompts: \(afternoonPrompts.count)")
        print("Night prompts: \(nightPrompts.count)")
        
        // Test getting prompts for each time of day
        print("\nTesting random prompts for each time of day:")
        
        // Reset used prompts before testing
        resetUsedPrompts()
        
        // Test morning prompts
        print("\nMorning Prompts Test:")
        for _ in 1...3 {
            if let prompt = getRandomPrompt(for: .morning) {
                print("- \(prompt)")
            }
        }
        print("Remaining morning prompts: \(remainingPrompts(for: .morning))")
        
        // Test afternoon prompts
        print("\nAfternoon Prompts Test:")
        for _ in 1...3 {
            if let prompt = getRandomPrompt(for: .afternoon) {
                print("- \(prompt)")
            }
        }
        print("Remaining afternoon prompts: \(remainingPrompts(for: .afternoon))")
        
        // Test night prompts
        print("\nNight Prompts Test:")
        for _ in 1...3 {
            if let prompt = getRandomPrompt(for: .night) {
                print("- \(prompt)")
            }
        }
        print("Remaining night prompts: \(remainingPrompts(for: .night))")
        
        print("\n=== End of Test ===\n")
    }
} 