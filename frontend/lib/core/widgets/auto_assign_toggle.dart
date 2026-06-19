import 'package:flutter/material.dart';

import 'rpc_feature_toggle.dart';

/// Auto-assign courts toggle with clear on/off visual states (especially in light mode).
class AutoAssignToggle extends StatelessWidget {
  const AutoAssignToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabledOnSubtitle,
    this.enabledOffSubtitle,
    this.interactive = true,
    this.compact = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? enabledOnSubtitle;
  final String? enabledOffSubtitle;
  final bool interactive;
  final bool compact;

  static const _defaultOnSubtitle =
      'Next ready groups fill open courts automatically';
  static const _defaultOffSubtitle = 'Courts must be assigned manually';
  static const _startOnSubtitle = 'Fill open courts automatically';

  factory AutoAssignToggle.forStartSession({
    Key? key,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool compact = false,
  }) {
    return AutoAssignToggle(
      key: key,
      value: value,
      onChanged: onChanged,
      enabledOnSubtitle: _startOnSubtitle,
      enabledOffSubtitle: _startOnSubtitle,
      compact: compact,
    );
  }

  factory AutoAssignToggle.forLiveSession({
    Key? key,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool interactive = true,
  }) {
    return AutoAssignToggle(
      key: key,
      value: value,
      onChanged: onChanged,
      enabledOnSubtitle: _defaultOnSubtitle,
      enabledOffSubtitle: _defaultOffSubtitle,
      interactive: interactive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = value
        ? (enabledOnSubtitle ?? _defaultOnSubtitle)
        : (enabledOffSubtitle ?? _defaultOffSubtitle);

    return RpcFeatureToggle(
      title: 'Auto-assign courts',
      subtitle: subtitle,
      icon: Icons.bolt_outlined,
      activeIcon: Icons.bolt_rounded,
      value: value,
      onChanged: onChanged,
      interactive: interactive,
      compact: compact,
    );
  }
}
