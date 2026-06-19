import 'package:flutter/material.dart';

import 'theme/rpc_palette.dart';

class MatchModeDefinition {
  const MatchModeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.useCase,
    required this.icon,
    this.recommended = false,
    this.forcesSingles = false,
    this.requiresSkillLevel = false,
    this.requiresGender = false,
  });

  final String id;
  final String name;
  final String description;
  final String useCase;
  final IconData icon;
  final bool recommended;
  final bool forcesSingles;
  final bool requiresSkillLevel;
  final bool requiresGender;
}

abstract final class MatchModes {
  static const defaultMode = 'auto_balanced';

  static const all = [
    MatchModeDefinition(
      id: 'auto_balanced',
      name: 'Auto-Balanced',
      description:
          'Fair player rotation with maximum variety while minimizing repeat partners and opponents.',
      useCase: 'General open play with mixed skill levels',
      icon: Icons.balance_rounded,
      recommended: true,
    ),
    MatchModeDefinition(
      id: 'skill_separated',
      name: 'Skill-Separated',
      description:
          'Group players into Beginner, Intermediate, and Advanced tiers for competitive matches.',
      useCase: 'Clinics, ladders, or tiered club nights',
      icon: Icons.leaderboard_rounded,
      requiresSkillLevel: true,
    ),
    MatchModeDefinition(
      id: 'winner_loser_groups',
      name: 'Winner/Loser Groups',
      description:
          'Winners stay in the winners pool while losers move to the losers pool for upcoming matches.',
      useCase: 'Classic open-play rotation by match result',
      icon: Icons.emoji_events_outlined,
    ),
    MatchModeDefinition(
      id: 'mixed_doubles',
      name: 'Mixed Doubles',
      description:
          'Prioritize mixed-gender doubles teams while maintaining balanced skill and fair rotations.',
      useCase: 'Social mixed events and co-ed play',
      icon: Icons.people_alt_rounded,
      requiresGender: true,
    ),
    MatchModeDefinition(
      id: 'skill_courts',
      name: 'Skill Courts',
      description:
          'Assign dedicated courts to skill brackets with separate queues for each level.',
      useCase: 'Facilities with fixed beginner/intermediate/advanced courts',
      icon: Icons.grid_view_rounded,
      requiresSkillLevel: true,
    ),
    MatchModeDefinition(
      id: 'singles',
      name: 'Singles',
      description:
          '1v1 format with two players assigned per court for head-to-head matches.',
      useCase: 'Singles tournaments or practice sessions',
      icon: Icons.person_rounded,
      forcesSingles: true,
    ),
    MatchModeDefinition(
      id: 'king_queen_court',
      name: 'King/Queen of the Court',
      description:
          'Ladder-style play where winners move up, losers move down, and partners rotate between matches.',
      useCase: 'High-energy challenge courts and ladder nights',
      icon: Icons.military_tech_rounded,
    ),
  ];

  static MatchModeDefinition byId(String id) {
    return all.firstWhere(
      (mode) => mode.id == id,
      orElse: () => all.first,
    );
  }

  static String sessionNameFor(String modeId) {
    return '${byId(modeId).name} Session';
  }

  static Color accentForQueue(BuildContext context, String queueType) {
    final c = context.rpc;
    return switch (queueType) {
      'winner' => c.success,
      'loser' => c.danger,
      'beginner' => const Color(0xFF10B981),
      'intermediate' => c.primary,
      'advanced' => const Color(0xFF8B5CF6),
      _ => c.textMuted,
    };
  }

  /// Header strip behind queue labels (Winners / Losers tabs, etc.).
  static Color headerBackgroundForQueue(BuildContext context, String queueType) {
    final c = context.rpc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentForQueue(context, queueType);

    if (isDark) {
      return accent.withValues(alpha: 0.16);
    }

    return switch (queueType) {
      'winner' => const Color(0xFFDCFCE7),
      'loser' => const Color(0xFFFEE2E2),
      'beginner' => const Color(0xFFDCFCE7),
      'intermediate' => const Color(0xFFEFF6FF),
      'advanced' => const Color(0xFFF3E8FF),
      _ => c.surfaceHover,
    };
  }

  static String genderLabel(String gender) {
    return switch (gender) {
      'male' => 'Male',
      'female' => 'Female',
      _ => gender,
    };
  }

  static String skillLabel(String skillLevel) {
    return switch (skillLevel) {
      'beginner' => 'Beginner',
      'intermediate' => 'Intermediate',
      'advanced' => 'Advanced',
      _ => skillLevel,
    };
  }

  static String labelForQueue(String queueType) {
    return switch (queueType) {
      'winner' => 'Winners Queue',
      'loser' => 'Losers Queue',
      'beginner' => 'Beginner Queue',
      'intermediate' => 'Intermediate Queue',
      'advanced' => 'Advanced Queue',
      _ => queueType,
    };
  }
}
