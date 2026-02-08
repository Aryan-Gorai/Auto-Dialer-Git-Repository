// Singleton service that handles all Firestore CRUD for the 'notes' collection.
// Uses the singleton pattern (_shared instance) so we never create multiple
// listeners or connections to the same collection.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/cloud/cloud_note.dart';
import 'package:flutter_application_1/services/cloud/cloud_storage_constants.dart';
import 'package:flutter_application_1/services/cloud/cloud_storage_exceptions.dart';

class FirebaseCloudStorage {

    // Reference to the top-level 'notes' collection in Firestore
    final notes = FirebaseFirestore.instance.collection('notes');

    // Deletes a single note document by its Firestore ID
    Future<void> deleteNote({required String documentId}) async{
        try{
            notes.doc(documentId).delete();

        } catch (e) {
            throw CouldNotDeleteNoteException();
        }
    }

    // Updates the text content of an existing note
    Future<void> updateNote ({
        required String documentId,
        required String text,
    }) async {
        try {
            await notes.doc(documentId).update({textFieldName: text});
        } catch (e) {
            throw CouldNotUpdateNoteException();
        }
    }

    // Returns a real-time stream of all notes belonging to a specific user.
    // The stream fires every time the 'notes' collection changes.
    Stream<Iterable<CloudNote>> allNotes({required String ownerUserId}) =>
    notes.snapshots().map((event) => event.docs
    .map((doc)=> CloudNote.fromSnapshot(doc))
    .where((note) => note.ownerUserId == ownerUserId));

    // One-shot fetch of all notes for a user (used when you don't need live updates)
    Future<Iterable<CloudNote>> getNotes({required String ownerUserId}) async {
        try {
            return await notes.where(
                ownerUserIdFieldName,
                isEqualTo: ownerUserId,
            )
            .get()
            .then(
                (value) => value.docs.map(
                (doc) => CloudNote.fromSnapshot(doc)),
            );

        } catch(e) {
            throw CouldNotGetAllNotesExceotion();
        }
    }

    // Creates a blank note in Firestore and returns the new CloudNote object
    Future<CloudNote> createNewNote ({required String ownerUserId}) async {
        final document = await notes.add({
            ownerUserIdFieldName: ownerUserId,
            textFieldName: '',
        });

        final fetchedNote=await document.get();
        return CloudNote(
            documentId: fetchedNote.id,
            ownerUserId: ownerUserId,
            text: '',
        );
    }

    // Singleton plumbing — ensures only one instance of this service exists
    static final FirebaseCloudStorage _shared = FirebaseCloudStorage._sharedInstance();
    FirebaseCloudStorage._sharedInstance();
    factory FirebaseCloudStorage() => _shared;
}