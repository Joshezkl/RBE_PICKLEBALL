import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../check_in_url.dart';
import '../theme/rpc_palette.dart';
import '../theme/rpc_spacing.dart';
import '../theme/rpc_typography.dart';
import 'rpc_card.dart';
import 'rpc_section_header.dart';

class CheckInQrPanel extends StatelessWidget {
  const CheckInQrPanel({
    super.key,
    required this.sessionName,
    required this.checkInToken,
  });

  final String sessionName;
  final String checkInToken;

  @override
  Widget build(BuildContext context) {
    final checkInUrl = buildCheckInUrl(checkInToken);
    final statusUrl = buildQueueStatusUrl(checkInToken);

    return RpcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RpcSectionHeader(
            title: 'Player Check-In',
            subtitle: 'Scan to join the session from a phone — no admin PIN needed',
          ),
          const SizedBox(height: RpcSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= RpcBreakpoints.compact;
              final checkInQr = _QrTile(
                label: 'Check In',
                caption: 'Join session',
                url: checkInUrl,
              );
              final statusQr = _QrTile(
                label: 'Queue Status',
                caption: 'Where am I?',
                url: statusUrl,
              );

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sessionName, style: RpcTypography.title(context)),
                  const SizedBox(height: RpcSpacing.sm),
                  Text(
                    'Check-in for new arrivals. Queue status lets players see position, court, and step out/back.',
                    style: RpcTypography.bodySmallMuted(context),
                  ),
                  const SizedBox(height: RpcSpacing.md),
                  _CopyLinkButton(url: checkInUrl, label: 'Copy check-in link'),
                  const SizedBox(height: RpcSpacing.sm),
                  _CopyLinkButton(url: statusUrl, label: 'Copy status link'),
                ],
              );

              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    checkInQr,
                    const SizedBox(width: RpcSpacing.md),
                    statusQr,
                    const SizedBox(width: RpcSpacing.lg),
                    Expanded(child: details),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: checkInQr),
                      const SizedBox(width: RpcSpacing.md),
                      Expanded(child: statusQr),
                    ],
                  ),
                  const SizedBox(height: RpcSpacing.lg),
                  details,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QrTile extends StatelessWidget {
  const _QrTile({
    required this.label,
    required this.caption,
    required this.url,
  });

  final String label;
  final String caption;
  final String url;

  @override
  Widget build(BuildContext context) {
    final c = context.rpc;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(RpcSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(RpcSpacing.inputRadius),
            border: Border.all(color: c.border),
          ),
          child: QrImageView(
            data: url,
            size: 140,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: RpcSpacing.sm),
        Text(label, style: RpcTypography.bodyBold(context)),
        Text(caption, style: RpcTypography.caption(context)),
      ],
    );
  }
}

class _CopyLinkButton extends StatelessWidget {
  const _CopyLinkButton({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label copied')),
          );
        }
      },
      icon: const Icon(Icons.link_rounded, size: 18),
      label: Text(label),
    );
  }
}
