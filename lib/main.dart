import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart' show DateFormat;
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_sound/flutter_sound.dart';

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
  bool draweroff = true;
  bool audioff = true;
  List<Map> messages = [];
  GlobalKey anchorKey = GlobalKey();
  Offset offset = Offset(0.0, 0.0);

  bool _isRecording = false;
  bool _isPlaying = false;
  StreamSubscription _recorderSubscription;
  StreamSubscription _dbPeakSubscription;
  StreamSubscription _playerSubscription;
  FlutterSound flutterSound;

  String _recorderTxt = '00:00:00';
  String _recorderTxt1 = '00:00';
  String _playerTxt = '00:00:00';
  double _dbLevel;

  double slider_current_position = 0.0;
  double max_duration = 1.0;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    flutterSound = new FlutterSound();
    flutterSound.setSubscriptionDuration(0.01);
    flutterSound.setDbPeakLevelUpdate(0.8);
    flutterSound.setDbLevelEnabled(true);
    initializeDateFormatting();
  }

  Future<void> sendText(String content) async {
    Map send = {
      "content": content,
      "type": -1,
    };
    textEditingController.clear();
    messages.add(send);
    _streamController.sink.add(messages);
  }

  Future<void> sendAudio() async {
    Map send = {
      "content": _recorderTxt1,
      "type": -2,
    };
    messages.add(send);
    _streamController.sink.add(messages);
  }

  void startRecorder() async {
    try {
      String path = await flutterSound.startRecorder(null, bitRate: 64000);
      print('startRecorder: $path');

      _recorderSubscription = flutterSound.onRecorderStateChanged.listen((e) {
        DateTime date = new DateTime.fromMillisecondsSinceEpoch(
            e.currentPosition.toInt(),
            isUtc: true);
        String txt = DateFormat('mm:ss:SS', 'en_GB').format(date);
        this._recorderTxt1 = txt.substring(3, 8);
        this.setState(() {
          this._recorderTxt = txt.substring(0, 8);
        });
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
    super.dispose();
  }

  Future<bool> onBackPress() async {
    if (draweroff == false) {
      setState(() {
        draweroff = true;
      });
    } else {
      Navigator.pop(context);
    }

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
              left: 30,
              bottom: 120,
              width: 40,
              height: 40,
              child: Offstage(
                offstage: audioff,
                child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(20.0)),
                    child: InkWell(
                      radius: 20,
                      onTap: () {
                        print('取消发送');
                        this.stopRecorder();
                        setState(() {
                          audioff = true;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        // color: Colors.black12,
                        child: Center(
                          child: Icon(
                            Icons.replay,
                            size: 23,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    )),
              ),
            ),
            Positioned(
                left: 115,
                bottom: 0,
                right: 0,
                height: 50,
                child: Offstage(
                  offstage: audioff,
                  child: InkWell(
                    onTap: () {
                      print('移动手指');
                      this.stopRecorder();
                      setState(() {
                        audioff = true;
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
                          '移动手指锁住-->$_recorderTxt',
                          style: TextStyle(color: Colors.black38, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                )),
            GestureDetector(
              onTap: () {
                this.stopRecorder();
                setState(() {
                  audioff = true;
                });
              },
              onTapDown: (T) {
                RenderBox renderBox =
                    anchorKey.currentContext.findRenderObject();
                offset =
                    renderBox.localToGlobal(Offset(0.0, renderBox.size.height));
                print(offset.dx);
                print(offset.dy);
                this.startRecorder();
                setState(() {
                  audioff = false;
                });
              },
              onTapUp: (T) {
                this.stopRecorder();
                setState(() {
                  audioff = true;
                });
                sendAudio();
              },
              child: CircleAvatar(
                radius: audioff ? 25 : 50,
                backgroundColor: audioff ? Colors.white : Color(0x306b6aba),
                child: Icon(Icons.mic, size: 30.0, color: Color(0xFF6b6aba)),
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
                Text('${detail['content']}"'),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16.0),
                    onTap: () async {
                      if (_isPlaying) {
                        await stopPlayer();
                        _isPlaying = false;
                        startPlayer();
                      } else {
                        startPlayer();
                        _isPlaying = true;
                      }
                    },
                    child: Container(
                      height: 44,
                      width: 180,
                      alignment: Alignment.centerRight,
                      color: Colors.black12,
                      child: Text(
                        '           )))·    ',
                        style: TextStyle(fontSize: 16),
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
