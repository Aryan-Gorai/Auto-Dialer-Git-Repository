// Custom exception classes for auth operations.
// Each one wraps a specific Firebase error code so the UI can show
// user-friendly messages without exposing raw Firebase errors.

//login exceptions
class UserNotFoundAuthException implements Exception{
  // Thrown when Firebase says the email doesn't belong to any account
}
class WrongPasswordAuthException implements Exception{
  // Thrown when the password doesn't match the stored credential
}


//register exceptions

class WeakPasswordAuthException implements Exception{
  // Firebase requires at least 6 characters
}
class EmailAlreadyInUseAuthException implements Exception{
  // Another account with this email already exists
}
class InvalidEmailAuthException implements Exception{
  // The email string isn't in a valid format
}

// generic exceptions

class GenericAuthException implements Exception{
  // Catch-all for any auth error we haven't mapped specifically
}

class UserNotLoggedInAuthException implements Exception{
  // Trying to do something that requires a logged-in user, but nobody is signed in
}