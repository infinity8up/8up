import 'package:flutter/widgets.dart';

class RootTabScope extends InheritedWidget {
  const RootTabScope({
    required this.onSelectTab,
    required super.child,
    super.key,
  });

  final ValueChanged<int> onSelectTab;

  static RootTabScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RootTabScope>();
  }

  void selectIndex(int index) => onSelectTab(index);

  @override
  bool updateShouldNotify(RootTabScope oldWidget) {
    return onSelectTab != oldWidget.onSelectTab;
  }
}
