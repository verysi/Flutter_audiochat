import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart' show DateFormat;
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:vibrate/vibrate.dart';

void main() {
  runApp(
    new MaterialApp(
      title: '语音消息',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new audiochat(),
    ),
  );
}

class audiochat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('语音消息'),
      ),
      body: audiodemo(),
    );
  }
}

class audiodemo extends StatefulWidget {
  @override
  audiodemoState createState() => new audiodemoState();
}

class audiodemoState extends State<audiodemo>
    with SingleTickerProviderStateMixin {
  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();
  final StreamController<List<dynamic>> _streamController =
      StreamController<List<dynamic>>();
  final FocusNode focusNode = new FocusNode();
  bool audioff = true;
  List<Map> messages = [];
  GlobalKey anchorKey = GlobalKey();
  Offset offset = Offset(0.0, 0.0);

  Animation animationAudio;
  AnimationController controller;

  bool istapUp = true;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _canVibrate = true;
  StreamSubscription _recorderSubscription;
  StreamSubscription _dbPeakSubscription;
  StreamSubscription _playerSubscription;
  FlutterSound flutterSound;

  String _recorderTxt = '00:00:00';
  String _playerTxt = '00:00:00';
  double _dbLevel;

  double slider_current_position = 0.0;
  double max_duration = 1.0;
  int _recordint = 0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    flutterSound = new FlutterSound();
    flutterSound.setSubscriptionDuration(0.01);
    flutterSound.setDbPeakLevelUpdate(0.8);
    flutterSound.setDbLevelEnabled(true);
    initializeDateFormatting();
    initVibrate();

    controller = new AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 75),
    );
