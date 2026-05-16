import Foundation

extension Song {
    var displayGenre: String {
        if let genre, !genre.isEmpty {
            return genre
        }
        
        return "Unknown Genre"
    }
    
    var fileType: String {
        URL(fileURLWithPath: path).pathExtension.uppercased()
    }
}
