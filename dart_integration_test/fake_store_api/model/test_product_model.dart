import 'package:net_kit/net_kit.dart';

import 'rating_model.dart';

class TestProductModel extends INetKitModel<TestProductModel> {
  const TestProductModel({
    this.id,
    this.title,
    this.price,
    this.description,
    this.category,
    this.image,
    this.rating,
  });

  factory TestProductModel.fromJson(Map<String, dynamic> json) {
    return TestProductModel(
      id: json['id'] as int?,
      title: json['title'] as String?,
      price: json['price'] as dynamic,
      description: json['description'] as String?,
      category: json['category'] as String?,
      image: json['image'] as String?,
      rating: json['rating'] == null
          ? null
          : RatingModel.fromJson(json['rating'] as Map<String, dynamic>),
    );
  }

  final int? id;
  final String? title;
  final dynamic price;
  final String? description;
  final String? category;
  final String? image;
  final RatingModel? rating;

  @override
  TestProductModel fromJson(Map<String, dynamic> json) =>
      TestProductModel.fromJson(json);

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