//    final Animation curve =
//        new CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    animationAudio = new Tween(begin: 0.0, end: 1.0).animate(controller)
      ..addStatusListener((state) {
        if (state == AnimationStatus.completed) {
          controller.stop();
        }
      });
  }

  initVibrate() async {
    bool canVibrate = await Vibrate.canVibrate;
    setState(() {
      _canVibrate = canVibrate;
      _canVibrate
          ? print("This device can vibrate")
          : print("This device cannot vibrate");
    });
  }

  //发送文字消息
  Future<void> sendText(String content) async {
    Map sendmessage = {
      "content": content,
      "type": -1,
    };
    textEditingController.clear();
    messages.add(sendmessage);
    _streamController.sink.add(messages);
  }

  //发送语音消息
  Future<void> sendAudio() async {
    await this.delayStopRecorder(100);
    if (_recordint == 0) {
      print('消息太短');
    } else {
      Map sendmessage = {
        "content": _recordint,
        "type": -2,
      };
      messages.add(sendmessage);
      _streamController.sink.add(messages);
    }
  }

  //录音时间转成整形
  int toRecordInt(String RecordText) {
    int x = 1;
    if (RecordText.substring(3, 4) == '0') {
      if (int.parse(RecordText.substring(6, 7)) < 5) {
        x = int.parse(RecordText.substring(4, 5));
      } else {
        x = int.parse(RecordText.substring(4, 5)) + 1;
      }
    } else {
      if (int.parse(RecordText.substring(6, 7)) < 5) {
        x = int.parse(RecordText.substring(3, 5));
      } else {
        x = int.parse(RecordText.substring(3, 5)) + 1;
      }
    }

    return x;
  }

  int _lastClickTime = 0;
  //语音按键优化,防止用户疯狂点击引发的灾难性bug
  void ontapdelay() async {
    int nowTime = new DateTime.now().millisecondsSinceEpoch;
    int timentervalI = nowTime - _lastClickTime;
    print('按键时间间隔：$timentervalI');
    if (_lastClickTime == 0 || nowTime - _lastClickTime > 1000) {
      setState(() {
        audioff = false;
        controller.reset();
        controller.forward();
      });
      _lastClickTime = new DateTime.now().millisecondsSinceEpoch;
      if (_canVibrate) {
        Vibrate.feedback(FeedbackType.medium);
      }
      if (_isRecording == true) {
        this.stopRecorder();
      }
      this.startRecorder();
    }
  }

  //停止录音
  void startRecorder() async {
    try {
      String path = await flutterSound.startRecorder(null, bitRate: 64000);
      print('startRecorder: $path');

      _recorderSubscription = flutterSound.onRecorderStateChanged.listen((e) {
        DateTime date = new DateTime.fromMillisecondsSinceEpoch(
            e.currentPosition.toInt(),
            isUtc: true);
        String txt = DateFormat('mm:ss:SS', 'en_GB').format(date);
        //this._recorderTxt1 = txt.substring(3, 8);
        this.setState(() {
          this._recorderTxt = txt.substring(3, 8);
          _recordint = toRecordInt(txt.substring(0, 8));
        });

        if (_recordint == 59) {
          this.delayStopRecorder(500);
        }
      });
      _dbPeakSubscription =
          flutterSound.onRecorderDbPeakChanged.listen((value) {
        print("got update -> $value");
        setState(() {
          this._dbLevel = value;
        });
      });

      this.setState(() {
        this._isRecording = true;
      });
    } catch (err) {
      print('startRecorder error: $err');
    }
  }

  void stopRecorder() async {
    try {
      String result = await flutterSound.stopRecorder();
      print('stopRecorder: $result');

      if (_recorderSubscription != null) {
        _recorderSubscription.cancel();
        _recorderSubscription = null;
      }
      if (_dbPeakSubscription != null) {
        _dbPeakSubscription.cancel();
        _dbPeakSubscription = null;
      }

      this.setState(() {
        this._isRecording = false;
      });
    } catch (err) {
      print('stopRecorder error: $err');
    }
  }

  //延时处理用户快速点击引发录音bug
  void delayStopRecorder(int delaytime) async {
    await Future.delayed(
        Duration(milliseconds: delaytime), () => this.stopRecorder());
  }

  //开始播放
  void startPlayer() async {
    String path = await flutterSound.startPlayer(null);
    await flutterSound.setVolume(1.0);
    print('startPlayer: $path');

    try {
      _playerSubscription = flutterSound.onPlayerStateChanged.listen((e) {
        if (e != null) {
          slider_current_position = e.currentPosition;
          max_duration = e.duration;

          DateTime date = new DateTime.fromMillisecondsSinceEpoch(
              e.currentPosition.toInt(),
              isUtc: true);
          String txt = DateFormat('mm:ss:SS', 'en_GB').format(date);
          this.setState(() {
            this._isPlaying = true;
            this._playerTxt = txt.substring(0, 8);
          });
        }
      });
    } catch (err) {
      print('error: $err');
    }
  }

  //停止播放
  void stopPlayer() async {
    try {
      String result = await flutterSound.stopPlayer();
      print('stopPlayer: $result');
      if (_playerSubscription != null) {
        _playerSubscription.cancel();
        _playerSubscription = null;
      }

      this.setState(() {
        this._isPlaying = false;
      });
    } catch (err) {
      print('error: $err');
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    controller.dispose();
    super.dispose();
  }

  Future<bool> onBackPress() async {
    Navigator.pop(context);
    //return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onBackPress,
      child: Stack(
          overflow: Overflow.clip,
          alignment: AlignmentDirectional.bottomStart,
          children: <Widget>[
            Column(children: <Widget>[
              buildListMessage(),
              buildInput(),
            ]),
            Positioned(
              left: 28,
              bottom: 112,
              width: 40,
              height: 40,
              child: Offstage(
                offstage: audioff,
                child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(20.0)),
                    child: InkWell(
                      radius: 20,
                      onTap: () async {
                        print('取消发送');
                        await this.stopRecorder();
                        setState(() {
                          audioff = true;
                          controller.stop();
                          controller.reverse();
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        // color: Colors.black12,
                        child: Center(
                          child: Icon(
                            Icons.replay,
                            size: 22,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    )),
              ),
            ),
            Positioned(
                left: 125,
                bottom: 0,
                right: 0,
                height: 50,
                child: Offstage(
                  offstage: audioff,
                  child: InkWell(
                    onTap: () {
                      // await this.stopRecorder();
                      setState(() {
                        audioff = true;
                        controller.stop();
                        controller.reverse();
                      });
                      sendAudio();
                    },
                    child: Container(
                      //color: Colors.white,
                      decoration: BoxDecoration(
                        borderRadius: new BorderRadius.circular((12.0)),
                        border:
                            new Border.all(color: Colors.black38, width: 0.5),
                        color: Colors.white,
                      ),
                      child: Center(
                        child: Text(
                          '移动手指锁住-->  $_recorderTxt',
                          style: TextStyle(color: Colors.black38, fontSize: 17),
                        ),
                      ),
                    ),
                  ),
                )),
            GestureDetector(
              onTapDown: (T) {
                if (audioff) {
                  this.ontapdelay();
                } else {
                  setState(() {
                    audioff = true;
                  });
                  sendAudio();
                }
              },
              onTapUp: (T) {
                if (_isRecording) {
                  if (audioff == false) {
                    int nowTime = new DateTime.now().millisecondsSinceEpoch;
                    setState(() {
                      audioff = true;
                      controller.stop();
                      controller.reverse();
                    });
                    if (nowTime - _lastClickTime > 500) {
                      sendAudio();
                    } else {
                      this.delayStopRecorder(500);
                    }
                  }
                }
              },
              child: audioff
                  ? CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child:
                          Icon(Icons.mic, size: 30.0, color: Color(0xFF6b6aba)),
                    )
                  : AnimatedBuilder(
                      animation: animationAudio,
                      builder: (_, child) {
                        return CircleAvatar(
                          radius: 24 * (1 + animationAudio.value),
                          backgroundColor: Color(0x306b6aba),
                          child: Icon(Icons.mic,
                              size: 32.0, color: Color(0xFF6b6aba)),
                        );
                      },
                    ),
            ),
          ]),
    );
  }

  buildInput() => Container(
        width: double.infinity,
        height: 50.0,
        decoration: new BoxDecoration(
            border: new Border(
                top: new BorderSide(
              color: audioff ? Colors.black12 : Colors.white,
              width: audioff ? 0.5 : 0,
            )),
            color: Colors.white),
        child: Row(
          children: <Widget>[
            new Container(
              width: 60,
              //margin: new EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(child: Text('')),
            ),
            Flexible(
              child: Container(
                // margin: new EdgeInsets.symmetric(horizontal: 1.0),
                child: Offstage(
                  offstage: !audioff,
                  child: TextField(
                    style: TextStyle(color: Colors.black54, fontSize: 18.0),
                    controller: textEditingController,
                    decoration: InputDecoration.collapsed(
                      hintText: '发消息',
                      hintStyle: TextStyle(color: Colors.black38),
                    ),
                    focusNode: focusNode,
                  ),
                ),
              ),
            ),
            Offstage(
              offstage: !audioff,
              child: Material(
                child: new Container(
                  margin: new EdgeInsets.symmetric(horizontal: 8.0),
                  child: new IconButton(
                    icon: new Icon(Icons.send, key: anchorKey),
                    onPressed: () => sendText(textEditingController.text),
                    color: Colors.blue,
                  ),
                ),
                color: Colors.white,
              ),
            ),
          ],
        ),
      );

  buildListMessage() => Flexible(
        child: StreamBuilder(
          stream: _streamController.stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: null,
              );
            } else {
              return ListView.builder(
                padding: EdgeInsets.all(10.0),
                itemBuilder: (context, index) => buildItem(
                    index, snapshot.data[snapshot.data.length - index - 1]),
                itemCount: snapshot.data.length,
                reverse: true,
                controller: listScrollController,
              );
            }
          },
        ),
      );

  Widget buildItem(int index, Map detail) {
    switch (detail['type']) {
      case -1:
        return Padding(
          padding: const EdgeInsets.only(right: 0),
          child: Container(
            alignment: Alignment.centerRight,
            margin: EdgeInsets.only(
              right: 5,
              top: 15,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/rchat.png'),
                      centerSlice: Rect.fromLTWH(15, 10, 20, 3),
                    ),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 1.0,
                    maxWidth: 270.0,
                    minHeight: 1.0,
                  ),
                  padding: EdgeInsets.fromLTRB(20.0, 10.0, 15.0, 15.0),
                  child: Text(
                    '${detail['content']}',
                    style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w400,
                        color: Colors.black),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 30, left: 5),
                  child: CircleAvatar(
                    radius: 22.0,
                    backgroundImage: AssetImage('assets/images/face1.jpeg'),
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case -2:
        double Length = 0;
        if (detail['content'] > 11) {
          Length = 180;
        } else {
          Length = 90 * (1 + detail['content'] / 11);
        }

        return Padding(
          padding: const EdgeInsets.only(right: 0),
          child: Container(
            alignment: Alignment.centerRight,
            margin: EdgeInsets.only(
              right: 5,
              top: 15,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  '${detail['content']}" ',
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.black38,
                      fontWeight: FontWeight.w700),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16.0),
                    onTap: () async {
                      if (_isPlaying) {
                        await stopPlayer();
                        startPlayer();
                      } else {
                        startPlayer();
                      }
                    },
                    child: Container(
                      height: 42,
                      width: Length,
                      alignment: Alignment.centerRight,
                      color: Colors.black12,
                      child: Text(
                        '           )))·    ',
                        style: TextStyle(fontSize: 13, color: Colors.black38),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: CircleAvatar(
                    radius: 22.0,
                    backgroundImage: AssetImage('assets/images/face1.jpeg'),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}

