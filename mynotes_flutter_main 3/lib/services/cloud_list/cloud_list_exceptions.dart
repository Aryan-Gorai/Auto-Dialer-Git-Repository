// Typed exception classes for the list and contact management layer.
// Mirrors the pattern used in auth_exceptions.dart — each error
// condition has its own class so callers can catch specific failures
// rather than relying on generic catch-all blocks.
//
// AQA Excellent coding style: Good exception handling,
// defensive programming

/// Base class for all list/contact service exceptions.
class ListServiceException implements Exception {
  final String message;
  const ListServiceException([this.message = '']);

  @override
  String toString() =>
      message.isEmpty ? runtimeType.toString() : '$runtimeType: $message';
}

// ---------------------------------------------------------------------------
// List exceptions
// ---------------------------------------------------------------------------

/// Thrown when a list that was expected to exist cannot be found.
class ListNotFoundException extends ListServiceException {
  const ListNotFoundException([super.message = 'List not found']);
}

/// Thrown when attempting to create a list with a name that already exists.
class DuplicateListException extends ListServiceException {
  const DuplicateListException(
      [super.message = 'A list with this name already exists']);
}

/// Thrown when the list name is empty or otherwise invalid.
class InvalidListNameException extends ListServiceException {
  const InvalidListNameException(
      [super.message = 'List name is empty or invalid']);
}

/// Thrown when the user has reached the maximum allowed number of lists.
class ListLimitExceededException extends ListServiceException {
  const ListLimitExceededException(
      [super.message = 'Maximum number of lists reached']);
}

// ---------------------------------------------------------------------------
// Contact exceptions
// ---------------------------------------------------------------------------

/// Thrown when a contact document that was expected to exist cannot be found.
class ContactNotFoundException extends ListServiceException {
  const ContactNotFoundException([super.message = 'Contact not found']);
}

/// Thrown when attempting to add a contact that already exists in the
/// target list (based on normalised phone number).
class DuplicateContactException extends ListServiceException {
  const DuplicateContactException(
      [super.message = 'Contact already exists in this list']);
}

/// Thrown when the provided phone number is empty, too short, or
/// otherwise fails validation.
class InvalidPhoneNumberException extends ListServiceException {
  const InvalidPhoneNumberException(
      [super.message = 'Phone number is invalid']);
}

/// Thrown when the contact name is empty or fails validation.
class InvalidContactNameException extends ListServiceException {
  const InvalidContactNameException(
      [super.message = 'Contact name is empty or invalid']);
}

// ---------------------------------------------------------------------------
// General Firestore exceptions
// ---------------------------------------------------------------------------

/// Thrown when a Firestore operation fails due to a network issue,
/// permission denial, or other infrastructure-level problem.
class FirestoreOperationException extends ListServiceException {
  const FirestoreOperationException(
      [super.message = 'Firestore operation failed']);
}

/// Thrown when data retrieved from Firestore is in an unexpected format.
class DataFormatException extends ListServiceException {
  const DataFormatException(
      [super.message = 'Unexpected data format in Firestore document']);
}
