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

    CloudList.fromSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> snapshot) :
    documentId = snapshot.id,
    ownerUserId = snapshot.data()[ownerUserIdFieldName],
    contact_name = snapshot.data() [contact_nameFieldName] as String;
    
}