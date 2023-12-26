import Foundation
import AppKit

// Extensions for log file appending
extension String {
    func appendLineToURL(fileURL: URL) throws {
        try (self + "\n").appendToURL(fileURL: fileURL)
    }

    func appendToURL(fileURL: URL) throws {
        let data = self.data(using: String.Encoding.utf8)!
        try data.append(fileURL: fileURL)
    }
}

extension Data {
    func append(fileURL: URL) throws {
        if let fileHandle = FileHandle(forWritingAtPath: fileURL.path) {
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
                fileHandle.write(self)
        }
        else {
            try write(to: fileURL, options: .atomic)
        }
    }
}

let logFileURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("linker.log")
try? "-----".appendLineToURL(fileURL: logFileURL)

let startTime = Date()

// Access the URL from the system clipboard
let clipboard = NSPasteboard.general
guard let urlString = clipboard.string(forType: .string),
let linkURL = URL(string: urlString),
linkURL.scheme != nil else {
    try? "Invalid URL on clipboard, exiting".appendLineToURL(fileURL: logFileURL)
    // Exit the script if clipboard content is not a valid URL
    exit(0)
}

// Read RTF data from standard input
let rtfData = FileHandle.standardInput.readDataToEndOfFile()
let rtfString = String(data: rtfData, encoding: .utf8)

// Validate if the input is in RTF format
guard let unwrappedRtfString = rtfString, unwrappedRtfString.contains("{\\rtf") else {
    try? "Invalid RTF data input, exiting".appendLineToURL(fileURL: logFileURL)
    // Exit the script if input is not in RTF format
    exit(0)
}

// Create an attributed string from RTF data
let attributedString = try NSAttributedString(data: Data(unwrappedRtfString.utf8), options: [:], documentAttributes: nil)

// Add a link attribute to the entire attributed string
let linkedString = NSMutableAttributedString(attributedString: attributedString)
linkedString.addAttribute(.link, value: linkURL, range: NSRange(location: 0, length: linkedString.length))

// Convert the modified attributed string back to RTF data
if let modifiedRTFData = try? linkedString.data(from: NSRange(location: 0, length: linkedString.length), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.rtf]) {
    // Write the modified RTF data to standard output
    FileHandle.standardOutput.write(modifiedRTFData)

    // Calculate elapsed time in milliseconds
    let endTime = Date()
    let elapsedTime = endTime.timeIntervalSince(startTime) * 1000

    // Append the elapsed time to the log file
    let logEntry = String(format: "Elapsed time: %.2f ms", elapsedTime)
    try? logEntry.appendLineToURL(fileURL: logFileURL)
} else {
    try? "Failed to convert attributed string to RTF data, exiting".appendLineToURL(fileURL: logFileURL)
    // Exit the script if conversion fails
    exit(0)
}
