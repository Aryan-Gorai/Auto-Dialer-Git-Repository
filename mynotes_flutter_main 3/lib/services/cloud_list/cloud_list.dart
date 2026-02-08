// Immutable model for a contact list entry stored in Firestore.
// Similar to CloudNote but represents a contact/list item instead of a text note.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/services/cloud_list/cloud_storage_constants.dart';



@immutable
class CloudList {
    final String documentId;
    final String ownerUserId;
    final String contact_name;
    
    const CloudList ({
        required this.documentId,
        required this.ownerUserId,
        required this.contact_name,
    });

    // Builds a CloudList from a raw Firestore document snapshot
    CloudList.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> snapshot) :
    documentId = snapshot.id,
    ownerUserId = snapshot.data()[ownerUserIdFieldName],
    contact_name = snapshot.data() [contact_nameFieldName] as String;
    
}