import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_eqo_v2/main.dart';
import 'package:flutter_eqo_v2/register.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'package:async/async.dart';
import 'package:stripe_payment/stripe_payment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:stripe_payment/stripe_payment.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:flutter_eqo_v2/login.dart';
import 'package:flutter_eqo_v2/main.dart';

void main() => runApp(Payment());

class Payment extends StatelessWidget {
  static const routeName = '/SubscriptionRoute';
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    //bring in login details
    final LoginOutput args = ModalRoute.of(context).settings.arguments;

    return MaterialApp(
      title: 'EQO',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: PaymentScreen(title: 'Payment'),
      routes: {
        MyApp.routeName: (context) => MyApp(),
      },
    );
  }
}

class PaymentScreen extends StatefulWidget {
  PaymentScreen({Key key, this.title, @required this.args}) : super(key: key);

  final String title;
  final LoginOutput args;

  @override
  _PaymentState createState() => _PaymentState(args);
}

class _PaymentState extends State<PaymentScreen> {
  TextStyle style = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);

  LoginOutput args;

  _PaymentState(LoginOutput args){
    this.args = args;
  }

  String user_email      = "";
  String user_id         = "";
  String user_subscription_id = "";
  String initial_payment_date = "";
  String last_payment_date    = "";

  @override
  void initState() {
    StripePayment.setOptions(StripeOptions(
        publishableKey: "pk_test_51Ip1nEBwbtoLyuGPq2r3m3roNooFxmbUCK6YKT3GetLq3w28ATrVlfMeOH8GIxtfz4JACK6o909Emyi20hqNWSYL007wAKvqRG"));
    super.initState();
  }

  //function for acquiring user data based on subscription status (email or subscription ID)
  int pull_counter = 1;

  Future<void> SubscriptionPagePull(itemPull)
  async {
    Map<String, String> lookup = {
      "user_id" : args.user_id,
      "item_pull" : itemPull
    };

    //get data from database
    var url_lookup = 'https://eqomusic.com/mobile/subscription_page_lookup.php';
    var data = await http.post(url_lookup,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: itemPull
    );

    var jsonData = json.decode(data.body);

    if(data.body.contains('Error') == true){

      return showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
                title: Text("Please refresh page"));
          }
      );

    }
    else{
      setState(() {
        
        if(itemPull == "email") {
          user_email = jsonData["email"];
        }
        else{
          user_subscription_id = jsonData["subscription_id"];
          initial_payment_date = jsonData["initial_payment_date"];
          last_payment_date    = jsonData["last_payment_date"];
        }
      });
    }

    pull_counter = 1;

  }

  //needs email; only call this when user is adding card for first time (i.e. subscription setup)
  //returns buyers ID, which needs to be saved in the firestore database
  Future<String> newBuyer(String email) async {
    try {
      final HttpsCallable createCustomer = CloudFunctions.instance
          .getHttpsCallable(functionName: 'createCustomer');
      return createCustomer
          .call(<String, dynamic>{'email': email}).then((response) {
        String _buyersID = response.data['id'];
        return _buyersID;
      });
    } catch (e) {
      throw e;
    }
  }

  //needs email; only call this when user is adding card for first time (i.e. subscription setup)
  //pass this the buyer ID from newBuyer method, returns PaymentMethod (object from Stripe)
  //note: this displays the UI for inputting the card by the user
  Future<PaymentMethod> addBuyersCard(_buyersID, priceID) async {

    try {
      final HttpsCallable setupIntent =
      CloudFunctions.instance.getHttpsCallable(functionName: 'setupIntent');
      return setupIntent
          .call(<String, dynamic>{'buyersID': _buyersID}).then((response) {
        String clientSecret = response.data['client_secret'];
        return StripePayment.paymentRequestWithCardForm(
            CardFormPaymentRequest())
            .then((paymentMethod) async {
          await StripePayment.confirmSetupIntent(PaymentIntent(
              clientSecret: clientSecret, paymentMethodId: paymentMethod.id));
          PaymentMethod _paymentMethod = paymentMethod;

          await createSubscription(_buyersID, priceID, _paymentMethod.id);

          return _paymentMethod;
        });
      });
    } catch (e) {
      throw e;
    }
  }

  //need buyerID from newBuyer function
  //need price ID ("price_1Ip1smBwbtoLyuGPQjgQp1iD")
  //need paymentmethodID (assume this is output of addBuyersCard function; e.g. [output name].data['id'] ???)
  //returns the subscription ID; need to save this to database
  createSubscription(
      String buyerID, String priceID, String paymentMethodID) async {
    try {
      final HttpsCallable createSubscription = CloudFunctions.instance
          .getHttpsCallable(functionName: 'createSubscription');
      return await createSubscription.call(<String, dynamic>{
        'buyersID': buyerID,
        'priceID': priceID,
        'paymentMethod_id': paymentMethodID,
      }).then((value) {

        SubscriptionUpdate("create", user_id, value.data['id']);

        return value.data['id'];

      });
    } catch (e) {
      throw e;
    }
  }

  //straight-forward; just need to get subscription ID of user to tackle this
  deleteSubscription(String subscriptionId) async {
    try {
      final HttpsCallable delSubscription = CloudFunctions.instance
          .getHttpsCallable(functionName: 'deleteSubscription');
      await delSubscription.call(<String, dynamic>{
        'subscription_id': subscriptionId,
      });

      SubscriptionUpdate("delete", user_id, subscriptionId);

    } catch (e) {
      throw e;
    }
  }

  //will need to test this out; could be used to confirm subscription is live and what not
  getSubscription(String subscriptionId) async {
    try {
      final HttpsCallable getSubscription = CloudFunctions.instance
          .getHttpsCallable(functionName: 'getSubscription');
      var response = await getSubscription.call(<String, dynamic>{
        'subscription_id': subscriptionId,
      });
      return response.data;
    } catch (e) {
      throw e;
    }
  }

  //probably don't include this for now
  Future<bool> deletePaymentMethod(PaymentMethod paymentMethod) async {
    final HttpsCallable dltPaymentM = CloudFunctions.instance
        .getHttpsCallable(functionName: 'deletePaymentMethod');
    return dltPaymentM
        .call(<String, dynamic>{'paymentMethod_id': paymentMethod.id}).then(
            (response) {
          return response.data["deleted"];
        });
  }

  //charges a single payment; can be used for individual ticket purchases in the future
  Future<String> chargePayment(
      String buyerID, PaymentMethod paymentMethod, int totalAmount,
      {String currency = 'usd'}) async {
    //this is calling of cloud function named createPaymentIntent
    try {
      final HttpsCallable createPayment = CloudFunctions.instance
          .getHttpsCallable(functionName: 'createPaymentIntent');
      dynamic response = await createPayment.call(<String, dynamic>{
        'paymentMethod_id': paymentMethod.id,
        'customer_id': buyerID,
        'amount': totalAmount,
        'currency': currency,
      });
      if (response.data['status'] == "requires_confirmation")
        return response.data["client_secret"];
      else
        return null;
    } on Exception catch (e) {
      throw e;
    }
  }

  //updates user data based on subscription (starting new one or ending one)
  //request variable accepts 1 of 2 options (create, delete)
  //see: create/delete subscription functions above for input flow

  void SubscriptionUpdate(input_request, user_id, subscription_id) async {

    Map<String, String> input_data_subscription = {
      "request": input_request,
      "user_id": user_id,
      "subscription_id": subscription_id,
    };

    var url_subscription = 'https://eqomusic.com/mobile/subscription_management.php';

    var data = await http.post(url_subscription,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: input_data_subscription
    );

    if(data.body.contains('Error') == false){
      print(data.body);
      return showDialog(
          context: context,
          builder: (context){
            return AlertDialog(
                title: Text("Thank you for subscribing, go find some shows!")
                , actions:[
                    TextButton(
                      child: Text("OK"),
                      onPressed: () {

                        Navigator.pushNamed(
                            context,
                            MyApp.routeName,
                            arguments: LoginOutput(args.user_id, args.user_type, args.user_city, args.user_state, "1", "0"));

                      },
                      ),
            ]);
          }
      );

    }


  }

  //for use in conjunction with previous function
  confirmPayment(String _clientSecret, PaymentMethod paymentMethod) async {
    try {
      PaymentIntentResult paymentIntentResult =
      await StripePayment.confirmPaymentIntent(PaymentIntent(
          clientSecret: _clientSecret, paymentMethodId: paymentMethod.id));
      return paymentIntentResult.status;
    } catch (e) {
      throw e;
    }
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    super.dispose();
  }

  //******************************************************************************************************************
  //Start of the app UI build
  //******************************************************************************************************************

  @override
  Widget build(BuildContext context) {

    if(pull_counter<1 && args.subscription_flag == "0"){
      SubscriptionPagePull("email");
    }

    if(pull_counter<1 && args.subscription_flag == "1"){
      SubscriptionPagePull("subscription_id");
    }

    String buyerID;
    PaymentMethod paymentMethod;
    String paymentMethodID;
    String priceID = "price_1Ip1smBwbtoLyuGPQjgQp1iD";

    final NewPaymentButton = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {

          //creates buyer ID, preps payment, creates subscription
          buyerID = newBuyer(user_email) as String;
          paymentMethod = addBuyersCard(buyerID, priceID) as PaymentMethod;

        },
        child: Text("Subscribe to EQO",
            textAlign: TextAlign.center,
            style: style.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );

    final ManagePaymentButton = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {


          //pops out basic information on the subscription here
          //probably can't recall much, so can just list start date, last payment date, last payment total

          return showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                    title: Text("Subscription cost per month: \$25.00"),
                    content: Text("Initial Payment Date:" + initial_payment_date +
                        "\n Last Payment Date:" + last_payment_date));
              }
          );

        },
        child: Text("Manage EQO Subscription",
            textAlign: TextAlign.center,
            style: style.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );

    final DeletePaymentButton = Material(
      elevation: 5.0,
      borderRadius: BorderRadius.circular(30.0),
      color: Color(0xff01A0C7),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: () {

          //pops out a confirmation button for deletion of subscription

          return showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                    title: Text("Are you sure you want to stop your subscription?"),
                    content: Text("Your subscription will be good until the end of your current billing period if you cancel"),
                    actions: [
                      FlatButton(
                      child: Text("Yes"),
                      onPressed: () {
                        deleteSubscription(user_subscription_id);
                      },
                      ),
                    ]);
              }
          );

        },
        child: Text("Manage EQO Subscription",
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
                    SizedBox(
                      height: 35.0,
                    ),
                    args.subscription_flag == "0" && args.final_month_flag == "0" ? NewPaymentButton : ManagePaymentButton,
                    SizedBox(
                      height: 15.0,
                    ),
                    SizedBox(
                      height: 15.0,
                    ),
                    args.subscription_flag == "0" && args.final_month_flag == "0" ? null : DeletePaymentButton,
                  ],
                ),
              ),
            ),
          ),
        )
    );
  }
}

//if fan:
//gains entrance either via button in upper right or via attend button if not subscribed
//if subscribed:
//allow for subscription management (i.e. cancellation), allow for going back to main screen
//if not subscribed:
//show monthly payment / rules -> initial payment button -> Stripe payment/update subscription status -> go back to main screen

//if venue:
//gains entrance using button in upper right only
//list # past fans that are unpaid -> total value available for collection
//allow for them to initiate payment (us to them, if we can?), go back to main screen
