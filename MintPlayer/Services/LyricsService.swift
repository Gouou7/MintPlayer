import Foundation

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: TimeInterval
    let rawTime: String
    let text: String
}

enum LyricsLoadState {
    case missing(URL)
    case failed(String)
    case plainText([String])
    case synced([LyricLine])
}

enum LyricsService {
    static func loadLyrics(for song: Song) -> LyricsLoadState {
        let lyricsURL = lyricsURL(for: song)
        guard FileManager.default.fileExists(atPath: lyricsURL.path) else {
            return .missing(lyricsURL)
        }
        
        do {
            let data = try Data(contentsOf: lyricsURL)
            guard let content = string(from: data) else {
                return .failed("无法读取歌词文件编码")
            }
            
            return parse(content)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
    
    static func lyricsURL(for song: Song) -> URL {
        URL(fileURLWithPath: song.path)
            .deletingPathExtension()
            .appendingPathExtension("lrc")
    }
    
    private static func string(from data: Data) -> String? {
        let encodings: [String.Encoding] = [.utf8, .unicode, .utf16, .utf16LittleEndian, .utf16BigEndian, .isoLatin1]
        for encoding in encodings {
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }
        return nil
    }
    
    private static func parse(_ content: String) -> LyricsLoadState {
        let lines = content.components(separatedBy: .newlines)
        let timestampPattern = #"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"#
        guard let timestampRegex = try? NSRegularExpression(pattern: timestampPattern) else {
            return .failed("歌词时间轴解析失败")
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
                syncedLines.append((LyricLine(time: time, rawTime: rawTime, text: text), lineIndex))
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
