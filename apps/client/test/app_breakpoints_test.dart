import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/theme/app_breakpoints.dart';

void main() {
  test('window classes use shared breakpoint boundaries', () {
    expect(appWindowClass(320), AppWindowClass.compact);
    expect(appWindowClass(599), AppWindowClass.compact);
    expect(appWindowClass(600), AppWindowClass.medium);
    expect(appWindowClass(839), AppWindowClass.medium);
    expect(appWindowClass(840), AppWindowClass.expanded);
    expect(appWindowClass(1199), AppWindowClass.expanded);
    expect(appWindowClass(1200), AppWindowClass.desktop);
  });

  test('breakpoint scale is monotonic', () {
    expect(AppBreakpoints.compact, lessThan(AppBreakpoints.medium));
    expect(AppBreakpoints.medium, lessThan(AppBreakpoints.expanded));
    expect(AppBreakpoints.expanded, lessThan(AppBreakpoints.desktop));
  });
}
