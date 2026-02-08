// Immutable model for a single note stored in Firestore.
// Uses a factory constructor to parse a Firestore snapshot into
// a clean Dart object with documentId, ownerUserId and text fields.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/cloud/cloud_storage_constants.dart';
import 'package:flutter/foundation.dart';

@immutable
class CloudNote {
    final String documentId;
    final String ownerUserId;
    final String text;
    const CloudNote ({
        required this.documentId,
        required this.ownerUserId,
        required this.text,
    });

    // Pulls values out of a Firestore document snapshot using the constant field names
    CloudNote.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> snapshot) :
    documentId = snapshot.id,
    ownerUserId = snapshot.data()[ownerUserIdFieldName],
    text = snapshot.data() [textFieldName] as String;
}