library flutter_radar_map;

import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_radar_map/radar_map_model.dart';

class RadarWidget extends StatefulWidget {
  final RadarMapModel radarMap;
  final TextStyle? textStyle;
  final ImageProvider? image;
  final bool isNeedDrawLegend;

  RadarWidget({Key? key, required this.radarMap, this.textStyle, this.image, this.isNeedDrawLegend = false})
      : assert(radarMap.legend.length == radarMap.data.length),
        super(key: key);

  @override
  _RadarMapWidgetState createState() => _RadarMapWidgetState();
}

class _RadarMapWidgetState extends State<RadarWidget> with SingleTickerProviderStateMixin {
  double _angle = 0.0;
  late AnimationController controller; // 动画控制器
  late Animation<double> animation; // 动画实例
  Function()? listener;
  var img;

  @override
  void initState() {
    super.initState();
    // 创建 Animation对象
    controller = AnimationController(
        duration: Duration(milliseconds: widget.radarMap.duration),
        vsync: this
    );
    // 创建曲线插值器
    var curveTween = CurveTween(curve: Cubic(0.96, 0.13, 0.1, 1.2));
    // 定义估值器
    var tween = Tween(begin: 0.0, end: 360.0);
    // 插值器根据时间产生值，并提供给估值器，作为animation的value
    animation = tween.animate(curveTween.animate(controller));
    listener = () {
      setState(() {
        _angle = animation.value;
      });
    };
    animation.addListener(listener!);
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    if (listener != null){
      animation.removeListener(listener!);
    }
    super.dispose();
  }

