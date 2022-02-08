import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:provider/provider.dart';
import 'package:wordpress_app/blocs/comment_bloc.dart';
import 'package:wordpress_app/blocs/user_bloc.dart';
import 'package:wordpress_app/config/config.dart';
import 'package:wordpress_app/models/comment.dart';
import 'package:wordpress_app/models/jwt_status.dart';
import 'package:wordpress_app/pages/login.dart';
import 'package:wordpress_app/services/app_service.dart';
import 'package:wordpress_app/services/auth_service.dart';
import 'package:wordpress_app/services/wordpress_service.dart';
import 'package:wordpress_app/utils/colors.dart';
import 'package:wordpress_app/utils/dialog.dart';
import 'package:wordpress_app/utils/empty_icon.dart';
import 'package:wordpress_app/utils/empty_image.dart';
import 'package:wordpress_app/utils/loading_card.dart';
import 'package:wordpress_app/utils/next_screen.dart';
import 'package:wordpress_app/utils/snacbar.dart';
import 'package:html/parser.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:wordpress_app/widgets/html_body.dart';

class CommentsPage extends StatefulWidget {
  final int categoryId;
  final int? postId;
  const CommentsPage({Key? key, required this.postId, required this.categoryId}) : super(key: key);

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  var formKey = GlobalKey<FormState>();
  var scaffoldKey = GlobalKey<ScaffoldState>();
  var textFieldCtrl = TextEditingController();
  Future? _fetchComments;
  bool _isSomethingChanging = false;

  Future _handlePostComment(int? id) async {
    final UserBloc ub = Provider.of<UserBloc>(context, listen: false);
    FocusScope.of(context).requestFocus(new FocusNode());
    if (textFieldCtrl.text.isEmpty) {
      openSnacbar(scaffoldKey, "Comment shouldn't be empty!");
    } else {
      AppService().checkInternet().then((hasInternet) async {
        if (hasInternet!) {
          setState(() => _isSomethingChanging = true);
          await WordPressService()
              .postComment(id, ub.name, ub.email!, textFieldCtrl.text)
              .then((bool isSuccesfull) {
            if (isSuccesfull) {
              textFieldCtrl.clear();
              setState(() => _isSomethingChanging = false);
              openDialog(context, 'comment success title'.tr(),
                  'comment success description'.tr());
            } else {
              setState(() => _isSomethingChanging = false);
              openDialog(context, 'Comment posting error!', 'Please try again');
            }
          });
        }
      });
    }
  }

  Future _handleDeleteComment(int? id, String? commentUser) async {
    final userName = context.read<UserBloc>().name;
    if (userName == commentUser) {
      AppService().checkInternet().then((hasInternet) {
        if (!hasInternet!) {
          openSnacbar(scaffoldKey, 'no internet'.tr());
        } else {
          setState(() => _isSomethingChanging = true);
          AuthService().customAuthenticationViaJWT().then((JwtStatus? status) {
            if (status!.isSuccessfull == false) {
              setState(() => _isSomethingChanging = false);
              openSnacbar(scaffoldKey, 'Failed to authenticate the user');
            } else {
              WordPressService()
                  .deleteCommentById(status.urlHeader, id)
                  .then((value) {
                if (value) {
                  setState(() => _isSomethingChanging = false);
                  _onRefresh();
                } else {
                  setState(() => _isSomethingChanging = false);
                  openSnacbar(scaffoldKey, 'Error on deleteing the comment');
                }
              });
            }
          });
        }
      });
    } else {
      openSnacbar(scaffoldKey, "you can't delete others comment".tr());
    }
  }

  Future _handleUpdateComment(
      int? id, String? commentUser, String newComment) async {
    await AppService().checkInternet().then((hasInternet) async {
      if (!hasInternet!) {
        openSnacbar(scaffoldKey, 'no internet'.tr());
      } else {
        setState(() => _isSomethingChanging = true);
        await AuthService()
            .customAuthenticationViaJWT()
            .then((JwtStatus? status) async {
          if (status!.isSuccessfull == false) {
            setState(() => _isSomethingChanging = false);
            openSnacbar(scaffoldKey, 'Failed to authenticate the user');
          } else {
            await WordPressService()
                .updateCommentById(status.urlHeader, id, newComment)
                .then((value) {
              if (value) {
                setState(() => _isSomethingChanging = false);
                _onRefresh();
              } else {
                setState(() => _isSomethingChanging = false);
                openSnacbar(scaffoldKey, 'Error on deleteing the comment');
              }
            });
          }
        });
      }
    });
  }

