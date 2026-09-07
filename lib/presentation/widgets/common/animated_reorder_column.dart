import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const _moveDuration = Duration(milliseconds: 360);

/// Key'li çocukları yeniden oluşturmadan yeni sıralarına kaydırır.
/// Değişken satır yükseklikleri ve hareket sırasındaki dokunmalar desteklenir.
class AnimatedReorderColumn extends StatefulWidget {
  final List<Widget> children;

  const AnimatedReorderColumn({super.key, required this.children});

  @override
  State<AnimatedReorderColumn> createState() => _AnimatedReorderColumnState();
}

class _AnimatedReorderColumnState extends State<AnimatedReorderColumn>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _moveDuration,
    value: 1,
  );
  late final _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  late List<Key?> _keys;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _keys = widget.children.map((child) => child.key).toList();
  }

  @override
  void didUpdateWidget(covariant AnimatedReorderColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keys = widget.children.map((child) => child.key).toList();
    if (!listEquals(_keys, keys)) {
      _controller.stop();
      _revision++;
      _keys = keys;
    }
  }

  void _startAnimation() => _controller.forward(from: 0);

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _MovingColumn(
    animation: _animation,
    revision: _revision,
    animate: !MediaQuery.disableAnimationsOf(context),
    onMove: _startAnimation,
    children: widget.children,
  );
}

class _MovingColumn extends MultiChildRenderObjectWidget {
  final Animation<double> animation;
  final int revision;
  final bool animate;
  final VoidCallback onMove;

  const _MovingColumn({
    required this.animation,
    required this.revision,
    required this.animate,
    required this.onMove,
    required super.children,
  });

  @override
  _RenderMovingColumn createRenderObject(BuildContext context) =>
      _RenderMovingColumn(
        animation: animation,
        revision: revision,
        animate: animate,
        onMove: onMove,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMovingColumn renderObject,
  ) {
    renderObject
      ..animation = animation
      ..revision = revision
      ..animate = animate
      ..onMove = onMove;
  }
}

class _MovingParentData extends FlexParentData {
  Offset begin = Offset.zero;
  bool hasPosition = false;
}

class _RenderMovingColumn extends RenderFlex {
  Animation<double> _animation;
  int _revision;
  bool _animate;
  VoidCallback onMove;
  bool _pendingMove = false;
  bool _moving = false;
  bool _hasLayout = false;
  double _beginHeight = 0;
  double _lastProgress = 1;

  _RenderMovingColumn({
    required Animation<double> animation,
    required int revision,
    required bool animate,
    required this.onMove,
  }) : _animation = animation,
       _revision = revision,
       _animate = animate,
       super(
         direction: Axis.vertical,
         mainAxisSize: MainAxisSize.min,
         crossAxisAlignment: CrossAxisAlignment.stretch,
       );

  set animation(Animation<double> value) {
    if (value == _animation) return;
    if (attached) _animation.removeListener(_tick);
    _animation = value;
    if (attached) _animation.addListener(_tick);
  }

  set revision(int value) {
    if (_revision == value) return;
    _revision = value;
    _pendingMove = true;
    markNeedsLayout();
  }

  set animate(bool value) {
    if (_animate == value) return;
    _animate = value;
    if (!value) _moving = false;
    markNeedsLayout();
  }

  void _tick() {
    if (_moving && _lastProgress != _animation.value) markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(_tick);
  }

  @override
  void detach() {
    _animation.removeListener(_tick);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MovingParentData) {
      child.parentData = _MovingParentData();
    }
  }

  @override
  void performLayout() {
    _lastProgress = _animation.value;
    final restart = _pendingMove && _animate && _hasLayout;
    final previous = <RenderBox, Offset>{};
    if (restart) {
      _beginHeight = size.height;
      for (var child = firstChild; child != null; child = childAfter(child)) {
        final data = child.parentData! as _MovingParentData;
        if (data.hasPosition) previous[child] = data.offset;
      }
    }

    super.performLayout();
    if (restart) {
      _moving = true;
      // forward aynı layout içinde listener çağırır; mevcut layout yeniden
      // dirty olmasın. İlk paint eski konumları koruyarak başlar.
      _lastProgress = 0;
      onMove();
    }
    _pendingMove = false;
    final progress = _animation.value;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final data = child.parentData! as _MovingParentData;
      if (restart) data.begin = previous[child] ?? data.offset;
      if (_moving && _animate) {
        data.offset = Offset.lerp(data.begin, data.offset, progress)!;
      }
      data.hasPosition = true;
    }
    if (_moving && _animate) {
      size = constraints.constrain(
        Size(
          size.width,
          _beginHeight + (size.height - _beginHeight) * progress,
        ),
      );
      if (progress == 1) _moving = false;
    }
    _hasLayout = true;
  }
}
