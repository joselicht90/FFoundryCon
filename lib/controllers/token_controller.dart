import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/foundry_token.dart';
import '../repositories/foundry_repository.dart';

/// Lista de tokens de la escena activa + acciones de movimiento.
class TokenController extends AsyncNotifier<List<FoundryToken>> {
  @override
  Future<List<FoundryToken>> build() =>
      ref.read(foundryRepositoryProvider).getTokens();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(foundryRepositoryProvider).getTokens(),
    );
  }

  /// Mueve un token una o más casillas. No recarga la lista para mantener la
  /// respuesta instantánea del D-pad.
  Future<void> step(
    String tokenId,
    StepDirection direction, {
    int spaces = 1,
  }) =>
      ref
          .read(foundryRepositoryProvider)
          .stepToken(tokenId, direction, spaces: spaces);

  Future<void> setTargets(List<String> tokenIds) =>
      ref.read(foundryRepositoryProvider).setTargets(tokenIds);

  Future<void> moveTo(String tokenId, num x, num y) =>
      ref.read(foundryRepositoryProvider).moveToken(tokenId, x, y);
}

final tokenControllerProvider =
    AsyncNotifierProvider<TokenController, List<FoundryToken>>(
  TokenController.new,
);
