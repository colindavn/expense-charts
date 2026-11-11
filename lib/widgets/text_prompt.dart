import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog with one text field. Returns `parse(text)` on Save, or null on Cancel.
/// It owns its controller, so the controller lives until the dialog is fully closed.
Future<T?> showTextPrompt<T>(
  BuildContext context, {
  required String title,
  required String initial,
  required T? Function(String text) parse,
  TextStyle? style,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  String? prefixText,
  String? suffixText,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => _TextPromptDialog<T>(
      title: title,
      initial: initial,
      parse: parse,
      style: style,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      prefixText: prefixText,
      suffixText: suffixText,
    ),
  );
}

class _TextPromptDialog<T> extends StatefulWidget {
  final String title;
  final String initial;
  final T? Function(String text) parse;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final String? suffixText;

  const _TextPromptDialog({
    required this.title,
    required this.initial,
    required this.parse,
    this.style,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
    this.suffixText,
  });

  @override
  State<_TextPromptDialog<T>> createState() => _TextPromptDialogState<T>();
}

class _TextPromptDialogState<T> extends State<_TextPromptDialog<T>> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final v = widget.parse(_controller.text);
    if (v != null) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        style: widget.style,
        decoration: InputDecoration(prefixText: widget.prefixText, suffixText: widget.suffixText),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