  void openUpdateCommentDialog(String? oldComment, int? id, String? commentUser) {
    final userName = context.read<UserBloc>().name;
    if (userName == commentUser) {
      showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            var _textfieldCtrl = TextEditingController();
            _textfieldCtrl.text =
                HtmlUnescape().convert(parse(oldComment).documentElement!.text);
            return AlertDialog(
              scrollable: false,
              contentPadding: EdgeInsets.fromLTRB(20, 30, 20, 20),
              content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    TextField(
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      controller: _textfieldCtrl,
                      maxLines: 6,
                    )
                  ]),
              actions: [
                TextButton(
                  child: Text('Close'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  child: Text('update').tr(),
                  onPressed: () async {
                    _handleUpdateComment(id, commentUser, _textfieldCtrl.text);
                    Navigator.pop(context);
                  },
                )
              ],
            );
          });
    } else {
      openSnacbar(scaffoldKey, "you can't edit others comment".tr());
    }
  }

  @override
  void initState() {
    Future.microtask(() => context.read<CommentsBloc>().getFlagList());
    _fetchComments = WordPressService().fetchCommentsById(widget.postId);
    super.initState();
  }

  _onRefresh() async {
    setState(() {
      _fetchComments = WordPressService().fetchCommentsById(widget.postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      key: scaffoldKey,
      appBar: AppBar(
        title: Text('comments').tr(),
        elevation: 1,
        titleSpacing: 0,
        centerTitle: false,
        actions: [
          IconButton(
              padding: EdgeInsets.only(right: 10),
              icon: Icon(
                Feather.refresh_cw,
                size: 20,
              ),
              onPressed: _onRefresh),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: FutureBuilder(
                    future: _fetchComments,
                    initialData: [],
                    builder: (BuildContext context, AsyncSnapshot snapshot) {
                      switch (snapshot.connectionState) {
                        case ConnectionState.none:
                        case ConnectionState.active:
                        case ConnectionState.waiting:
                          return _LoadingWidget();
                        case ConnectionState.done:
                        default:
                          if (snapshot.hasError || snapshot.data == null) {
                            return EmptyPageWithIcon(
                              icon: Icons.error,
                              title: 'Error on getting data',
                            );
                          } else if (snapshot.data.isEmpty) {
                            return EmptyPageWithImage(
                              image: Config.commentImage,
                              title: 'no comments found'.tr(),
                              description: 'be the first to comment'.tr(),
                            );
                          }

                          return _buildCommentList(snapshot.data);
                      }
                    }),
              ),
              Divider(
                height: 1,
                color: Colors.grey[500],
              ),
              _bottomWidget(context)
            ],
          ),
          !_isSomethingChanging
              ? Container()
              : Align(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(),
                )
        ],
      ),
    );
  }

  Widget _bottomWidget(BuildContext context) {
    if (context.watch<UserBloc>().isSignedIn == false)
      return InkWell(
        child: Container(
          padding: EdgeInsets.all(15),
          alignment: Alignment.topCenter,
          height: 70,
          decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          child: Text(
            'login to make comments',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ).tr(),
        ),
        onTap: () => nextScreenPopup(
            context,
            LoginPage(
              popUpScreen: true,
            )),
      );
    else
      return SafeArea(
        bottom: true,
        top: false,
        child: Container(
          color: Theme.of(context).backgroundColor,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 65,
                  padding:
                      EdgeInsets.only(top: 8, bottom: 10, right: 5, left: 20),
                  child: Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryVariant,
                        borderRadius: BorderRadius.circular(25)),
                    child: TextFormField(
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                      decoration: InputDecoration(
                        errorStyle: TextStyle(fontSize: 0),
                        contentPadding: EdgeInsets.only(left: 15, right: 10),
                        border: InputBorder.none,
                        hintText: 'write a comment'.tr(),
                      ),
                      controller: textFieldCtrl,
                    ),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.only(right: 10),
                icon: Icon(
                  Icons.send,
                  size: 25,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                onPressed: () => _handlePostComment(widget.postId),
              )
            ],
          ),
        ),
      );
  }

  Widget _buildCommentList(snap) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(15, 15, 10, 30),
      itemCount: snap.length,
      physics: AlwaysScrollableScrollPhysics(),
      separatorBuilder: (ctx, idx) => SizedBox(
        height: 15,
      ),
      itemBuilder: (BuildContext context, int index) {
        CommentModel d = snap[index];
        return InkWell(
          child: Container(
              child: Row(
            children: <Widget>[
              Container(
                alignment: Alignment.bottomLeft,
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: _getRandomColor(),
                  child: Text(
                    d.author![0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                  //backgroundImage: CachedNetworkImageProvider(d[index].avatar),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      margin: EdgeInsets.only(
                          left: 8, top: 10, right: 5, bottom: 3),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryVariant,
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                d.author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600),
                              ),

                              _menuPopUp(d),
                            ],
                          ),
                          SizedBox(
                            height: 5,
                          ),

                          _isCommentFlagged(d.id)
                          ? Container(child: Text('comment flagged').tr(),)
                          : HtmlBody(
                                  content: d.content!,
                                  isVideoEnabled: true,
                                  isimageEnabled: true,
                                  isIframeVideoEnabled: true,
                                  textPadding: 0.0,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 15),
                      child: Text(
                        d.date!,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600]),
                      ),
                    )
                  ],
                ),
              ),
            ],
          )),
        );
      },
    );
  }

  PopupMenuButton<dynamic> _menuPopUp(CommentModel d) {
    return PopupMenuButton(
        padding: EdgeInsets.all(0),
        child: Icon(
          CupertinoIcons.ellipsis,
          size: 18,
        ),
        itemBuilder: (BuildContext context) {
          return <PopupMenuItem>[
            PopupMenuItem(
              child: Text('update comment').tr(),
              value: 'update',
            ),
            

            _isCommentFlagged(d.id)
            ? PopupMenuItem(
              child: Text('unflag comment').tr(),
              value: 'unflag',
            )
            : PopupMenuItem(
              child: Text('flag comment').tr(),
              value: 'flag',
            ),
            
            PopupMenuItem(
              child: Text('delete').tr(),
              value: 'delete',
            ),
            PopupMenuItem(
              child: Text('report').tr(),
              value: 'report',
            )
          ];
        },
        onSelected: (dynamic value) async{
          if (value == 'update') {
            openUpdateCommentDialog(d.content, d.id, d.author);
          }else if (value == 'flag') {
            await context.read<CommentsBloc>().addToFlagList(context, widget.categoryId, widget.postId!, d.id!);
            _onRefresh();
          }else if (value == 'unflag') {
            await context.read<CommentsBloc>().removeFromFlagList(context, widget.categoryId, widget.postId!, d.id!);
            _onRefresh();
          }else if (value == 'report') {
            //fake report
            openDialog(context, 'report-info'.tr(), '');
          }else {
            _handleDeleteComment(d.id, d.author);
          }
        });
  }


  bool _isCommentFlagged (int? commentId){
    final cb = context.read<CommentsBloc>();
    final flagId = "${widget.categoryId}-${widget.postId}-$commentId";
    if(cb.flagList.contains(flagId)){
      return true;
    }else{
      return false;
    }
  }

  Color? _getRandomColor() {
    return (ColorList().randomColors..shuffle()).first;
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(15),
      itemCount: 12,
      separatorBuilder: (ctx, idx) => SizedBox(
        height: 15,
      ),
      itemBuilder: (BuildContext context, int index) {
        return Container(
            margin: EdgeInsets.all(0),
            child: Row(
              children: <Widget>[
                Container(
                  alignment: Alignment.bottomLeft,
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                Flexible(
                  child: Container(
                    margin: EdgeInsets.only(left: 10, top: 10, right: 5),
                    child: LoadingCard(
                      height: 90,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                )
              ],
            ));
      },
    );
  }
}
