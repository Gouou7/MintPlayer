import Foundation
import CoreFoundation

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: TimeInterval
    let rawTime: String
    let text: String
}

enum LyricsLoadState {
    case loading
    case missing(URL)
    case failed(String)
    case plainText([String])
    case synced([LyricLine])
}

enum LyricsTextEncoding: String, CaseIterable {
    case automatic, utf8, utf16, gb18030, big5

    var titleKey: L10n.Key {
        switch self {
        case .automatic: return .automaticEncoding
        case .utf8: return .utf8Encoding
        case .utf16: return .utf16Encoding
        case .gb18030: return .gb18030Encoding
        case .big5: return .big5Encoding
        }
    }

    var stringEncoding: String.Encoding? {
        switch self {
        case .automatic: return nil
        case .utf8: return .utf8
        case .utf16: return .utf16
        case .gb18030:
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            ))
        case .big5:
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.big5.rawValue)
            ))
        }
    }
}

enum LyricsService {
    static func loadLyrics(for song: Song, fileURL: URL? = nil, timingOffset: TimeInterval = 0, encoding: LyricsTextEncoding = .automatic) -> LyricsLoadState {
        let lyricsURL = fileURL ?? lyricsURL(for: song)
        guard FileManager.default.fileExists(atPath: lyricsURL.path) else {
            return fileURL == nil ? .missing(lyricsURL) : .failed(L10n.current(.selectedLyricsMissing, lyricsURL.lastPathComponent))
        }
        
        do {
            let data = try Data(contentsOf: lyricsURL)
            let decoded: String?
            if let explicitEncoding = encoding.stringEncoding {
                decoded = String(data: data, encoding: explicitEncoding)
            } else {
                decoded = string(from: data)
            }
            guard let content = decoded else {
                return .failed(L10n.current(.lyricsEncodingFailed))
            }
            
            return parse(content, timingOffset: timingOffset)
        } catch {
            return .failed(L10n.current(.lyricsFileReadFailed, error.localizedDescription))
        }
    }
    
    static func lyricsURL(for song: Song) -> URL {
        URL(fileURLWithPath: song.path)
            .deletingPathExtension()
            .appendingPathExtension("lrc")
    }
    
    private static func string(from data: Data) -> String? {
        let bytes = Array(data.prefix(4))
        if bytes.starts(with: [0xFF, 0xFE, 0x00, 0x00]) || bytes.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            return String(data: data, encoding: .utf32)
        }
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }
        // LRC timestamps begin with ASCII, which also identifies BOM-less UTF-16 byte order.
        if bytes.count >= 2, data.count.isMultiple(of: 2) {
            if bytes[0] == 0 { return String(data: data, encoding: .utf16BigEndian) }
            if bytes[1] == 0 { return String(data: data, encoding: .utf16LittleEndian) }
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        let encodings = [LyricsTextEncoding.gb18030, .big5].compactMap(\.stringEncoding)
            + [String.Encoding.windowsCP1252, .isoLatin1]
        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        return nil
    }

    private static func parse(_ content: String, timingOffset: TimeInterval) -> LyricsLoadState {
        let lines = content.replacingOccurrences(of: "\u{FEFF}", with: "").components(separatedBy: .newlines)
        let offsetRegex = try? NSRegularExpression(pattern: #"^\[offset\s*:\s*([+-]?\d+)\s*\]$"#, options: .caseInsensitive)
        var fileOffset: TimeInterval = 0
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = offsetRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line), let value = Double(line[range]), value.isFinite {
                fileOffset = value / 1000
            }
        }
        let timestampPattern = #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
        guard let timestampRegex = try? NSRegularExpression(pattern: timestampPattern) else {
            return .failed(L10n.current(.lyricsParsingFailed))
        }
        
        var syncedLines: [(line: LyricLine, sourceIndex: Int)] = []
        var plainLines: [String] = []
        
        for (lineIndex, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = timestampRegex.matches(in: line, range: nsRange)
            
            if matches.isEmpty {
                if !isMetadataLine(line) {
                    plainLines.append(line)
                }
                continue
            }
            
            let text = timestampRegex
                .stringByReplacingMatches(in: line, range: nsRange, withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !text.isEmpty else { continue }
            
            for match in matches {
                guard
                    let time = timeInterval(from: match, in: line),
                    let rawTimeRange = Range(match.range(at: 0), in: line)
                else {
                    continue
                }
                
                let rawTime = String(line[rawTimeRange])
                syncedLines.append((LyricLine(time: time - fileOffset + timingOffset, rawTime: rawTime, text: text), lineIndex))
            }
        }
        
        if !syncedLines.isEmpty {
            let sortedLines = syncedLines
                .sorted {
                    if $0.line.time == $1.line.time {
                        return $0.sourceIndex < $1.sourceIndex
                    }
                    return $0.line.time < $1.line.time
                }
                .map(\.line)
            return .synced(sortedLines)
        }
        
        if !plainLines.isEmpty {
            return .plainText(plainLines)
        }
        
        return .plainText([])
    }
    
    private static func timeInterval(from match: NSTextCheckingResult, in line: String) -> TimeInterval? {
        guard
            let minuteRange = Range(match.range(at: 1), in: line),
            let secondRange = Range(match.range(at: 2), in: line),
            let minutes = TimeInterval(line[minuteRange]),
            let seconds = TimeInterval(line[secondRange])
        else {
            return nil
        }
        
        var fraction: TimeInterval = 0
        if let fractionRange = Range(match.range(at: 3), in: line) {
            let fractionText = String(line[fractionRange])
            if let fractionValue = TimeInterval(fractionText) {
                fraction = fractionValue / pow(10, TimeInterval(fractionText.count))
            }
        }
        
        return minutes * 60 + seconds + fraction
    }
    
    private static func isMetadataLine(_ line: String) -> Bool {
        line.hasPrefix("[") && line.hasSuffix("]") && line.contains(":")
    }
}
