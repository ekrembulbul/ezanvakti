import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Paints a finite, non-lazy widget in an independent render tree.
class WidgetImageRenderer {
  static Future<Uint8List> render({
    required BuildContext context,
    required Widget child,
  }) async {
    const size = Size(1000, 10000);
    final boundary = RenderRepaintBoundary();
    final position = RenderPositionedBox(
      alignment: Alignment.topLeft,
      child: boundary,
    );
    final pipeline = PipelineOwner();
    final focus = FocusManager();
    final owner = BuildOwner(focusManager: focus);
    final view = RenderView(
      view: View.of(context),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size),
      ),
      child: position,
    );
    pipeline.rootNode = view;
    view.prepareInitialFrame();
    final root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: InheritedTheme.captureAll(
        context,
        MediaQuery(
          data: const MediaQueryData(
            size: size,
            textScaler: TextScaler.noScaling,
          ),
          child: Localizations.override(
            context: context,
            child: Directionality(
              textDirection: Directionality.of(context),
              child: SizedBox(width: size.width, child: child),
            ),
          ),
        ),
      ),
    ).attachToRenderTree(owner);
    ui.Image? image;
    try {
      owner.buildScope(root);
      owner.finalizeTree();
      pipeline.flushLayout();
      pipeline.flushCompositingBits();
      pipeline.flushPaint();
      image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG encoding failed');
      return data.buffer.asUint8List();
    } finally {
      image?.dispose();
      RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
      ).attachToRenderTree(owner, root);
      owner.buildScope(root);
      owner.finalizeTree();
      pipeline.rootNode = null;
      view.child = null;
      position.child = null;
      boundary.dispose();
      position.dispose();
      view.dispose();
      pipeline.dispose();
      focus.dispose();
    }
  }
}
