import 'dart:async';

import 'package:flet/flet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_alacritty/flutter_alacritty.dart' hide TerminalSearchBar;

import 'alacritty/search_bar.dart';
import 'alacritty/terminal_history_scrollbar.dart';

// 定义专属的日志快捷键 Intent
class SelectAllIntent extends Intent { const SelectAllIntent(); }
class CopyLogIntent extends Intent { const CopyLogIntent(); }
class ScrollToTopIntent extends Intent { const ScrollToTopIntent(); }
class ScrollToBottomIntent extends Intent { const ScrollToBottomIntent(); }
class ToggleSearchIntent extends Intent { const ToggleSearchIntent(); }

class RustManager {
  RustManager._(); // 私有构造，防止外部实例化

  static Future<void>? _initFuture;

  /// 全局唯一的初始化方法
  static Future<void> init() async {
    _initFuture ??= RustLib.init();
    return _initFuture!;
  }
}

class TerminalLogControl extends StatefulWidget {
  final Control control;

  TerminalLogControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<TerminalLogControl> createState() => _TerminalLogControlState();
}

class _TerminalLogControlState extends State<TerminalLogControl> {
  late TerminalConfig _config;
  TerminalEngine? _engine;
  final TerminalController _controller = TerminalController();
  final FocusNode _focus = FocusNode();

  DataChannel? _channel;
  StreamSubscription<Uint8List>? _channelSub;

  bool _searchOpen = false;
  String _searchPattern = '';
  String _searchText = '';
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _regex = true;
  bool _wrap = true;

  static final Uint8List _frameDispose = Uint8List.fromList([0xFF]);

  final GlobalKey<State<TerminalView>> _viewKey = GlobalKey<State<TerminalView>>();

  @override
  void initState() {
    super.initState();

    _config = TerminalConfig.defaults();
    _config = _config.copyWith(
      colors: _config.colors.copyWith(
        selection: 0xFF6600,
      ),
      scrolling: const ScrollConfig(history: 100000, multiplier: 3),
    );

    _initRustLib();
    _focus.addListener(_onFocusChange);
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  // RustLib 初始化 必须
  Future<void> _initRustLib() async {
    await RustManager.init();

    if (!mounted) return;

    // 在 RustLib 初始化完成后 引擎同步创建与绑定
    final engine = TerminalEngine(config: _config);
    _engine = engine;
    _controller.attach(engine);

    setState(() {});
    triggerEvent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_channelSub != null) return;  // initialise lazily, once
    _channel = FletBackend.of(context).openDataChannel();
    _channelSub = _channel!.messages.listen(_onFrameFromPython);
    // Tell Python about the channel via a regular control event.
    triggerEvent();
  }

  void triggerEvent() {
    if (_channelSub == null || _engine == null) return;
    widget.control.triggerEvent("data_channel_open", {
      "channel_name": "termlog",
      "channel_id": _channel!.id,
    });
  }

  void _onFrameFromPython(Uint8List bytes) {
    _engine?.feed(bytes);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    switch (name) {
      case "clear":
        _engine?.clearHistory();
      default: ;
    }
  }

  // 调整光标
  void _onFocusChange() {
    if (_focus.hasFocus) {
      var tConfig = _config.copyWith(
        cursor: const CursorConfig(
          blinkInterval: 530,
          defaultBlinking: true,
          blinkTimeout: 0
        ),
      );
      _applyConfig(tConfig);
    } else {
      var tConfig = _config.copyWith(
        cursor: const CursorConfig(
          blinkInterval: 530,
          defaultShape: 3,
          defaultBlinking: false,
        ),
      );
      _applyConfig(tConfig);
    }
  }

  // 更新配置
  void _applyConfig(TerminalConfig next) {
    setState(() {
      _config = next;
    });
    _engine?.reconfigure(next);
  }

  TerminalSearchOptions get _searchOptions => TerminalSearchOptions(
    caseSensitive: _caseSensitive,
    wholeWord: _wholeWord,
    regex: _regex,
    wrap: _wrap,
  );

  void _applySearch(String pattern) {
    _searchPattern = pattern;
    if (pattern.isEmpty) {
      _controller.searchClear();
    } else {
      _controller.searchSet(pattern, options: _searchOptions);
    }
  }

