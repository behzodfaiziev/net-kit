/// Transfer progress for a request body or a response body.
///
/// [count] is the number of bytes transferred so far. [total] is the declared
/// length when it is known, otherwise `-1`.
typedef NetKitProgressCallback = void Function(int count, int total);
