import 'dart:async';

import 'package:GymStats/src/model/app_user.dart';
import 'package:GymStats/src/model/app_user_event.dart';
import 'package:GymStats/src/model/user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUserBloc {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _userCollection = FirebaseFirestore.instance.collection("users");
  final StreamController<AppUserEvent> _streamController = StreamController<AppUserEvent>.broadcast();
  AppUser _currentUser;

  bool _isDeleting = false;

  bool get isLogged => _currentUser != null;
  //To Cancel old user stream and suscribe to the new one
  StreamSubscription<QuerySnapshot> _subscription;

  Stream<AppUserEvent> get userEventStream => _streamController.stream;

  AppUser get currentUser => _currentUser;

  //Inicializa los listeners para obtener un stream de UserEvent conteniendo la
  //informacion del usuario actual
  void init() {
    print("init AppUserBloc");
    _auth.authStateChanges().listen((User event) {
      print("-----Auth State Changed-----");
      print(event.toString());
      if (_isDeleting) {
        _streamController.add(AppUserEvent(event: UserEventType.kDeleting));
      } else {
        if (event == null) {
          _streamController.add(AppUserEvent(event: UserEventType.kDisconnected));
        } else {
          print("-----Subscript to: -----");
          print("-----${event.uid}-----");
          _subscription?.cancel();
          _subscription = _userCollection.where("authUID", isEqualTo: event.uid).snapshots().listen((result) {
            if (result == null) {
              print("-----Cant find user in DATA BASE-----");
              _streamController.add(AppUserEvent(event: UserEventType.kDisconnected));
              _currentUser = null;
            } else {
              final len = result.docs.length;
              if (len == 0) {
                print("-----Cant find user in DATA BASE len: 0-----");
                _streamController.add(AppUserEvent(event: UserEventType.kDisconnected));
                _currentUser = null;
              } else if (len > 1) {
                print("-----Cloned user in DATA BASE len: $len -----");
                _streamController.add(AppUserEvent(event: UserEventType.kDisconnected));
                _currentUser = null;
              } else if (len == 1) {
                print("-----USER EY: LOGGIN IN-----");
                _currentUser = AppUser(firebaseUser: event, userData: UserData.fromFirebase(result.docs[0]));
                _streamController.add(AppUserEvent(event: UserEventType.kConnected, user: _currentUser));
              }
            }
          });
        }
      }
    });
  }

  Future<UserData> getUserDataFromID(String id) async {
    final user = await _userCollection.doc(id).get();
    if (user == null) {
      print("Error getUserDataFromID cant find the user");
      return null;
    } else {
      return UserData.fromFirebase(user);
    }
  }

  DocumentReference getUserDocumentFromID(String id) {
    final user = _userCollection.doc(id);
    if (user == null) {
      print("Error getUserDocumentFromId cant find the user");
      return null;
    } else {
      return user;
    }
  }

  Future<DocumentSnapshot> getUserDocumentFromUID(String uid) async {
    final userList = await _userCollection.where("uid", isEqualTo: uid).get();
    if (userList.docs.length == 0) {
      print("Error getUserDataFromUID cant find the user");
      return null;
    } else {
      return userList.docs[0];
    }
  }

  Future<FirebaseAuthException> createUserEmailPassword({String email, String password, ApplicationLevel level = ApplicationLevel.kUser}) async {
    UserCredential result;

    try {
      result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (error) {
      return error as FirebaseAuthException;
    }
    try {
      print("Creating user");

      final tosend = UserData(email: email, password: password, authUID: result.user.uid, level: level, userName: "None");
      await _userCollection.add(tosend.toJson());
      print("User Add sucesful");
    } catch (error) {
      print(error.toString());
      print("ERror adding user");
      await result?.user?.delete();
    }
    return null;
  }

  Future deleteUserWithUID(String uid) async {
    DocumentSnapshot documentSnapshot = await getUserDocumentFromUID(uid);
    UserData userData = UserData.fromJson(documentSnapshot.data());
    if (documentSnapshot == null) {
      print("Can't delete the user");
    } else {
      print("begin deletion");
      _isDeleting = true;
      final UserData actualUser = _currentUser.userData;
      AuthCredential credential = EmailAuthProvider.credential(email: userData.email, password: userData.password);
      await FirebaseAuth.instance.signInWithCredential(credential);
      print("Signed in");
      final currentuser = FirebaseAuth.instance.currentUser;
      print("Deleted from database");
      await documentSnapshot.reference.delete();
      print("Deleted user");
      await currentuser.delete();
      await this.logInEmailAndPassword(email: actualUser.email, password: actualUser.password);
      print("Logged in");
      _isDeleting = false;
    }
  }

  Future<FirebaseAuthException> logInEmailAndPassword({String email, String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (error) {
      return error as FirebaseAuthException;
    }
    return null;
  }

  Future signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print(e.toString());
      return null;
    }
  }
}
