import 'package:flutter/material.dart';

enum Shape { circle, square }
enum TextType { rotate, normal}

class RadarMapModel {
  List<LegendModel> legend;
  List<MapDataModel> data;
  List<IndicatorModel> indicator;
  Shape shape;
  int duration;
  double radius;
  Color rectColor1;
  Color rectColor2;
  int dashWidth;
  TextType textType;
  int alphaPercent;
  double pointRadius;
  Color pointColor;
  double textOffset;

  static const Color defaultGray = Color(0xFFEEF1F7);
  static const Color defaultPointColor = Color(0xFF346CF6);

  RadarMapModel(
      {required this.legend,
      required this.data,
      required this.indicator,
      required this.radius,
      this.duration = 2000,
      this.shape = Shape.circle, 
      this.rectColor1 = defaultGray,
      this.rectColor2 = Colors.white,
      this.dashWidth = 3,
      this.textType = TextType.normal,
      this.alphaPercent = 60,
      this.pointRadius = 3,
      this.textOffset = 20,
      this.pointColor = defaultPointColor
      });
}

/// 考虑legend、Dimension、data的长度对应关系

// 指标 model
class LegendModel {
  final String name;
  final Color color;

  LegendModel(this.name, this.color);
}

//  维度 model
class IndicatorModel {
  final String name; // 维度名称
  final double maxValues; // 当前维度的最大值

  IndicatorModel(this.name, this.maxValues);
}

// 根据每个legend给出维度的值列表
class MapDataModel {
  final List<double> data;

//  final String legendName;

  MapDataModel(this.data);
}
