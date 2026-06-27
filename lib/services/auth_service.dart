import 'dart:async';

/// Firebase Authentication remove karne ke baad login local hai.
/// Is class ko placeholder ke taur par rakha gaya hai taaki build compile rahe.
class AuthService {
  Stream<Object?> get authStateChanges => const Stream.empty();

  Object? get currentUser => null;

  Future<void> signOut() async {}
}
