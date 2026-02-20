import 'package:flutter/foundation.dart';

class AppShellController {
  static final ValueNotifier<int?> _tabRequests = ValueNotifier<int?>(null);
  static bool _isAttached = false;
  static int? _queuedInitialTab;

  static ValueListenable<int?> get tabRequests => _tabRequests;

  static bool get isAttached => _isAttached;

  static void markAttached() {
    _isAttached = true;
  }

  static void markDetached() {
    _isAttached = false;
  }

  static void openTab(int index) {
    if (_isAttached) {
      _tabRequests.value = index;
      return;
    }
    _queuedInitialTab = index;
  }

  static void consumeRequest() {
    _tabRequests.value = null;
  }

  static int? takeQueuedInitialTab() {
    final value = _queuedInitialTab;
    _queuedInitialTab = null;
    return value;
  }
}
