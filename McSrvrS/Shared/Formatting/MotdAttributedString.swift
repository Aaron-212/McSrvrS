import SwiftUI

extension String {
    func trimmingWhitespace() -> String {
        self
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
    }

    func trimmingFormatCodes() -> String {
        self.replacingOccurrences(
            of: "§[0-9a-flmnork]",
            with: "",
            options: .regularExpression
        )
    }

}

extension ServerStatus.StatusData {
    func parseMotd(skipColor: Bool = false, trimWhitespace: Bool = false) -> AttributedString? {
        guard let motd = self.motd else { return nil }

        var attributedString = AttributedString()
        var currentText = ""
        var currentAttributes = AttributeContainer()

        // Set default white color for text without color codes
        if !skipColor {
            currentAttributes.foregroundColor = .white
        }

        let characters = Array(trimWhitespace ? motd.trimmingWhitespace() : motd)
        var i = 0

        // Helper function to apply current text with attributes
        func flushCurrentText() {
            if !currentText.isEmpty {
                var textPart = AttributedString(currentText)
                textPart.mergeAttributes(currentAttributes)
                attributedString.append(textPart)
                currentText = ""
            }
        }

        // Color mapping
        func getColor(for code: Character) -> Color? {
            switch code {
            case "0": return .black
            case "1": return Color(red: 0.0, green: 0.0, blue: 0.67)  // Dark Blue
            case "2": return Color(red: 0.0, green: 0.67, blue: 0.0)  // Dark Green
            case "3": return Color(red: 0.0, green: 0.67, blue: 0.67)  // Dark Aqua
            case "4": return Color(red: 0.67, green: 0.0, blue: 0.0)  // Dark Red
            case "5": return Color(red: 0.67, green: 0.0, blue: 0.67)  // Dark Purple
            case "6": return Color(red: 1.0, green: 0.67, blue: 0.0)  // Gold
            case "7": return Color(red: 0.67, green: 0.67, blue: 0.67)  // Gray
            case "8": return Color(red: 0.33, green: 0.33, blue: 0.33)  // Dark Gray
            case "9": return Color(red: 0.33, green: 0.33, blue: 1.0)  // Blue
            case "a": return Color(red: 0.33, green: 1.0, blue: 0.33)  // Green
            case "b": return Color(red: 0.33, green: 1.0, blue: 1.0)  // Aqua
            case "c": return Color(red: 1.0, green: 0.33, blue: 0.33)  // Red
            case "d": return Color(red: 1.0, green: 0.33, blue: 1.0)  // Light Purple
            case "e": return Color(red: 1.0, green: 1.0, blue: 0.33)  // Yellow
            case "f": return .white
            default: return .white
            }
        }

        while i < characters.count {
            let char = characters[i]

            if char == "§" && i + 1 < characters.count {
                // Found a format code
                let formatCode = characters[i + 1]

                // Flush current text before applying new formatting
                flushCurrentText()

                switch formatCode {
                case "0"..."9", "a"..."f":
                    // Color code - reset styles and apply color
                    currentAttributes = AttributeContainer()
                    if let color = getColor(for: formatCode), !skipColor {
                        currentAttributes.foregroundColor = color
                    }

                case "l":
                    // Bold
                    currentAttributes.inlinePresentationIntent = .stronglyEmphasized

                case "m":
                    // Strikethrough
                    currentAttributes.strikethroughStyle = .single

                case "n":
                    // Underline
                    currentAttributes.underlineStyle = .single

                case "o":
                    // Italic
                    currentAttributes.inlinePresentationIntent = .emphasized

                case "r":
                    // Reset all formatting
                    currentAttributes = AttributeContainer()
                    // Set default white color after reset
                    if !skipColor {
                        currentAttributes.foregroundColor = .white
                    }

                case "k":
                    // Obfuscated - skip for now as requested
                    break

                default:
                    // Unknown format code, treat as regular text
                    currentText.append(char)
                    i += 1
                    continue
                }

                // Skip the format code characters
                i += 2
            } else {
                // Regular character
                currentText.append(char)
                i += 1
            }
        }

        // Don't forget to flush any remaining text
        flushCurrentText()

        return attributedString
    }
}
