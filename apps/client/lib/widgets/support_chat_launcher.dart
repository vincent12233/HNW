import 'package:flutter/material.dart';

import '../pages/support_chat_page.dart';
import 'support_ui_metrics.dart';

/// Opens the in-app support panel that launches SaleSmartly on Android/iOS.
/// Used by the home Deposit CTA and the side floating customer-service button.
Future<void> showSupportChatPanel(
  BuildContext context, {
  String? initialMessage,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close support',
    barrierColor: const Color(0x73071326),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final m = SupportUiMetrics.of(context);
            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  m.panelHorizontalInset,
                  12,
                  m.panelHorizontalInset,
                  m.panelBottomInset,
                ),
                child: SizedBox(
                  width: m.panelWidth,
                  height: m.panelMaxHeight,
                  child: Material(
                    color: Colors.transparent,
                    elevation: 16,
                    shadowColor: const Color(0x66071326),
                    borderRadius: BorderRadius.circular(m.panelRadius),
                    clipBehavior: Clip.antiAlias,
                    child: SupportChatPage(initialMessage: initialMessage),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
