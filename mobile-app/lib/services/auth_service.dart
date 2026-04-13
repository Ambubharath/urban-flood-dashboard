import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen to the user's authentication state
  Stream<User?> get user {
    return _auth.authStateChanges();
  }

  // Register with email and password and save user profile to Firestore
  Future<UserCredential> registerWithEmail(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    // After successful registration, save the user's profile to Firestore
    if (userCredential.user != null) {
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': userCredential.user!.email,
        'uid': userCredential.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return userCredential;
  }

  // Sign in with email and password and then verify the user's existence in Firestore
  Future<UserCredential> signInWithEmailAndCheckAuth(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final user = userCredential.user;

    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        // If the user's profile doesn't exist, sign them out immediately.
        await signOut();
        throw FirebaseAuthException(
          code: 'unauthorized-user',
          message: 'This account is not authorized to sign in.',
        );
      }
    }
    return userCredential;
  }

  // Sign out
  Future<void> signOut() async {
    return await _auth.signOut();
  }
}