  Widget buildLegend(String legendTitle, Color legendColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 11,
          margin: EdgeInsets.only(right: 5),
          decoration: BoxDecoration(color: legendColor, borderRadius: BorderRadius.all(Radius.circular(3))),
        ),
        Text(
          legendTitle,
          style: Theme.of(context).textTheme.subtitle2!.copyWith(fontSize: 12.0),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    CustomPaint paint = CustomPaint(
      painter: RadarMapPainter(widget.radarMap, textStyle: widget.textStyle),
    );

    /// 圆形背景下，定义图片旋转
    if (widget.image != null && widget.radarMap.shape == Shape.circle)
      img = Transform.rotate(
        angle: _angle / 180 * pi,
        child: Opacity(
          opacity: animation.value / 360 * 0.4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radarMap.radius),
            child: Image(
              image: widget.image!,
              width: widget.radarMap.radius * 2,
              height: widget.radarMap.radius * 2,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );

    var center = Transform.rotate(
      // 旋转动画
      angle: -_angle / 180 * pi,
      child: Transform.scale(
        // 缩放动画
        scale: 0.5 + animation.value / 360 / 2,
        child: SizedBox(
          width: widget.radarMap.radius * 2,
          height: widget.radarMap.radius * 2,
          child: paint,
        ),
      ),
    );

    return Container(
      width: MediaQuery.of(context).size.width,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          if (img != null && widget.radarMap.shape == Shape.circle) img,
          center,
          if (widget.isNeedDrawLegend)
            Positioned(
              top: 10,
              right: 5,
              child: Column(
                children: widget.radarMap.legend.map((item) => buildLegend(item.name, item.color)).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// canvas绘制
class RadarMapPainter extends CustomPainter {
  RadarMapModel radarMap;
  late Paint mRectFillPaint; //矩形填充画笔
  late Paint mLinePaint; // 线画笔
  late Paint mFillPaint; // 填充画笔
  late Paint mPointPaint; // 圆点
  TextStyle? textStyle;
  late Path mLinePath; // 短直线路径
  late int elementLength;

  RadarMapPainter(this.radarMap, {this.textStyle}) {
    mLinePath = Path();
    mLinePaint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.008 * radarMap.radius
      ..isAntiAlias = true;

    mFillPaint = Paint() //填充画笔
      ..strokeWidth = 0.05 * radarMap.radius
      ..color = Colors.black
      ..isAntiAlias = true;

    mRectFillPaint = Paint()
      ..color = radarMap.rectColor1
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    mPointPaint = Paint()
      ..color = radarMap.pointColor
      ..isAntiAlias = true;

    elementLength = radarMap.indicator.length;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(radarMap.radius, radarMap.radius); // 移动坐标系
    drawInnerCircle(canvas, size);
    drawInfoText(canvas);
    for (int i = 0; i < radarMap.legend.length; i++) {
      drawRadarMap(
          canvas,
          radarMap.data[i].data,
          radarMap.indicator.map((item) => item.maxValues).toList(),
          mFillPaint
            ..color = radarMap.legend[i].color.withAlpha(radarMap.alphaPercent)
            ..isAntiAlias = true);
      drawRadarPath(
          canvas,
          radarMap.data[i].data,
          radarMap.indicator.map((item) => item.maxValues).toList(),
          mFillPaint
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..color = radarMap.legend[i].color);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }

  /// 绘制内圈圆 || 内多边形、分割线
  drawInnerCircle(Canvas canvas, Size size) {
    double innerRadius = radarMap.radius; // 内圆半径
    if (radarMap.shape == Shape.circle) {
      // 绘制五个圆环
      for (int s = 5; s > 0; s--) {
        canvas.drawCircle(
          Offset(0, 0),
          innerRadius / 5 * s,
          mLinePaint
            ..color = s % 2 != 0 ? Color(0x772EBBC3) : Color(0x77FFFFFF)
            ..style = PaintingStyle.fill,
        );
      }
    } else {
      for (int count = 0; count <= 4; count++){
        double rectInnerRadius = innerRadius - innerRadius * (count / 4);
        Path mapPath = new Path();
        double angle = 0;
        double delta = 2 * pi / elementLength;
        mapPath.moveTo(0, -rectInnerRadius);
        for (int i = 0; i < elementLength; i++) {
          angle += delta;
          mapPath.lineTo(0 + rectInnerRadius * sin(angle), 0 - rectInnerRadius * cos(angle));
        }
        mapPath.close();
        canvas.drawPath(
          mapPath,
          mRectFillPaint
            ..color = count % 2 == 0 ? radarMap.rectColor1 : radarMap.rectColor2
            ..style = PaintingStyle.fill,
        );
      }
    }
    // 遍历画线
    for (var i = 0; i < elementLength; i++) {
      canvas.save();
      canvas.rotate(360 / elementLength * i.toDouble() / 180 * pi);
      mLinePath.moveTo(0, -innerRadius);
      mLinePath.relativeLineTo(0, innerRadius); //线的路径
      drawDashLine(canvas, radarMap.dashWidth);
      canvas.restore();
    }
    canvas.save();
    canvas.restore();
  }

  drawDashLine(Canvas canvas, int dashWidth){
    double innerRadius = radarMap.radius;
    double dashCount = innerRadius / (dashWidth * 2);
    for (int i = 0; i <= dashCount; i++){
      //加上dashWidth为了最后汇聚在一点上
      double startY = (-innerRadius + dashWidth) + i * dashWidth * 2;
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), mLinePaint);
    }
  }

  /// 绘制区域
  drawRadarMap(Canvas canvas, List<double> value, List<double> maxList, Paint mapPaint) {
    Path radarMapPath = Path();
    double step = radarMap.radius / elementLength; //每小段的长度
    radarMapPath.moveTo(0, -value[0] / (maxList[0] / elementLength) * step); //起点
    for (int i = 1; i < elementLength; i++) {
      double mark = value[i] / (maxList[i] / elementLength);
      var deg = pi / 180 * (360 / elementLength * i - 90);
      radarMapPath.lineTo(mark * step * cos(deg), mark * step * sin(deg));
    }
    radarMapPath.close();
    canvas.drawPath(radarMapPath, mapPaint);
  }

  /// 绘制边框
  drawRadarPath(Canvas canvas, List<double> value, List<double> maxList, Paint linePaint) {
    Path mradarPath = Path();
    double pointRadius = radarMap.pointRadius;
    double step = radarMap.radius / value.length; //每小段的长度
    double x = 0;
    double y = -value[0] / (maxList[0] / value.length) * step;
    mradarPath.moveTo(x, y);
    canvas.drawCircle(Offset(x, y), pointRadius, mPointPaint);
    for (int i = 1; i < value.length; i++) {
      double mark = value[i] / (maxList[i] / value.length);
      var deg = pi / 180 * (360 / value.length * i - 90);
      x = mark * step * cos(deg);
      y = mark * step * sin(deg);
      mradarPath.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), pointRadius, mPointPaint);
    }
    mradarPath.close();
    canvas.drawPath(mradarPath, linePaint);
  }

  /// 绘制文字
  void drawInfoText(Canvas canvas) {
    radarMap.textType == TextType.rotate ? drawRotateText(canvas) : drawNormalText(canvas, radarMap.textOffset);
  }

  void drawNormalText(Canvas canvas, double textOffset){
    double radius = radarMap.radius + textOffset;
    double angle = 0;
    double realAngle = 0; //用于角度判断，避免double的精度问题
    double realPi = 0; //用于角度判断，避免double的精度问题
    double delta = 2 * pi / elementLength;
    Paragraph paragraph;
    for (int i = 0; i < elementLength; i++) {
      angle += delta;
      paragraph = buildTextParagraph(radarMap.indicator[i].name);
      double x = 0 + radius * sin(angle);
      double y = 0 - radius * cos(angle);
      realAngle = double.parse(angle.toStringAsFixed(2));
      realPi = double.parse(pi.toStringAsFixed(2));
      if (0 < realAngle && realAngle < realPi){
        x += textOffset;
      }else if (realPi < realAngle && realAngle < 2 * realPi){
        x -= textOffset;
      }
      canvas.drawParagraph(paragraph, Offset(x - paragraph.width/2, y - paragraph.height / 2));
    }
  }

  void drawRotateText(Canvas canvas){
    double r2 = radarMap.radius + 2; //下圆半径
    for (int i = 0; i < elementLength; i++) {
      Offset offset;
      canvas.save();
      if (i != 0) {
        canvas.rotate(360 / elementLength * i / 180 * pi + pi);
        offset = Offset(-50, r2);
      } else {
        offset = Offset(-50, -r2 - textStyle!.fontSize! - 8);
      }
      drawText(
        canvas,
        radarMap.indicator[i].name,
        offset,
      );
      canvas.restore();
    }
  }

  /// 绘制文字 centerDraw leftDraw rightDraw 基于中点，基于左侧，基于右侧绘制
  drawText(Canvas canvas, String text, Offset offset) {
    var paragraph = buildTextParagraph(text);
    canvas.drawParagraph(paragraph, Offset(offset.dx, offset.dy));
  }

  Paragraph buildTextParagraph(
      String text,
      {
        // Color color = Colors.black,
        double maxWith = 100,
        // double fontSize,
        String? fontFamily,
        TextAlign textAlign = TextAlign.center,
        FontWeight fontWeight = FontWeight.normal,
      }){
    var paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontFamily: textStyle?.fontFamily,
        textAlign: textAlign,
        fontSize: textStyle?.fontSize ?? radarMap.radius * 0.16,
        fontWeight: textStyle?.fontWeight,
      ),
    );
    paragraphBuilder.pushStyle(ui.TextStyle(color: textStyle!.color ?? Colors.black, textBaseline: ui.TextBaseline.alphabetic));
    paragraphBuilder.addText(text);
    var paragraph = paragraphBuilder.build();
    print("paragraph.width:${paragraph.width}");
    paragraph.layout(ui.ParagraphConstraints(width: maxWith));
    return paragraph;
  }
}
