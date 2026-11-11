import 'package:flutter/widgets.dart';

import 'content_repository.dart';

/// Provides the [ContentRepository] to the widget tree so tests can swap it.
class ContentScope extends InheritedWidget {
  const ContentScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final ContentRepository repository;

  static ContentRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ContentScope>();
    return scope?.repository ?? ContentRepository();
  }

  @override
  bool updateShouldNotify(ContentScope oldWidget) =>
      repository != oldWidget.repository;
}
