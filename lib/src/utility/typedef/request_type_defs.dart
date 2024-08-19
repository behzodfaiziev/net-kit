import 'package:dartz/dartz.dart';

import '../../model/error/error_model.dart';

typedef RequestModel<R> = Future<Either<ErrorModel, R>>;

typedef RequestList<R> = Future<Either<ErrorModel, List<R>>>;

typedef RequestVoid = Future<Either<ErrorModel, void>>;

typedef MapType = Map<String, dynamic>;
