import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// PyCharm 风格右上角悬浮紧凑搜索栏 (高质感专业终端样式完整版)
class TerminalSearchBar extends StatefulWidget {
  const TerminalSearchBar({
    required this.visible,
    required this.onChanged,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
    this.invalidPattern = false,
    this.caseSensitive = false,
    this.wholeWord = false,
    this.regex = true,
    this.wrap = true,
    this.searchText,
    this.onCaseSensitiveChanged,
    this.onWholeWordChanged,
    this.onRegexChanged,
    this.onWrapChanged,
    super.key,
  });

  final bool visible;
  final bool invalidPattern;
  final String? searchText;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;

  final bool caseSensitive;
  final bool wholeWord;
  final bool regex;
  final bool wrap;

  final ValueChanged<bool>? onCaseSensitiveChanged;
  final ValueChanged<bool>? onWholeWordChanged;
  final ValueChanged<bool>? onRegexChanged;
  final ValueChanged<bool>? onWrapChanged;

  @override
  State<TerminalSearchBar> createState() => _TerminalSearchBarState();
}

class _TerminalSearchBarState extends State<TerminalSearchBar> {

  late final FocusNode _node = FocusNode(onKeyEvent: _onKey);
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.searchText);

    if (widget.visible) _node.requestFocus();
  }

  @override
  void didUpdateWidget(TerminalSearchBar old) {
    super.didUpdateWidget(old);

    final safeText = widget.searchText ?? "";
    if (widget.searchText != old.searchText) {
      _ctrl.value = TextEditingValue(
        text: safeText,
        selection: TextSelection.collapsed(offset: safeText.length),
      );
    }

    if (widget.visible == old.visible) return;
    if (widget.visible) {
      _node.requestFocus();
    } else {
      _node.unfocus();
      _ctrl.clear();
    }
  }

  @override
  void dispose() {
    _node.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      HardwareKeyboard.instance.isShiftPressed ? widget.onPrev() : widget.onNext();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildToggleButton({
    required String text,
    required bool isSelected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final bgColor = isSelected ? const Color(0xff007acc) : Colors.transparent;
    final hoverColor = isSelected ? const Color(0xff0062a3) : const Color(0xff3c3c3c);
    final textColor = isSelected ? Colors.white : const Color(0xff888888);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          hoverColor: hoverColor,
          highlightColor: const Color(0xff4c4c4c),
          borderRadius: BorderRadius.circular(3),
          child: Ink(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTerminalButton(IconData icon, VoidCallback? onTap) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        hoverColor: const Color(0xff3c3c3c),
        highlightColor: const Color(0xff4c4c4c),
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Icon(icon, size: 14, color: const Color(0xffcccccc)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2F31),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF43454A), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.invalidPattern ? Icons.error_outline : Icons.search,
            size: 14,
            color: widget.invalidPattern ? const Color(0xFFE06C75) : const Color(0xFFAFB1B3),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 140,
            child: TextField(
              controller: _ctrl,
              focusNode: _node,
              style: const TextStyle(color: Color(0xFFDFE1E5), fontSize: 13),
              cursorColor: const Color(0xff007acc),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
                hintText: widget.invalidPattern ? '错误正则' : '搜索',
                hintStyle: TextStyle(
                  color: widget.invalidPattern ? const Color(0xFFE06C75) : const Color(0xFF6C6E72),
                  fontSize: 13,
                ),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          _buildToggleButton(
            text: 'Cc',
            isSelected: widget.caseSensitive,
            tooltip: '区分大小写 (Aa)',
            onTap: () => widget.onCaseSensitiveChanged?.call(!widget.caseSensitive),
          ),
          // _buildToggleButton(
          //   text: 'W',
          //   isSelected: widget.wholeWord,
          //   tooltip: '全字匹配',
          //   onTap: () => widget.onWholeWordChanged?.call(!widget.wholeWord),
          // ),
          _buildToggleButton(
            text: '.*',
            isSelected: widget.regex,
            tooltip: '正则表达式 (.*)',
            onTap: () => widget.onRegexChanged?.call(!widget.regex),
          ),
          // _buildToggleButton(
          //   text: '⟳',
          //   isSelected: widget.wrap,
          //   tooltip: '循环换行搜索',
          //   onTap: () => widget.onWrapChanged?.call(!widget.wrap),
          // ),
          Container(
            height: 14,
            width: 1,
            color: const Color(0xFF43454A),
            margin: const EdgeInsets.symmetric(horizontal: 6),
          ),
          _buildTerminalButton(Icons.keyboard_arrow_up, widget.onPrev),
          _buildTerminalButton(Icons.keyboard_arrow_down, widget.onNext),
          const SizedBox(width: 10), // 防误触隔离带
          _buildTerminalButton(Icons.close, widget.onClose),
        ],
      ),
    );
  }
}