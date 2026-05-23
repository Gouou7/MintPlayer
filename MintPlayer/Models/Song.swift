import Foundation

struct Song: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let path: String
    let coverPath: String?
    let genre: String?
    let year: Int?
    let librarySourceId: UUID?
    let dateAdded: Date
    let playCount: Int
    let lastPlayedAt: Date?
    let isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        path: String,
        coverPath: String? = nil,
        genre: String? = nil,
        year: Int? = nil,
        librarySourceId: UUID? = nil,
        dateAdded: Date = Date(),
        playCount: Int = 0,
        lastPlayedAt: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.path = path
        self.coverPath = coverPath
        self.genre = genre
        self.year = year
        self.librarySourceId = librarySourceId
        self.dateAdded = dateAdded
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
        self.isFavorite = isFavorite
    }
}

extension Song {
    func mergingPersistentFields(from existingSong: Song) -> Song {
        Song(
            id: existingSong.id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            path: path,
            coverPath: coverPath,
            genre: genre,
            year: year,
            librarySourceId: librarySourceId ?? existingSong.librarySourceId,
            dateAdded: existingSong.dateAdded,
            playCount: existingSong.playCount,
            lastPlayedAt: existingSong.lastPlayedAt,
            isFavorite: existingSong.isFavorite
        )
    }

    func recordingPlayback(at date: Date) -> Song {
        Song(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            path: path,
            coverPath: coverPath,
            genre: genre,
            year: year,
            librarySourceId: librarySourceId,
            dateAdded: dateAdded,
            playCount: playCount + 1,
            lastPlayedAt: date,
            isFavorite: isFavorite
        )
    }

    func assigningLibrarySource(_ sourceId: UUID?) -> Song {
        Song(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            path: path,
            coverPath: coverPath,
            genre: genre,
            year: year,
            librarySourceId: sourceId,
            dateAdded: dateAdded,
            playCount: playCount,
            lastPlayedAt: lastPlayedAt,
            isFavorite: isFavorite
        )
    }

    func settingFavorite(_ isFavorite: Bool) -> Song {
        Song(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            path: path,
            coverPath: coverPath,
            genre: genre,
            year: year,
            librarySourceId: librarySourceId,
            dateAdded: dateAdded,
            playCount: playCount,
            lastPlayedAt: lastPlayedAt,
            isFavorite: isFavorite
        )
    }
}
