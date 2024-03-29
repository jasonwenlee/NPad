//
//  Operations.swift
//  NPad
//
//  Created by Jason on 13/12/2023.
//

import CoreData
import Foundation

enum Operations: EntryProtocol {
    static let context = PersistenceController.shared.container.viewContext

    static func addEntry(title: String? = nil, description: String? = nil) -> TextEntry {
        let textEntry = TextEntry(context: context)
        textEntry.id = UUID()
        textEntry.entry_title = title
        textEntry.entry_description = description
        Log.log(message: "Adding entry \(textEntry.id?.uuidString ?? "")")
        _save()
        return textEntry
    }

    static func updateEntry(id: UUID, updatedTitle: String?, updatedDescription: String?) -> TextEntry? {
        let textEntry = fetchEntry(id: id)
        textEntry?.entry_title = updatedTitle
        textEntry?.entry_description = updatedDescription
        Log.log(message: "Updating entry \(id)")
        _save()
        return textEntry
    }

    static func deleteEntry(entry: TextEntry) {
        context.delete(entry)
        Log.log(message: "Deleting entry \(entry.id?.uuidString ?? "") from database")
        _save()
    }

    static func fetchEntry(id: UUID) -> TextEntry? {
        let request: NSFetchRequest<TextEntry> = TextEntry.fetchRequest()
        do {
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            let entry = try context.fetch(request).first
            Log.log(message: "Fetched entry \(id) from database")
            return entry
        } catch {
            return nil
        }
    }

    static func fetchEntries() -> [TextEntry] {
        let request: NSFetchRequest<TextEntry> = TextEntry.fetchRequest()
        do {
            let entries = try context.fetch(request)
            Log.log(message: "Fetched entries from database")
            return entries
        } catch {
            return []
        }
    }

    static func addAttachments(entryId: UUID? = nil, urls: [URL]) -> TextEntry? {
        guard let textEntry = entryId == nil ? addEntry() : fetchEntry(id: entryId!) else {
            Log.error(message: "Fail to add \(urls.count) attachments to entry \(entryId?.uuidString ?? "")")
            return nil
        }

        let attachments = urls.map { url in
            let attachment = Attachment(context: context)
            attachment.entry_id = entryId
            attachment.filePath = url.relativePathAsString()
            attachment.fileName = url.lastPathComponent
            attachment.fileType = url.pathExtension
            return attachment
        }

        let attachmentsToAdd = Set(attachments)
        textEntry.addToAttachments(attachmentsToAdd as NSSet)

        // Copy attachments to documents directory.
        let fileManager = FileManager.default
        urls.forEach { from in
            if let to = from.convertToDocumentDirectory() {
                let destinationDirectory = to.deletingLastPathComponent()

                // Check if the directory exists.
                do {
                    var isDirectory: ObjCBool = false
                    if !fileManager.fileExists(atPath: destinationDirectory.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
                        // If the directory doesn't exist, create it.
                        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true, attributes: nil)
                        Log.log(message: "Created directory")
                    }
                } catch {
                    Log.error(message: "Fail to create directory")
                }

                do {
                    // Check if file already exists.
                    if fileManager.fileExists(atPath: to.path()) {
                        Log.log(message: "File exists at path")
                        if fileManager.contentsEqual(atPath: from.path(), andPath: to.path()) {
                            Log.log(message: "Skip copying. Contents are the same")
                        } else {
                            do {
                                let result = try fileManager.replaceItemAt(to, withItemAt: from)
                                if result != nil {
                                    Log.log(message: "Replaced item with new contents")
                                }
                            } catch {
                                Log.error(message: "Faile to replace item with new contents")
                            }
                        }
                    } else {
                        try fileManager.copyItem(at: from, to: to)
                        Log.log(message: "Copied item to: \(to.path())")
                    }

                    _save()
                } catch {
                    Log.error(message: "Failed to create item at: \(to.path())")
                }
            }
        }

        return textEntry
    }

    static func _save() {
        if context.hasChanges {
            do {
                try context.save()
                Log.log(message: "Saved changes in database")
            } catch {
                let nsError = error as NSError
                Log.error(message: "Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
