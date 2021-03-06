import 'package:GymStats/src/pages/exercises/exercises_page.dart';
import 'package:GymStats/src/pages/home_page.dart';
import 'package:GymStats/src/pages/stats/graphics_page.dart';
import 'package:GymStats/src/pages/stats/stats_page.dart';
import 'package:GymStats/src/pages/stats/training_stats_page.dart';
import 'package:GymStats/src/pages/training/training_page.dart';
import 'package:GymStats/src/pages/stats/trainings_list_page.dart';
import 'package:GymStats/src/pages/workout_template_list_page.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'model/app_user_event.dart';
import 'pages/create_workout_page.dart';
import 'pages/stats/profile_page.dart';
import 'signin_page.dart';

class LoginStreamWrapper extends StatefulWidget {
  const LoginStreamWrapper({Key key}) : super(key: key);

  @override
  _LoginStreamWrapperState createState() => _LoginStreamWrapperState();
}

class _LoginStreamWrapperState extends State<LoginStreamWrapper> {
  final routes = {
    HomePage.route: (BuildContext context) => HomePage(),
    ExercisesPage.route: (BuildContext context) => ExercisesPage(),
    CreateWorkoutPage.route: (BuildContext context) => CreateWorkoutPage(),
    WorkoutListPage.route: (BuildContext context) => WorkoutListPage(),
    TrainingPage.route: (BuildContext context) => TrainingPage(),
    TrainingsListPage.route: (BuildContext context) => TrainingsListPage(),
    ProfilePage.route: (BuildContext context) => ProfilePage(),
    TrainingStatsPage.route: (BuildContext context) => TrainingStatsPage(),
    GraphicsPage.route: (BuildContext context) => GraphicsPage(),
    StatsPage.route: (BuildContext context) => StatsPage(),
  };

  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    final bloc = AppStateContainer.of(context).blocProvider;
    print("From Login Wrapper: ");
    print(bloc.appUserBloc.currentUser?.userData?.userName);

    return StreamBuilder(
      stream: bloc.appUserBloc.userEventStream,
      builder: (BuildContext context, AsyncSnapshot<AppUserEvent> snapshot) {
        //todo: fix this, should wait not show siginpage if already logged
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        } else {
          print(snapshot.data.event);
          if (snapshot.data.event == UserEventType.kDisconnected) {
            return SignInPage();
          } else {
            return FutureBuilder(
                future: bloc.trainingBloc.checkForOpenSesions(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Theme(
                      data: ThemeData(brightness: Brightness.light),
                      child: WillPopScope(
                        onWillPop: () async {
                          return !await _navigatorKey.currentState.maybePop();
                        },
                        child: Navigator(
                          key: _navigatorKey,
                          initialRoute: HomePage.route,
                          onGenerateRoute: (settings) {
                            if (routes.containsKey(settings.name)) {
                              return MaterialPageRoute(builder: routes[settings.name]);
                            } else {
                              return MaterialPageRoute(builder: routes[HomePage.route]);
                            }
                          },
                        ),
                      ),
                    );
                  } else {
                    return Container(
                      color: Colors.black,
                    );
                  }
                });
          }
        }
      },
    );
  }
}
