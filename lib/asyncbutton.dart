import 'package:flutter/material.dart';

class AppAsyncButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;
  final ButtonStyle? style;
  final TextStyle? textStyle; // <--- Nowy parametr

  const AppAsyncButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.style,
    this.textStyle, // <--- Dodajemy do konstruktora
  });

  @override
  State<AppAsyncButton> createState() => _AppAsyncButtonState();
}

class _AppAsyncButtonState extends State<AppAsyncButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: widget.style,
      onPressed: _isLoading ? null : _handlePress,
      icon: _isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            )
          : Icon(widget.icon, size: 18),
      label: Text(
        _isLoading ? "CZEKAJ..." : widget.label,
        style: widget.textStyle, // <--- Stosujemy styl tutaj
      ),
    );
  }

  Future<void> _handlePress() async {
    // Tutaj możesz dodać logikę sprawdzania cache,
    // aby pokazać loader tylko gdy faktycznie potrzeba czasu.
    setState(() => _isLoading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