  void _setSearchOption(void Function() update) {
    setState(update);
    _applySearch(_searchPattern);
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchText = '';
        _searchPattern = '';
      }
    });
    if (!_searchOpen) {
      _controller.searchClear();
      // 终端聚焦
      Future.microtask(() {
        _focus.requestFocus();
      });
    }
  }

  void _copySelection() {
    final text = _engine!.selectionText();
    if (text != null && text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
    }
  }

  Future<void> _selectAll() async {
    final terminalGrid = _engine!.grid;
    final int maxColumns = terminalGrid.columns;
    final int screenRows = terminalGrid.rows;

    // 目前只能在首屏才能全选，挺坑的
    await _controller.scrollToTop();

    // 2. 🚀 终点：当前视口物理底部 + 滚轮向上偏移量 = 真正的最新数据最底端
    final int liveEndRow = (screenRows - 1) + terminalGrid.displayOffset;

    // 3. 模拟在绝对坐标的最左上角按下
    _controller.selectionStart(0, 0, false, 0);

    // 4. 模拟拖拽到绝对坐标的最右下角
    _controller.selectionUpdate(liveEndRow, maxColumns - 1, true);

    // 5. 结束选择并同步剪贴板状态
    _controller.capturePrimary();

    // 6. 通知画面刷新
    _engine!.refreshView();
  }

  Future<void> _scrollToTop() async {
    await _controller.scrollToTop();
  }

  // 🚀 异步跳转到尾行
  Future<void> _scrollToBottom() async {
    await _controller.scrollToBottom();
  }

  void _handleSearchShortcut() {
    final selectedText = _engine!.selectionText() ?? '';
    setState(() {
      if (selectedText.isNotEmpty) {
        _searchOpen = true;
        _searchText = selectedText;
        _searchPattern = selectedText;
        _applySearch(selectedText);
      } else {
        _searchOpen = !_searchOpen;
        _searchText = '';
        _searchPattern = '';
        _controller.searchClear();
      }
    });
  }

  @override
  void dispose() {
    _engine?.clearHistory();

    // 通知flet我退出了
    _channel?.send(_frameDispose);

    // flet通道
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.close();
    _channel = null;
    // 组件
    _controller.dispose();
    _engine?.dispose();
    _engine = null;
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget myControl = Scaffold(
      backgroundColor: Color(0xFF000000 | _config.colors.background),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_engine != null)
                  Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (PointerDownEvent event) {
                      if (!_focus.hasFocus) {
                        // 延迟聚焦，解决第一次点击不能聚焦问题
                        Future.microtask(() {
                          _focus.requestFocus();
                        });
                      }
                    },
                    onPointerSignal: (PointerSignalEvent pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        // 1. 检查是否正在向上滚动（dy < 0 意味着鼠标滚轮在往上滚历史记录）
                        final isScrollingUp = pointerSignal.scrollDelta.dy < 0;
                        // 解决没有历史区域向上滚动显示异常
                        if (isScrollingUp && _engine!.grid.historySize == 0) {
                          _engine!.onCancelCoalescedScroll?.call();
                        }
                      }
                    },
                    child: TerminalView(
                      _engine!,
                      key: _viewKey,
                      onPtyResize: (cols, rows) {},
                      controller: _controller,
                      theme: _config.theme,
                      textStyle: _config.style,
                      padding: EdgeInsets.symmetric(
                        horizontal: _config.window.padding.x,
                        vertical: _config.window.padding.y,
                      ),
                      focusNode: _focus,
                      autofocus: true,
                      cursorBlinkInterval: Duration(milliseconds: _config.cursor.blinkInterval),
                      cursorBlinkTimeout: Duration(seconds: _config.cursor.blinkTimeout),
                      bellDuration: Duration(milliseconds: _config.bell.duration),
                      doubleClickThreshold: Duration(milliseconds: _config.mouse.doubleClickThreshold),
                      scrollMultiplier: _config.scrolling.multiplier,
                      scrollSensitivity: _config.scrolling.sensitivity * 0.85,
                      fastScrollSensitivity: _config.scrolling.fastSensitivity,
                      tuiScrollSensitivity: 1,

                      // 🚀 核心修改：直接让底层终端视图监听这套快捷键映射
                      shortcuts: const <ShortcutActivator, Intent>{
                        SingleActivator(LogicalKeyboardKey.keyA, control: true): SelectAllIntent(),
                        SingleActivator(LogicalKeyboardKey.keyC, control: true): CopyLogIntent(),
                        SingleActivator(LogicalKeyboardKey.home, control: true): ScrollToTopIntent(),
                        SingleActivator(LogicalKeyboardKey.end, control: true): ScrollToBottomIntent(),
                        SingleActivator(LogicalKeyboardKey.keyF, control: true): ToggleSearchIntent(),
                      },

                      // 🚀 核心修改：直接在底层终端内执行对应的业务逻辑
                      actions: <Type, Action<Intent>>{
                        SelectAllIntent: CallbackAction<SelectAllIntent>(onInvoke: (_) => _selectAll()),
                        CopyLogIntent: CallbackAction<CopyLogIntent>(onInvoke: (_) => _copySelection()),
                        ScrollToTopIntent: CallbackAction<ScrollToTopIntent>(onInvoke: (_) => _scrollToTop()),
                        ScrollToBottomIntent: CallbackAction<ScrollToBottomIntent>(onInvoke: (_) => _scrollToBottom()),
                        ToggleSearchIntent: CallbackAction<ToggleSearchIntent>(
                          onInvoke: (_) {
                            _handleSearchShortcut();
                            return null;
                          },
                        ),
                      },
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 25,
                  child: Offstage(
                    offstage: !_searchOpen,
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => TerminalSearchBar(
                        visible: _searchOpen,
                        searchText: _searchText,
                        invalidPattern: !_controller.searchValid,
                        caseSensitive: _caseSensitive,
                        wholeWord: _wholeWord,
                        regex: _regex,
                        wrap: _wrap,
                        onChanged: _applySearch,
                        onNext: _controller.searchNext,
                        onPrev: _controller.searchPrev,
                        onClose: _toggleSearch,
                        onCaseSensitiveChanged: (v) => _setSearchOption(() => _caseSensitive = v),
                        onWholeWordChanged: (v) => _setSearchOption(() => _wholeWord = v),
                        onRegexChanged: (v) => _setSearchOption(() => _regex = v),
                        onWrapChanged: (v) => _setSearchOption(() => _wrap = v),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_engine != null)
            TerminalHistoryScrollbar(
              engine: _engine!,
              controller: _controller,
            ),
        ],
      ),
    );

    return LayoutControl(control: widget.control, child: myControl);
  }
}