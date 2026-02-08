// Tiny controller that holds two callbacks: one to close the loading overlay
// and one to update its text. Used by LoadingScreen to manage the overlay.

import 'package:flutter/foundation.dart';

typedef CloseLoadingScreen = bool Function();
typedef UpdateLoadingScreen = bool Function(String text);

@immutable
class LoadingScreenController {
  final CloseLoadingScreen close;
  final UpdateLoadingScreen update;

  const LoadingScreenController({
    required this.close, 
  required this.update,
  });

}