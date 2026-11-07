import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pet_pack.dart';

enum PetMood { idle, thinking, working, happy, error, sleeping }

/// The in-house Spark pet. It fades a busy pose to idle after ten seconds
/// without a touch, glances left/right while idle, and falls asleep when the
/// idle spell lasts.
class PetView extends StatefulWidget {
  const PetView({
    super.key,
    required this.mood,
    this.scale = 3,
    this.onInteraction,
  });

  final PetMood mood;
  final double scale;
  final VoidCallback? onInteraction;

  @override
  State<PetView> createState() => _PetViewState();
}

class _PetViewState extends State<PetView> {
  static const _busyFade = Duration(seconds: 10);
  static const _idleWindow = Duration(seconds: 10);

  PetPack? _pack;
  PetMood _displayed = PetMood.idle;
  PetAnimation? _anim;
  int _frame = 0;
  bool _once = false;
  VoidCallback? _then;
  bool _transient = false;
  bool _dragging = false;
  bool _glancing = false;
  DateTime _lastTouch = DateTime.now();

  Timer? _frameTimer;
  Timer? _clock;
  Timer? _glanceTimer;
  final Map<String, ui.Image> _sheets = {};
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    _lastTouch = DateTime.now();
    _displayed = widget.mood;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _behavior());
    _load();
  }

  @override
  void didUpdateWidget(covariant PetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood == widget.mood) return;
    final idleFor = DateTime.now().difference(_lastTouch);
    final busy = widget.mood == PetMood.thinking || widget.mood == PetMood.working;
    _displayed = busy && idleFor >= _busyFade ? PetMood.idle : widget.mood;
    if (!_transient && !_dragging) _showBase();
  }

  Future<void> _load() async {
    try {
      final pack = await PetPack.load();
      if (!mounted) return;
      setState(() => _pack = pack);
      _showBase();
    } catch (_) {
      // A missing pet is not worth blocking the chat page.
    }
  }

  void _behavior() {
    if (!mounted || _transient || _dragging || _glancing) return;
    final idleFor = DateTime.now().difference(_lastTouch);
    if ((_displayed == PetMood.thinking || _displayed == PetMood.working) &&
        idleFor >= _busyFade) {
      _displayed = PetMood.idle;
      _showBase();
      return;
    }
    if (_displayed == PetMood.idle &&
        idleFor >= _busyFade + _idleWindow) {
      _displayed = PetMood.sleeping;
      _showBase();
    }
  }

  void _showBase() {
    if (_transient || _dragging) return;
    if (_displayed == PetMood.happy) {
      // Happy is a one-off: after the hop, settle back to idle even if the
      // chat page does not rebuild again.
      _play(
        'happy',
        once: true,
        then: () {
          if (!mounted) return;
          _displayed = PetMood.idle;
          _showBase();
        },
      );
      _cancelGlance();
      return;
    }
    final name = switch (_displayed) {
      PetMood.thinking => 'waiting',
      PetMood.working => 'typing',
      PetMood.happy => 'happy',
      PetMood.error => 'error',
      PetMood.sleeping => 'sleeping',
      PetMood.idle => 'idle',
    };
    _play(name);
    if (_displayed == PetMood.idle) {
      _scheduleGlance();
    } else {
      _cancelGlance();
    }
  }

  void _play(String name, {bool once = false, VoidCallback? then}) {
    final anim = _pack?.animation(name);
    if (anim == null || anim.frames.isEmpty) return;
    _frameTimer?.cancel();
    setState(() {
      _anim = anim;
      _frame = 0;
      _once = once;
      _then = then;
    });
    _ensureSheet(anim);
    _tickFrame();
  }

  void _tickFrame() {
    _frameTimer?.cancel();
    final anim = _anim;
    if (anim == null) return;
    final frame = anim.frames[_frame];
    _frameTimer = Timer(Duration(milliseconds: frame.ms), () {
      if (!mounted) return;
      final next = _frame + 1;
      if (next >= anim.frames.length) {
        if (_once || !anim.loop) {
          final then = _then;
          _then = null;
          _once = false;
          if (then != null) {
            then();
          }
          return;
        }
        _frame = 0;
      } else {
        _frame = next;
      }
      setState(() {});
      _tickFrame();
    });
  }

  void _ensureSheet(PetAnimation anim) {
    if (_sheets.containsKey(anim.sheet) || _loading.contains(anim.sheet)) {
      return;
    }
    _loading.add(anim.sheet);
    unawaited(() async {
      try {
        final data = await rootBundle.load('assets/pets/spark/${anim.sheet}');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        if (!mounted) return;
        setState(() => _sheets[anim.sheet] = frame.image);
      } catch (_) {
        // Leave the frame blank; the next animation tries again.
      } finally {
        _loading.remove(anim.sheet);
      }
    }());
  }

  void _scheduleGlance() {
    _cancelGlance();
    if (_displayed != PetMood.idle || _transient || _dragging) return;
    final options = (_pack?.idles ?? const <PetIdle>[])
        .where((idle) => idle.anim.startsWith('glance'))
        .toList();
    if (options.isEmpty) return;
    final min = _pack?.idleMinMs ?? 4000;
    final max = _pack?.idleMaxMs ?? 9000;
    final wait = min + Random().nextInt(max <= min ? 1 : max - min);
    _glanceTimer = Timer(Duration(milliseconds: wait), () {
      if (!mounted || _displayed != PetMood.idle || _transient || _dragging) {
        return;
      }
      final pick = options[Random().nextInt(options.length)];
      _glancing = true;
      _play(
        pick.anim,
        once: true,
        then: () {
          _glancing = false;
          _showBase();
        },
      );
    });
  }

  void _cancelGlance() {
    _glanceTimer?.cancel();
    _glanceTimer = null;
    _glancing = false;
  }

  void _touch() {
    _lastTouch = DateTime.now();
    widget.onInteraction?.call();
    _cancelGlance();
    if (_displayed == PetMood.sleeping) {
      final busy =
          widget.mood == PetMood.thinking || widget.mood == PetMood.working;
      _transient = true;
      _displayed = busy ? widget.mood : PetMood.idle;
      _play(
        'waking',
        once: true,
        then: () {
          _transient = false;
          _showBase();
        },
      );
      return;
    }
    if (widget.mood == PetMood.thinking || widget.mood == PetMood.working) {
      _displayed = widget.mood;
    }
    _transient = true;
    final options = ['react-left', 'react-right', 'react-double'];
    _play(
      options[Random().nextInt(options.length)],
      once: true,
      then: () {
        _transient = false;
        _showBase();
      },
    );
  }

  void _startDrag() {
    _lastTouch = DateTime.now();
    widget.onInteraction?.call();
    _cancelGlance();
    _dragging = true;
    _play('react-drag');
  }

  void _endDrag() {
    _dragging = false;
    _showBase();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _clock?.cancel();
    _glanceTimer?.cancel();
    for (final image in _sheets.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    if (pack == null) return const SizedBox.shrink();
    final anim = _anim;
    final image = anim == null ? null : _sheets[anim.sheet];
    final size = Size(
      pack.canvas.width * widget.scale,
      pack.canvas.height * widget.scale,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _touch,
      onPanStart: (_) => _startDrag(),
      onPanEnd: (_) => _endDrag(),
      child: SizedBox.fromSize(
        size: size,
        child: CustomPaint(
          painter: _PetPainter(image: image, anim: anim, frame: _frame),
        ),
      ),
    );
  }
}

class _PetPainter extends CustomPainter {
  _PetPainter({required this.image, required this.anim, required this.frame});

  final ui.Image? image;
  final PetAnimation? anim;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    final anim = this.anim;
    if (image == null || anim == null || anim.frames.isEmpty) return;
    final index = anim.frames[frame].index;
    final source = anim.sourceRect(index);
    canvas.drawImageRect(
      image,
      source,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant _PetPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.anim != anim ||
      oldDelegate.frame != frame;
}
