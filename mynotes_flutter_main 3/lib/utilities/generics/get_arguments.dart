// Extension on BuildContext that pulls route arguments out in a type-safe way.
// Saves us from repeating the ModalRoute.of(context) boilerplate everywhere.

import 'package:flutter/material.dart' ;

extension GetArgument on BuildContext {
  T? getArgument<T>() {
    final modalRoute = ModalRoute.of(this);
    if (modalRoute != null) {
      final args = modalRoute.settings.arguments;
      if (args != null && args is T) {
        return args as T;
      }
    }
    return null;
  }
}
