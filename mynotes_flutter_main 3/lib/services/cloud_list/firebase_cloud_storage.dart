// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_application_1/services/cloud_list/cloud_storage_constants.dart';
// import 'package:flutter/foundation.dart';

// class FirebaseCloudStorage {



















// Future<CloudList> createNewList ({required String ownerUserId}) async {
//         final document = await list.add({
//             ownerUserIdFieldName: ownerUserId,
//             contact_nameFieldName: '',
//         });

//         final fetchedList=await document.get();
//         return CloudList(
//             documentId: fetchedNote.id,
//             ownerUserId: ownerUserId,
//             contact_nameFieldName: '',
//         );
//     }



//     static final FirebaseCloudStorage _shared = FirebaseCloudStorage._sharedInstance();
//     FirebaseCloudStorage._sharedInstance();
//     factory FirebaseCloudStorage() => _shared;


// }