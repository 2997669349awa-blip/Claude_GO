import 'dart:convert';

import 'package:flutter/services.dart';

class PetFrame {
  const PetFrame(this.index, this.ms);

  final int index;
  final int ms;
}

class PetAnimation {
  const PetAnimation({
    required this.name,
    required this.sheet,
    required this.frameW,
    required this.frameH,
    required this.cols,
    required this.frames,
    required this.loop,
  });

  final String name;
  final String sheet;
  final int frameW;
  final int frameH;
  final int cols;
  final List<PetFrame> frames;
  final bool loop;

  int get durationMs => frames.fold(0, (sum, frame) => sum + frame.ms);

  Rect sourceRect(int index) => Rect.fromLTWH(
    ((index % cols) * frameW).toDouble(),
    ((index ~/ cols) * frameH).toDouble(),
    frameW.toDouble(),
    frameH.toDouble(),
  );
}

class PetIdle {
  const PetIdle(this.anim, this.ms);

  final String anim;
  final int ms;
}

class PetPack {
  const PetPack({
    required this.canvas,
    required this.anchorX,
    required this.baseline,
    required this.contentBox,
    required this.animations,
    required this.states,
    required this.idles,
    required this.idleMinMs,
    required this.idleMaxMs,
    required this.sleepAfter,
    required this.reactions,
  });

  final Size canvas;
  final double anchorX;
  final double baseline;
  final Rect contentBox;
  final Map<String, PetAnimation> animations;
  final Map<String, List<String>> states;
  final List<PetIdle> idles;
  final int idleMinMs;
  final int idleMaxMs;
  final Duration sleepAfter;
  final Map<String, String> reactions;

  static Future<PetPack> load({String id = 'spark'}) async {
    final raw = await rootBundle.loadString('assets/pets/$id/pack.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final canvasJson = json['canvas'] as Map<String, dynamic>;
    final anchorJson = json['anchor'] as Map<String, dynamic>;
    final boxJson = json['contentBox'] as Map<String, dynamic>;

    final animations = <String, PetAnimation>{};
    (json['animations'] as Map<String, dynamic>).forEach((name, value) {
      final map = value as Map<String, dynamic>;
      final frames = (map['frames'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (frame) => PetFrame(
              (frame['i'] as num).toInt(),
              (frame['ms'] as num).toInt(),
            ),
          )
          .toList();
      animations[name] = PetAnimation(
        name: name,
        sheet: map['sheet'] as String,
        frameW: (map['frameW'] as num).toInt(),
        frameH: (map['frameH'] as num).toInt(),
        cols: (map['cols'] as num).toInt(),
        frames: frames,
        loop: map['loop'] == true,
      );
    });

    final states = <String, List<String>>{};
    (json['states'] as Map<String, dynamic>).forEach((name, value) {
      states[name] = (value as List).cast<String>();
    });

    final idlePool = json['idlePool'] as Map<String, dynamic>?;
    final idles = (idlePool?['anims'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (value) => PetIdle(
            value['anim'] as String,
            (value['ms'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
    final every = idlePool?['everyMs'] as Map<String, dynamic>?;
    final sleep = json['sleep'] as Map<String, dynamic>?;

    return PetPack(
      canvas: Size(
        (canvasJson['w'] as num).toDouble(),
        (canvasJson['h'] as num).toDouble(),
      ),
      anchorX: (anchorJson['x'] as num).toDouble(),
      baseline: (anchorJson['baseline'] as num).toDouble(),
      contentBox: Rect.fromLTWH(
        (boxJson['x'] as num).toDouble(),
        (boxJson['y'] as num).toDouble(),
        (boxJson['w'] as num).toDouble(),
        (boxJson['h'] as num).toDouble(),
      ),
      animations: animations,
      states: states,
      idles: idles,
      idleMinMs: (every?['min'] as num?)?.toInt() ?? 4000,
      idleMaxMs: (every?['max'] as num?)?.toInt() ?? 9000,
      sleepAfter: Duration(
        milliseconds: (sleep?['afterMs'] as num?)?.toInt() ?? 20000,
      ),
      reactions: ((json['reactions'] as Map?) ?? const {})
          .cast<String, String>(),
    );
  }

  PetAnimation? animationForState(String state) {
    final name = states[state]?.first;
    return name == null ? null : animations[name];
  }

  PetAnimation? animation(String name) => animations[name];
}
