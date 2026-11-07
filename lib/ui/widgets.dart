import 'dart:convert';

import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.shadow = true});

  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: clay.withValues(alpha: 0.25),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          'assets/brand/claude_go.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.active = false, this.warn = false});

  final String text;
  final bool active;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warn
        ? const Color(0xFFB4442F)
        : (active ? scheme.primary : scheme.onSurface.withValues(alpha: 0.55));
    final background = warn
        ? const Color(0x1FB4442F)
        : color.withValues(alpha: 0.10);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class ModeCard extends StatelessWidget {
  const ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outline,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: scheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          const SizedBox(width: 8),
                          Pill(status, active: active),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class ToolTile extends StatelessWidget {
  const ToolTile({super.key, required this.tool});

  final ToolCard tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = tool.input.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('  ·  ');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Row(
            children: [
              Icon(
                tool.isError
                    ? Icons.error_outline_rounded
                    : Icons.build_circle_outlined,
                size: 16,
                color: tool.isError ? const Color(0xFFB4442F) : scheme.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tool.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (!tool.done)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                ),
            ],
          ),
          subtitle: summary.isEmpty
              ? null
              : Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
          children: [
            if (tool.input.isNotEmpty)
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(tool.input),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            if (tool.result != null && tool.result!.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                tool.result!,
                maxLines: 24,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.45,
                  color: tool.isError
                      ? const Color(0xFFB4442F)
                      : scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
