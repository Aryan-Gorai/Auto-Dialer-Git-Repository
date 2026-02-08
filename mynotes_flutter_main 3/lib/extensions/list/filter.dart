// Stream extension that filters a List<T> inside a stream.
// Handy for narrowing down Firestore snapshot streams to only the items we want.
extension Filter<T> on Stream<List<T>> {
  Stream<List<T>> filter(bool Function(T) where) =>
    map((items) => items.where(where).toList());
}