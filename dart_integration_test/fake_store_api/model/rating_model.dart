import 'package:net_kit/net_kit.dart';

class RatingModel extends INetKitModel<RatingModel> {
  const RatingModel({this.rate, this.count});

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      rate: json['rate'] as dynamic,
      count: json['count'] as int?,
    );
  }

  final dynamic rate;
  final int? count;

  @override
  RatingModel fromJson(Map<String, dynamic> json) => RatingModel.fromJson(json);

  @override
  Map<String, dynamic>? toJson() => {'rate': rate, 'count': count};
}
