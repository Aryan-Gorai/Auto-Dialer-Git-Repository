// Full-screen loading overlay that dims the background and shows a spinner
// with a text message. Uses a singleton pattern so any part of the app can
// call LoadingScreen().show() or .hide() without creating a new instance.
// The overlay is built with Flutter's Overlay API and updates its text
// via a StreamController so we don't have to tear it down and rebuild.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/helpers/loading/loading_screen_controller.dart';
import 'package:flutter_application_1/theme/components/app_components.dart';

class LoadingScreen {
  factory LoadingScreen() => _shared;
  static final LoadingScreen _shared = LoadingScreen._sharedInstance();
  LoadingScreen._sharedInstance();

  LoadingScreenController? controller;

  // If the overlay is already showing, just update the text; otherwise create it
  void show({
    required BuildContext context,
    required String text,
  }) {
    if (controller?.update(text) ?? false) {
      return;
    } else {
      controller = showOverlay(
        context: context,
        text: text,
      );
    }
  }

  // Tears down the overlay and resets the controller
  void hide() {
    controller?.close();
    controller = null;
  }

  LoadingScreenController showOverlay({
    required BuildContext context,
    required String text,
  }) {
    final _text = StreamController<String>();
    _text.add(text);

    final state = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    final overlay = OverlayEntry(
      builder: (context) {
        return Material(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: Container(
                constraints: BoxConstraints(
                  maxWidth: size.width * 0.8,
                  maxHeight: size.height * 0.8,
                  minWidth: size.width * 0.5,
                ),
                decoration: BoxDecoration(
                  color: AppDesignTokens.surface,
                  borderRadius: BorderRadius.circular(AppDesignTokens.radiusLg),
                  boxShadow: AppDesignTokens.elevatedShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 10),
                        const CircularProgressIndicator(color: AppDesignTokens.primary),
                        const SizedBox(height: 20),
                        StreamBuilder(
                          stream: _text.stream,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                snapshot.data as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppDesignTokens.neutral900),
                              );
                            } else {
                              return Container();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                )),
          ),
        );
      },
    );

    state.insert(overlay);

    return LoadingScreenController(
      close: () {
        _text.close();
        overlay.remove();
        return true;
      },
      update: (text) {
        _text.add(text);
        return true;
      },
    );
  }
}