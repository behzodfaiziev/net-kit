import 'package:net_kit/net_kit.dart';

import 'rating_model.dart';

class WrongTypeTestProductModel extends INetKitModel {
  const WrongTypeTestProductModel({
    this.id,
    this.title,
    this.price,
    this.description,
    this.category,
    this.image,
    this.rating,
  });

  factory WrongTypeTestProductModel.fromJson(Map<String, dynamic> json) {
    return WrongTypeTestProductModel(
      id: json['id'] as String?,
      title: json['title'] as String?,
      price: json['price'] as dynamic,
      description: json['description'] as List<int>?,
      category: json['category'] as String?,
      image: json['image'] as String?,
      rating: json['rating'] == null
          ? null
          : RatingModel.fromJson(json['rating'] as Map<String, dynamic>),
    );
  }

  final String? id;
  final String? title;
  final dynamic price;
  final List<int>? description;
  final String? category;
  final String? image;
  final RatingModel? rating;

  @override
  WrongTypeTestProductModel fromJson(Map<String, dynamic> json) =>
      WrongTypeTestProductModel.fromJson(json);

  @override
  Map<String, dynamic>? toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'description': description,
        'category': category,
        'image': image,
        'rating': rating,
      };
}
