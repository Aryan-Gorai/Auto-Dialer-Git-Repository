// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_application_1/services/crud/crud_exceptions.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' show join;


//   class CallService{

//   Database? _db;



//   // same thing as notesStreamController, but for contacts
//   List<DatabaseContacts> _contact = [];

//   //SINGLETON
//   static final CallService _sharedC = CallService._sharedInstance();
//   CallService._sharedInstance(){
//     _contactsStreamController = StreamController<List<DatabaseContacts>>.broadcast(
//       onListen: () {
//         _contactsStreamController.sink.add(_contact);
//       },
//     );
//   }

//   factory CallService() => _sharedC;

//   late final StreamController<List<DatabaseContacts>> _contactsStreamController;
//   // stream controller part two for contacts
//   Stream<List<DatabaseContacts>>get allContacts =>  _contactsStreamController.stream;

//   Future<DatabaseUser> getOrCreateUser({required String email}) async {
//     await _ensureDbIsOpen();
//     try {
//       final user = await getUser(email: email);
//       return user;
//     } on CouldNotFindUser {
//       final createdUser = await createUser(email: email);
//       return createdUser;
//     } catch (e) {
//       rethrow;
//     }
    
//   }


// // database insert new contact ...
//   Future<DatabaseContacts> createContact({required DatabaseUser owner}) async {
//   await _ensureDbIsOpen();
//   final db = _getDatabaseOrThrow();

//   // make sure owner exists in the database with the correct id
//   final dbUser = await getUser(email: owner.email);
//   if (dbUser != owner) {
//     throw CouldNotFindUser();
//   }

//   // create the contact
//   final contactId = await db.insert(contactTable, {
//     userIdColumn: owner.id,
//     nameColumn: name,
//     phoneNumberColumn: phoneNumber,
//     isSyncedWithCloudColumn: 1
//   });

//   final contact = DatabaseContacts(
//     id: contactId,
//     userId: owner.id,
//     name: name,
//     phoneNumber: phoneNumber,
//     isSyncedWithCloud: true,
//   );

//   _contact.add(contact);
//   _contactsStreamController.add(_contact);

//   return contact;
// }

// // end insert new contacts block

// // Databse UpdateContacts

// Future<DatabaseContacts> updateContact({
//   required DatabaseContacts contact,
//   required String name,
//   required String phoneNumber,
// }) async {
//   await _ensureDbIsOpen();
//   final db = _getDatabaseOrThrow();

//   // make sure contact exists
//   await getContact(id: contact.id);

//   // update DB
//   final updatesCount = await db.update(contactTable, {
//     nameColumn: name,
//     phoneNumberColumn: phoneNumber,
//     isSyncedWithCloudColumn: 0,
//   });

//   if (updatesCount == 0) {
//     throw CouldNotUpdateContact();
//   } else {
//     final updatedContact = await getContact(id: contact.id);
//     _contact.removeWhere((contact) => contact.id == updatedContact.id);
//     _contact.add(updatedContact);
//     _contactsStreamController.add(_contact);
//     return updatedContact;
//   }
// }


// // end UpdateContacts


// // get contact

// Future<DatabaseContacts> getContact({required int id}) async {
//   await _ensureDbIsOpen();
//   final db = _getDatabaseOrThrow();
//   final contacts = await db.query(
//     contactTable, limit: 1, 
//     where: 'id = ?', 
//     whereArgs: [id],
//   );

//   if (contacts.isEmpty) {
//     throw CouldNotFindContact();
//   } else {
//     final contact = DatabaseContacts.fromRow(contacts.first);
//     _contact.removeWhere((c) => c.id == id);
//     _contact.add(contact);
//     _contactsStreamController.add(_contact);
//     return contact;
//   }
// }



// // end GetContact




// // database  delete contact


//   Future<void> deleteContact ({required int id}) async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();
//     final deletedCount = await db.delete(
//       contactTable,
//       where: 'id = ?',
//       whereArgs: [id],
//     );
//     if(deletedCount == 0) {
//       throw CouldNotDeleteContact();
//     } else {
//       _contact.removeWhere((contact) => contact.id == id);
//       _contactsStreamController.add(_contact);
//     }
//   }

// // end database delete contact


// // Database delete all contacts

//   Future<int> deleteAllContacts() async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();
//     final numberOfDeletions = await db.delete(contactTable);
//     _contact = [];
//     _contactsStreamController.add(_contact);
//     return numberOfDeletions;
//   }

// // end database delete all contacts


// // Database get all contacts

//   Future<Iterable<DatabaseContacts>> getAllContacts() async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();
//     final contact = await db.query(contactTable, limit: 1, );

//     return contact.map((contactRow) => DatabaseContacts.fromRow(contactRow));
//   }
// // End Database get all contacts

// // DATBASE CACHE CONTACTS

//   Future<void> _cacheContact() async{
//   await _ensureDbIsOpen();
//   final allContact = await getAllContacts();
//   _contact = allContact.toList();
//   _contactsStreamController.add(_contact);
//   }

// // DATBASE end CACHE CONTACTS

//   Future<DatabaseUser> getUser({required String email}) async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();

