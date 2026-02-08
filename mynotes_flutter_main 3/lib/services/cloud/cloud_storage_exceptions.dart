// Exception hierarchy for Firestore CRUD operations on notes.
// Mirrors the four standard database operations so each failure
// type can be handled separately in the UI.

class CloudStorageException implements Exception{
    const CloudStorageException();
}

// C in CRUD
class CouldNotCreateNoteException extends CloudStorageException {}

// R in CRUD
class CouldNotGetAllNotesExceotion extends CloudStorageException {}

// U in CRUD
class CouldNotUpdateNoteException extends CloudStorageException{}

// D in CRUD
class CouldNotDeleteNoteException extends CloudStorageException{}