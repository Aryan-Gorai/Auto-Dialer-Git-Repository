// Shows a simple error dialog with an OK button. Wraps generic_dialog
// so every error popup in the app looks the same.

import 'package:flutter/material.dart';
import 'package:flutter_application_1/utilities/dialogs/generic_dialog.dart';

Future<void> showErrorDialog(
  BuildContext context,
  String text,
) {
  return showGenericDialog<void>(
    context: context,
    title: 'An error occurred',
    content: text,
    optionsBuilder: () => {
      'OK': null,
    },
  );
}
