import 'package:dartz/dartz.dart';

import '../../model/error/error_model.dart';

/// Request model for network request
/// [R] is the model to parse the data to
/// [ErrorModel] is the error model
/// [RequestModel] is the response of the request
typedef RequestModel<R> = Future<Either<ErrorModel, R>>;

/// Request list for network request
/// [R] is the model to parse the data to
/// [ErrorModel] is the error model
/// [RequestList] is the response of the request
/// It returns a list of models
typedef RequestList<R> = Future<Either<ErrorModel, List<R>>>;

/// Request void for network request
/// [ErrorModel] is the error model
/// [RequestVoid] is the response of the request
/// It returns null
typedef RequestVoid = Future<Either<ErrorModel, void>>;

/// The map type definition
typedef MapType = Map<String, dynamic>;
