import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();
  static final ValueNotifier<int> selectedIndex = ValueNotifier<int>(0);

  static void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  static void closeDrawer() {
    scaffoldKey.currentState?.closeDrawer();
  }

  static void navigateTo(int index) {
    selectedIndex.value = index;
    scaffoldKey.currentState?.closeDrawer();
  }
}
