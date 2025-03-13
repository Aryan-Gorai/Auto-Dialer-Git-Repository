import 'package:flutter/material.dart';
import 'package:flutter_application_1/utilities/dialogs/generic_dialog.dart';

Future<bool> showWelcomeDialog(BuildContext context) {
  return showGenericDialog<bool>(
    context: context,
    title: 'Welcome!',
    content: 'Please select a list from the drop down at the top before continuing...',
    optionsBuilder: () => {
      'Ok': null,
    },
  ).then(
    (value) => value ?? false,
  );
}

