import 'package:flet/flet.dart';
import 'package:flutter/widgets.dart';

import 'terminal_log.dart';

class Extension extends FletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    switch (control.type) {
      case "TerminalLog":
        return TerminalLogControl(control: control);
      default:
        return null;
    }
  }
}
