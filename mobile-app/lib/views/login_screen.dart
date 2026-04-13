import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:floodwatchapp/services/auth_service.dart';
import 'package:floodwatchapp/views/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        _showSnackBar('Please enter both email and password.');
        return;
      }

      await AuthService().signInWithEmailAndCheckAuth(
        _emailController.text,
        _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'The email address is badly formatted.';
          break;
        case 'user-not-found':
          errorMessage = 'No account found for this email. Please sign up.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect email or password. Please try again.';
          break;
        case 'unauthorized-user':
          errorMessage = 'This account is not authorized to sign in.';
          break;
        default:
          errorMessage = 'An unexpected error occurred. Please try again.';
      }
      _showSnackBar(errorMessage);
    } catch (e) {
      _showSnackBar('An unknown error occurred. Please check your network connection.');
      print(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE3F2FD), Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 80),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      spreadRadius: 8,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 80,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to receive flood alerts in your area.',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: Colors.black54,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'e.g., test@gmail.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.email, color: Colors.blue),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignupScreen()),
                        );
                      },
                child: const Text(
                  'Don\'t have an account? Sign Up',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
