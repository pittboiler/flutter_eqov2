import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_eqo_v2/main.dart';
import 'package:flutter_eqo_v2/register.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:geolocator/geolocator.dart';

import 'artist_main.dart';

void main() => runApp(MyLogin());

class MyLogin extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EQO',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyLoginPage(title: 'Flutter Login'),
      routes: {
        MyApp.routeName: (context) => MyApp(),
        MyRegister.routeName: (context) => MyRegister(),
        ArtistMain.routeName: (context) => ArtistMain(),
      },
    );
  }
}

class MyLoginPage extends StatefulWidget {
  MyLoginPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyLoginState createState() => _MyLoginState();
}

class _MyLoginState extends State<MyLoginPage> {
  TextStyle style = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  //gets user location data here to pass into main
  Position currentPosition;
  int location_update_counter = 0;
  LatLng center = LatLng(0, 0);
  double user_latitude = 0.00;
  double user_longitude = 0.00;


  final Geolocator geolocator = Geolocator()..forceAndroidLocationManager;

  //gets user location data here to pass into main
  _getCurrentLocation() async {
    if(location_update_counter < 1) {
      geolocator
          .getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
          .then((Position position) {
        currentPosition = position;
        center = LatLng(currentPosition.latitude, currentPosition.longitude);
        print("center from lat/long" + center.toString());
      }).catchError((e) {
        print(e);
      });
      location_update_counter = location_update_counter + 1;
    }
  }

  //login check: take inputs from login field, run by code validation, output login info or error message
  Future<List<LoginOutput>> LoginCheck(input_email, input_password, user_latitude, user_longitude)

  async {

    //temporary hard-coded inputs
    Map<String, String> input_data_login = {
      "email": input_email,
      "password" : input_password,
    };

    //get data from database

    var url_login = 'https://eqomusic.com/mobile/login.php';

    var data = await http.post(url_login,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_data_login
    );

    print(data.body.toString());

    var jsonData = json.decode(data.body);

    if(data.body.isNotEmpty) {

      if(jsonData.contains('Error') == true){
        print("failed!");
        return showDialog(
            context: context,
            builder: (context){
              return AlertDialog(title: Text("Username or password is incorrect"));
            }
        );

      }
      else{
        if(jsonData[1].toString() == "artist"){
          Navigator.pushNamed(
              context,
              ArtistMain.routeName,
              arguments: LoginOutput(jsonData[0].toString(), jsonData[1].toString(), jsonData[2].toString(), jsonData[3].toString(), center));
        }
        else {
          Navigator.pushNamed(
              context,
              MyApp.routeName,
              arguments: LoginOutput(jsonData[0].toString(), jsonData[1].toString(), jsonData[2].toString(), jsonData[3].toString(), center));
        }
      }

    }
    else {
      print("failed!");
      return showDialog(
          context: context,
          builder: (context){
            return AlertDialog(title: Text("Username or password is incorrect"));
          }
      );
    }

  }

  //******************************************************************************************************************
  //Start of the app UI build
  //******************************************************************************************************************

  @override
  Widget build(BuildContext context) {

    _getCurrentLocation();

    final emailField = TextField(
      style: style,
      controller: emailController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Email",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final passwordField = TextField(
      obscureText: true,
      style: style,
      controller: passwordController,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Password",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
    );

    final loginButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {
          LoginCheck(emailController.text, passwordController.text, user_latitude, user_longitude);
        },
        child: Text("Login",
            textAlign: TextAlign.center,
            style: style.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );

    final RegisterButon = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MyRegisterPage()),
          );
            },
        child: Text("Register",
            textAlign: TextAlign.center,
            style: style.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );

    return Scaffold(
        appBar: AppBar(
          title: Text('Flutter EQO'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(36.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(height: 100.0),
                    SizedBox(
                      height: 155.0,
                      child: Image.asset(
                        "images/eqo_icon4.png", //put in EQO logo here
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: 45.0),
                    emailField,
                    SizedBox(height: 25.0),
                    passwordField,
                    SizedBox(
                      height: 35.0,
                    ),
                    loginButon,
                    SizedBox(
                      height: 15.0,
                    ),
                    RegisterButon,
                    SizedBox(
                      height: 125.0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
    );
  }
}

class LoginOutput {
  final String user_id;
  final String user_type;
  final String user_city;
  final String user_state;
  final LatLng center;

  LoginOutput(this.user_id, this.user_type, this.user_city, this.user_state, this.center);

}