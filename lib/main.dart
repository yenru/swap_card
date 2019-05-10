import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swap Cards',
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: CardSwapper())),
    );
  }
}

class CardSwapper extends StatefulWidget {
  List<CardView> cardList = [
    CardView(Icons.star),
    CardView(Icons.favorite),
    CardView(Icons.extension),
    CardView(Icons.pets),
    CardView(Icons.settings),
  ];

  @override
  _CardSwapperState createState() => _CardSwapperState();
}

class _CardSwapperState extends State<CardSwapper>
    with SingleTickerProviderStateMixin {
  double scrollPercent = 0.0;
  Offset startDrag;
  AnimationController _controller;

  bool isForward = true;  //滑動的方向
  Swapper swapper;        //動畫實作物件
  int frontIndex = 0;     //目前畫面上呈現的卡片index

  @override
  void initState() {
    super.initState();
    swapper = new Swapper(
      width: 180,   //動畫移動範圍的最大寬度
      front: widget.cardList.first,   //目前在畫面上的卡片
      medium: widget.cardList[1]      //下一張卡片
    );

    _controller = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    )
      ..addListener(() {  //動畫進行中
        setState(() {     //重繪Swapper物件
          scrollPercent = _controller.value;
        });
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {  //動畫完成時
          int len = widget.cardList.length;

          int tempIndex = frontIndex;   //準備播放交換動畫的卡片index
          if (isForward)
            tempIndex++;
          else
            tempIndex--;

          //確認卡片index在範圍內
          if (tempIndex >= 0 && tempIndex < len) {
            setState(() {
              frontIndex = tempIndex;
              swapper.set(  //重新設定Swapper物件中的三張卡片
                  front: widget.cardList[frontIndex],
                  medium: frontIndex + 1 < len
                      ? widget.cardList[frontIndex + 1]
                      : null,
                  back: frontIndex - 1 >= 0
                      ? widget.cardList[frontIndex - 1]
                      : null);
            });
            _controller.reset();  //重置控制器，回到未播放的狀態
          }
        }
      });
  }

  void _onPanStart(DragStartDetails details) {
    _controller.stop(); //終止播放中的動畫
    startDrag = details.globalPosition;   //記錄開始拖移的位置
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final currDrag = details.globalPosition;
    final dragDistance = currDrag.dx - startDrag.dx;
    final dragPercent = dragDistance / context.size.width;

    //拖移% 只在 -1 到 1 之間有效
    if (dragPercent >= -1 && dragPercent <= 1) {
      setState(() {   //決定拖移的方向後重繪
        if (dragPercent >= 0) {
          scrollPercent = dragPercent;
          isForward = false;
        } else {
          scrollPercent = -dragPercent;
          isForward = true;
        }
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _controller.forward(from: scrollPercent);   //將動畫繼續播放完畢
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onPanStart,
      onHorizontalDragUpdate: _onPanUpdate,
      onHorizontalDragEnd: _onPanEnd,
      behavior: HitTestBehavior.translucent,
      child: swapper.build(scrollPercent, isForward),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class CardView extends StatelessWidget {
  final IconData iconImage;
  CardView(this.iconImage);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Icon(
        iconImage,
        size: 150,
      ),
    );
  }
}

enum CardSeq { front, back }

class Swapper {
  //Swapper每次最多準備三張卡片，提供目前卡片與前後一張卡片的切換
  final double width;   //動畫移動範圍的最大寬度
  Widget front;         //目前在畫面上的卡片
  Widget medium;        //下一張卡片
  Widget back;          //上一張卡片

  //stack陣列中的先後順序會影響卡片上下的視覺效果
  //因此動畫進行到卡片上下切換時，要將stack位置調換
  static final stackSwitchPoint = 0.5;
  //三角函數的週期為±pi，縮為±0.5
  final thRange = pi / stackSwitchPoint;
  //動畫往前放大，或往後縮小時的最大縮放比率
  final scaleRate = 0.2;

  double tx;                //x軸最大transform範圍
  final double tz = 10;     //z軸最大transform範圍

  Swapper({@required this.width, @required this.front, this.medium, this.back})
      : assert(width != null),
        assert(front != null) {
    //x軸最大位移距離應為 width / 2
    //由於cos範圍在±1之間距離為2，因此後面計算時要除2，先提到前面做
    //實際公式應為 tx = width / 2 / 2
    tx = width / 2 * stackSwitchPoint;
  }

  //提供更新準備中的三張卡片
  void set({Widget front, Widget medium, Widget back}) {
    this.front = front ?? this.front;
    this.medium = medium;
    this.back = back;
  }

  //建立影格畫面
  //position 表示動畫播放的位置，為0-1的數值
  //isForward 決定卡片是和 false上一張 true下一張做切換
  Widget build(double position, [bool isForward = true]) {
    Widget top, bottom;
    //若準備切換的卡片不存在，回傳當前卡片
    if ((isForward && medium == null) || (!isForward && back == null))
      return front;

    //準備目前的卡片
    Widget frontTransform = Transform(
        transform: go(CardSeq.front, position, isForward),
        alignment: FractionalOffset.center,
        child: front);
    //準備切換的卡片
    Widget backTransform = Transform(
        transform: go(CardSeq.back, position, isForward),
        alignment: FractionalOffset.center,
        child: (isForward ? medium : back));

    //動畫進行到stackSwitchPoint時，將stack順序調換
    if (position > stackSwitchPoint) {
      top = backTransform;
      bottom = frontTransform;
    } else {
      top = frontTransform;
      bottom = backTransform;
    }

    //先放入stack的物件會呈現在下面
    return Stack(
      children: [bottom, top],
    );
  }

  //回傳卡片目前的3D位置
  //seq表示前面或後面的卡片，動畫進行中只會用到2張卡片
  Matrix4 go(CardSeq seq, double pos, bool isForward) {
    //將0-1的範圍轉成±0.5
    pos = pos - stackSwitchPoint;

    //pos*thRange的範圍會落在±pi
    //xp的範圍在±1之間
    double xp = cos(pos * thRange);
    //xp只需要正數0-1的值，因此+1調整xp的範圍到0-2之間後除2
    //原始公式應為 tx * (xp + 1) / 2，將除2提到tx初始化先做
    double x = tx * (xp + 1);

    //sin的週期符合z軸需要，不必微調
    double zp = sin(pos * thRange);
    double z = tz * zp;

    //縮放所需的週期函數與z軸相同
    double sp = scaleRate * zp;

    if (seq == CardSeq.front) {
      //與下一張切換時，目前的卡片往左移動(-x)
      //與上一張切換時，目前的卡片往右移動(x)
      double xMove = isForward ? -x : x;
      //前面的卡片z與sp固定由正轉負
      //z與sp原始值是由負轉正，因此加負號
      return new Matrix4.translationValues(xMove, 0, -z)..scale(1 - sp);
    }
    if (seq == CardSeq.back) {
      //與下一張切換時，下一張卡片往右移動(x)
      //與上一張切換時，上一張卡片往左移動(-x)
      double xMove = isForward ? x : -x;
      //後面的卡片z與sp固定由負轉正
      return new Matrix4.translationValues(xMove, 0, z)..scale(1 + sp);
    }
    return new Matrix4.translationValues(0, 0, 0);
  }
}
