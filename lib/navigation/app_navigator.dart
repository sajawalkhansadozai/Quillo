import 'package:flutter/material.dart';

/// Root navigator used for home-screen quick actions and deep links.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

NavigatorState? get appNavigator => appNavigatorKey.currentState;
