import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/foundry_user.dart';
import '../models/foundry_world.dart';
import '../repositories/foundry_repository.dart';

/// Mundos disponibles en el reader (leídos del filesystem del volumen).
final worldsProvider = FutureProvider.autoDispose<List<FoundryWorld>>(
  (ref) => ref.watch(foundryRepositoryProvider).getWorlds(),
);

/// Usuarios de un mundo, leídos de su LevelDB.
final worldUsersProvider =
    FutureProvider.autoDispose.family<List<FoundryUser>, String>(
  (ref, worldId) => ref.watch(foundryRepositoryProvider).getUsers(worldId),
);

/// Mundo elegido por el usuario.
class SelectedWorldController extends Notifier<FoundryWorld?> {
  @override
  FoundryWorld? build() => null;

  void select(FoundryWorld world) => state = world;
  void clear() => state = null;
}

final selectedWorldProvider =
    NotifierProvider<SelectedWorldController, FoundryWorld?>(
  SelectedWorldController.new,
);

/// Usuario (jugador o GM) elegido dentro del mundo.
class SelectedUserController extends Notifier<FoundryUser?> {
  @override
  FoundryUser? build() => null;

  void select(FoundryUser user) => state = user;
  void clear() => state = null;
}

final selectedUserProvider =
    NotifierProvider<SelectedUserController, FoundryUser?>(
  SelectedUserController.new,
);
