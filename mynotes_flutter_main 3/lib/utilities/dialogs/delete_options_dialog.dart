import 'package:flutter/material.dart';
import 'package:flutter_application_1/utilities/dialogs/generic_dialog.dart';
import 'package:flutter_application_1/views/list/list_view.dart';

bool clicked = false;

Future<bool> showDeleteListViewDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Delete"),
        content: const Text("Choose the relevant option from below"),
        actions: [
          TextButton(
            onPressed: () {

            DeleteAllListsButtonFunction();
        


              Navigator.of(context).pop(false);
              clicked = true;
              

            }, child: const Text ("Delete all Lists"),
          ),
          TextButton(
            onPressed: () async{




              DeleteAllContactsButtonFunction();
              Navigator.of(context).pop(true);
            }, child: const Text ("Delete all Contacts"),
          ),
          TextButton(
            onPressed: () {


              DeleteAllContactsFromListButtonFunction();
              Navigator.of(context).pop(true);
            }, child: const Text ("Delete all Contacts from Selected List"),
          ),
        ]
      );
    }
  ).then((value) => value ?? false);
}
