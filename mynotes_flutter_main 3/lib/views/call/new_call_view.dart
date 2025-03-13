// import 'package:flutter/material.dart';
// import 'package:flutter_application_1/services/auth/auth_service.dart';
// import 'package:flutter_application_1/services/crud/call_service.dart';

// class NewCallView extends StatefulWidget {
//   const NewCallView({super.key});

//   @override
//   State<NewCallView> createState() => _NewCallViewState();
// }

// class _NewCallViewState extends State<NewCallView> {
//   DatabaseContacts? _contact;
//   late final CallService _contactsService;
//   late final TextEditingController _textController;

//   @override void initState() {
//     _contactsService = CallService();
//     _textController = TextEditingController();
//     super.initState();
//   }

//     void _textControllerListener() async {
//     final contact = _contact;
//     if (contact == null) {
//       return;
//     }
//     final text = _textController.text;
//     await _contactsService.updateContact(
//       contact: contact, 
//       name: name, 
//       phoneNumber: phoneNumber);
//   }

//   void _setupTextControllerListener() {
//     _textController.removeListener(_textControllerListener);
//     _textController.addListener(_textControllerListener);
//   }

//   Future<DatabaseContacts> createNewContact() async {
//     final existingContact = _contact;
//     if (existingContact != null) {
//       return existingContact;
//     }
//     final currentUser = AuthService.firebase().currentUser!;
//     final email = currentUser.email!;
//     final owner = await _contactsService.getUser(email: email);
//     return await _contactsService.createContact(owner: owner);    
//   }

//  void _deleteContactIfTextIsEmpty() {
//     final contact = _contact;
//     if (_textController.text.isEmpty && contact != null) {
//       _contactsService.deleteContact(id: contact.id);
//     }
//   }

//   void _saveContactIfTextNotEmpty() async {
//     final contact = _contact;
//     final text = _textController.text;
//     if (contact != null && text.isNotEmpty) {
//       await _contactsService.updateContact(
//         contact: contact, name: '', 
//         phoneNumber: ''
        
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _deleteContactIfTextIsEmpty();
//     _saveContactIfTextNotEmpty();
//     _textController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold (
//       appBar:  AppBar(
//         title: const Text ('New call')
//       ),
//       body: FutureBuilder(
//       future: createNewContact(),
//       builder:(context, snapshot) {
//         switch (snapshot.connectionState) {
//           case ConnectionState.done:
//             _contact = snapshot.data as DatabaseContacts?;
//             _setupTextControllerListener();
//             return TextField(
//               controller: _textController,
//               keyboardType: TextInputType.multiline,
//               maxLines: null,
//               decoration: const InputDecoration(
//                 hintText: 'Start typing your contact...',
//               ),
//             );
//           default:
//             return const CircularProgressIndicator();
//         }
//       },
//     ),
//     );
//   }
// }
  