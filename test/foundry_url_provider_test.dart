import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ffoundrycon/core/network/foundry_url_provider.dart';
import 'package:ffoundrycon/core/storage/prefs_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() => container.dispose());

  test('sin URL guardada es null', () {
    expect(container.read(foundryUrlProvider), isNull);
  });

  test('normaliza espacios y barras finales', () async {
    final ok = await container
        .read(foundryUrlProvider.notifier)
        .set('  https://foundry.example.test//  ');
    expect(ok, isTrue);
    expect(container.read(foundryUrlProvider), 'https://foundry.example.test');
  });

  test('rechaza URLs que no son https', () async {
    final notifier = container.read(foundryUrlProvider.notifier);
    expect(await notifier.set('http://foundry.example.test'), isFalse);
    expect(await notifier.set('foundry.example.test'), isFalse);
    expect(container.read(foundryUrlProvider), isNull);
  });

  test('vacía borra la guardada', () async {
    final notifier = container.read(foundryUrlProvider.notifier);
    await notifier.set('https://foundry.example.test');
    expect(await notifier.set('   '), isTrue);
    expect(container.read(foundryUrlProvider), isNull);
  });
}
