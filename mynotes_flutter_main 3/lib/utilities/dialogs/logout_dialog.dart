// Confirmation dialog for logging out. Returns true if the user taps
// "Log Out", false if they cancel.

import 'package:flutter/material.dart';


// Future<bool> showLogOutDialog(BuildContext context) {
//   return showGenericDialog<bool>(
//     context: context,
//     title: 'Log out',
//     content: 'Are you sure you want to log out?',
//     optionsBuilder: () => {
//       'Cancel': false,
//       'Log out': true,
//     },
//   ).then(
//     (value) => value ?? false,
//   );
// }


Future<bool> showLogOutDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            }, child: const Text ("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            }, child: const Text ("Log Out"),
          ),
        ]
      );
    }
  ).then((value) => value ?? false);
}