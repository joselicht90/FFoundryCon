import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ffoundrycon/app.dart';
import 'package:ffoundrycon/controllers/session_controller.dart';
import 'package:ffoundrycon/core/storage/prefs_provider.dart';
import 'package:ffoundrycon/models/foundry_world.dart';

void main() {
  testWidgets('arranca en la selección de mundo usando la URL por defecto',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          // Evita la llamada de red real (timer pendiente) en el test.
          worldsProvider.overrideWith((ref) async => <FoundryWorld>[]),
        ],
        child: const FFoundryConApp(),
      ),
    );
    await tester.pump();

    // Con URL hardcodeada por defecto, entra directo a elegir mundo.
    expect(find.text('Elegí un mundo'), findsOneWidget);
  });
}
