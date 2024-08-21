/// ### Methods for HTTP requests.
/// It is used to indicate the desired action
/// to be performed for a given resource.
enum RequestMethod {
  /// The GET method requests a representation of the specified resource.
  get,

  /// The POST method is used to submit an entity to the specified resource,
  post,

  /// The PUT method replaces all current representations of the target resource
  put,

  /// The DELETE method deletes the specified resource.
  delete,

  /// The PATCH method is used to apply partial modifications to a resource.
  patch,
}