//       final results = await db.query(
//       userTable, limit: 1, 
//       where: 'email = ?', 
//       whereArgs: [email.toLowerCase()],
//     );

//     if (results.isEmpty) {
//       throw CouldNotFindUser();
//     } else {
//       return DatabaseUser.fromRow(results.first);
//     }
//   }

//   Future<DatabaseUser> createUser ({required String email}) async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();
//     final results = await db.query(
//       userTable, limit: 1, 
//       where: 'email = ?', 
//       whereArgs: [email.toLowerCase()],
//     );
//     if (results.isNotEmpty) {
//       throw UserAlreadyExists();
//     }

//     final userId = await db.insert(userTable,{
//       emailColumn: email.toLowerCase(),
//     });

//     return DatabaseUser(
//       id: userId, 
//       email: email,
//     );
//   }

//   Future<void> deleteUser({required String email}) async {
//     await _ensureDbIsOpen();
//     final db = _getDatabaseOrThrow();
//     final deletedCount = await db.delete(
//       userTable, where: 'email = ?', 
//       whereArgs: [email.toLowerCase()],
//     );
//     if (deletedCount != 1) {
//       throw CouldNotDeleteUser();
//     }
//   }

//   Database _getDatabaseOrThrow () {
//     final db = _db;
//     if (db == null) {
//       throw DatabaseIsNotOpen();
//     } else {
//       return db;
//     }
//   }

//   Future<void> close() async {
//   final db = _db;
//    if (db == null) {
//       throw DatabaseIsNotOpen();
//     } else {
//       await db.close();
//       _db = null;
//     }
//   }

//   Future<void> _ensureDbIsOpen() async{
//   try {
//     await open();
//   } on DatabaseAlreadyOpenException {
//     // empty
//   }
// }

//   Future<void> open() async {
//     if (_db != null) {
//       throw DatabaseAlreadyOpenException();
//     }
//     try {
//       final docsPath = await getApplicationDocumentsDirectory();
//       final dbPath = join(docsPath.path, dbName);
//       final db = await openDatabase(dbPath);
//       _db = db;

//       // create the user table
//       await db.execute(createUserTable);

//       // create the contact table
//       await db.execute(createContactsTable);
//       await _cacheContact();

//     } on MissingPlatformDirectoryException {
//       throw UnableToGetDocumentsDirectory();
//     }
//   }  
  







  
//   }

// @immutable
// class DatabaseUser {
//   final int id;
//   final String email;
//   const DatabaseUser ({ 
//     required this.id, 
//     required this.email, 
//     });

//   DatabaseUser.fromRow(Map<String, Object?> map) 
//   : id = map[idColumn] as int, 
//     email = map[emailColumn] as String;


//   @override
//   String toString() => 'Person, ID = $id, email = $email';

//   @override 
//   bool operator ==(covariant DatabaseUser other)  => id == other.id;
  
//   @override
//   int get hashCode => id.hashCode;
  

// } 



// // Class for contacts database

// class DatabaseContacts {
//   final int id;
//   final int userId;
//   final String name;
//   final String phoneNumber;
//   final bool isSyncedWithCloud;

//   DatabaseContacts({
//     required this.id, 
//     required this.userId,
//     required this.name, 
//     required this.phoneNumber, 
//     required this.isSyncedWithCloud,
//     });

//       DatabaseContacts.fromRow(Map<String, Object?> map) 
//     : id = map[idColumn] as int, 
//     userId = map[userIdColumn] as int,
//     name = map[nameColumn] as String,
//     phoneNumber = map[phoneNumberColumn] as String,
//     isSyncedWithCloud = 
//       (map[isSyncedWithCloudColumn] as int) == 1 ? true : false;


//   @override
//   String toString() => 
//     'Contact, ID = $id, name = $name, number = $phoneNumber, isSyncedWithCloud = $isSyncedWithCloud';

//   @override bool operator ==(covariant DatabaseContacts other)  => id == other.id;
  
//   @override
//   int get hashCode => id.hashCode;


// }




// const dbName = 'notes.db';
// const noteTable = 'note';
// const userTable = 'user';
// const idColumn = "id";
// const emailColumn = 'email';
// const userIdColumn = 'user_id';
// const textColumn = 'text';
// const isSyncedWithCloudColumn = 'is_synced_with_cloud';

// // constants for contacts database
// const contactTable = 'contact';
// const nameColumn = 'name';
// const phoneNumberColumn = 'phone_number';

// const String name = ''; 
// const String phoneNumber = '';
// // end constants for contacts database

// const createUserTable  = ''' CREATE TABLE IF NOT EXISTS "user" (
//   "id"	INTEGER NOT NULL,
//   "email"	TEXT UNIQUE,
//   PRIMARY KEY("id" AUTOINCREMENT)
//   );''';


// // constant creation of contacts database

// const createContactsTable =  '''CREATE TABLE IF NOT EXISTS "contacts" (
//       "id" INTEGER NOT NULL,
//       "name" TEXT,
//       "phone_number" TEXT,
//       "is_synced_with_cloud" INTEGER NOT NULL DEFAULT 0,
//       PRIMARY KEY("id"),
//       FOREIGN KEY("user_id") REFERENCES "user"("id")
//     );''';