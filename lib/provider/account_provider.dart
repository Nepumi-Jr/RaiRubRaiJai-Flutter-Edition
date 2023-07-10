import 'dart:convert';

import '../data_model/account_data.dart';
import '../data_model/date.dart';

import 'package:flutter/material.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AccountsData {
  Map<Date, List<Account>> _accounts = {};
  Map<Date, IncomeAndCost> _accumulated = {};
  VoidCallback onUpdateData;

  List<Account> getAccountsOnDate(Date date) {
    return _accounts[date] ?? [];
  }

  List<Account> getAccountsToday() {
    final today = Date.today();
    return _accounts[today] ?? [];
  }

  List<Account> getAllAccounts() {
    return _accounts.values.expand((accounts) => accounts).toList();
  }

  List<Date> getAllDate() {
    return _accounts.keys.toList();
  }

  void _syncData({bool syncToFireStore = false}) {
    //? Reload the accumulated data
    _accumulated = {};
    List<Date> allDate = _accounts.keys.toList();
    allDate.sort((a, b) => a.compareTo(b));
    int accumulatedIncome = 0;
    int accumulatedCost = 0;
    for (final date in allDate) {
      for (final account in getAccountsOnDate(date)) {
        if (account.isPositive) {
          accumulatedIncome += account.amount;
        } else {
          accumulatedCost += account.amount;
        }
      }
      _accumulated[date] = IncomeAndCost(accumulatedIncome, accumulatedCost);
    }
    if (syncToFireStore) {
      print(">>>>>>>>>>>>>>>>>>>>>> sync data");
      print(_accounts);
      print(_accounts.length);
      print(_accounts.isEmpty);
      onUpdateData();
    }
  }

  void addAccountAtDay(Date date, Account account) {
    if (_accounts[date] == null) {
      _accounts[date] = [];
    }
    _accounts[date]!.add(account);
    _syncData(syncToFireStore: true);
  }

  void removeAccountAtDay(Date date, Account account) {
    _accounts[date]!.remove(account);
    _syncData(syncToFireStore: true);
  }

  void removeAccountAtIndex(Date date, int index) {
    _accounts[date]!.removeAt(index);
    _syncData(syncToFireStore: true);
  }

  IncomeAndCost getAccumulatedICBeforeDay(Date date) {
    List<Date> allDate = _accounts.keys.toList();
    allDate.sort((a, b) => a.compareTo(b));

    //? Find the index of the date by binary search
    int left = 0;
    int right = allDate.length - 1;
    int ans = -1;
    while (left <= right) {
      int mid = (left + right) ~/ 2;
      if (allDate[mid].compareTo(date) < 0) {
        ans = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }
    if (ans == -1) {
      return const IncomeAndCost(0, 0);
    }
    return _accumulated[allDate[ans]]!;
  }

  IncomeAndCost getICAtDay(Date date) {
    int income = 0;
    int cost = 0;
    for (final account in getAccountsOnDate(date)) {
      if (account.isPositive) {
        income += account.amount;
      } else {
        cost += account.amount;
      }
    }
    return IncomeAndCost(income, cost);
  }

  int getAccumulatedBeforeDay(Date date) {
    var ic = getAccumulatedICBeforeDay(date);
    return ic.income + ic.cost;
  }

  IncomeAndCost getIncomeAndCostAtMonth(Date date) {
    final firstDayOfMonth = Date(date.year, date.month, 1);
    final lastDayOfMonth = Date(date.year, date.month + 1, 1);

    return IncomeAndCost(
        getAccumulatedICBeforeDay(lastDayOfMonth).income -
            getAccumulatedICBeforeDay(firstDayOfMonth).income,
        getAccumulatedICBeforeDay(lastDayOfMonth).cost -
            getAccumulatedICBeforeDay(firstDayOfMonth).cost);
  }

  int getExpectedMoneyAtDay(Date date) {
    final int numDayOfMonth = date.numDayOfMonth;
    return getAccumulatedBeforeDay(date) ~/ (numDayOfMonth - date.day + 1);
  }

  AccountsData(this._accounts, {required this.onUpdateData}) {
    _syncData();
  }

  factory AccountsData.fromJson(Map<String, dynamic> json,
      {required VoidCallback onUpdateData}) {
    Map<Date, List<Account>> accounts = {};
    for (final entry in json.entries) {
      final date = Date.fromString(entry.key);
      final accountsOnDate = (entry.value as List)
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList();
      accounts[date] = accountsOnDate;
    }
    return AccountsData(accounts, onUpdateData: onUpdateData);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    for (final entry in _accounts.entries) {
      final date = entry.key;
      final accountsOnDate = entry.value;
      json[date.toString()] = accountsOnDate.map((e) => e.toJson()).toList();
    }
    return json;
  }
}

const _scope = <String>[
  'email',
  'https://www.googleapis.com/auth/contacts.readonly',
  'https://www.googleapis.com/auth/userinfo.email',
  'https://www.googleapis.com/auth/userinfo.profile',
];

class User extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scope,
  );
  late GoogleSignInAccount? user;
  late UserCredential firebaseUserCredential;
  late CollectionReference _userCloudData;

  String email = "bruh@bruh.com";
  List<String> accountList = [];
  int accountIndex = 0;

  String get accountName =>
      (accountList.isEmpty) ? "No Account" : accountList[accountIndex];

  AccountsData accountsData = AccountsData({}, onUpdateData: () {});
  DateTime dateUpdate = DateTime.now();

  List<String> quickTitleIncome = [];
  List<String> quickTitleCost = [];

  void onUpdateData() {
    _userCloudData.doc(accountName).set({
      "data": jsonEncode(accountsData),
      "dateUpdated": DateTime.now().toString(),
      "quickTitleCost": jsonEncode(quickTitleCost),
      "quickTitleIncome": jsonEncode(quickTitleIncome),
    });
    print(accountsData._accounts);
    print(accountsData.toJson());

    notifyListeners();
  }

  void selectAccount(int index) {
    accountIndex = index;
    CollectionReference userData =
        FirebaseFirestore.instance.collection(user!.email);
    userData.doc(accountName).get().then((value) {
      accountsData = AccountsData.fromJson(jsonDecode(value["data"]),
          onUpdateData: onUpdateData);
      dateUpdate = DateTime.parse(value["dateUpdated"]);
      quickTitleCost = (jsonDecode(value["quickTitleCost"]) as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      quickTitleIncome =
          (jsonDecode(value["quickTitleIncome"]) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
      notifyListeners();
    });
  }

  void selectAccountName(String name) {
    accountIndex = accountList.indexOf(name);
    if (accountIndex == -1) return;
    selectAccount(accountIndex);
  }

  void refreshAccount() {
    selectAccount(accountIndex);
  }

  void removeCurrentAccount() {
    if (accountList.isEmpty) return;
    _userCloudData.doc(accountName).delete();
    accountList.removeAt(accountIndex);
    accountList.sort();
    selectAccount(0);
  }

  void renameCurrentAccount(String newName) {
    if (accountList.isEmpty) return;
    if (accountList.contains(newName)) return;
    String oldName = accountName;
    accountList[accountIndex] = newName;
    selectAccount(accountIndex);
    _userCloudData.doc(newName).set({
      "data": jsonEncode(accountsData.toJson()),
      "dateUpdated": DateTime.now().toString(),
      "quickTitleIncome": jsonEncode(quickTitleIncome),
      "quickTitleCost": jsonEncode(quickTitleCost),
    }).then((value) => selectAccountName(newName));
    _userCloudData.doc(oldName).delete();
  }

  void addAccount(String name) {
    if (accountList.contains(name)) return;
    accountList.add(name);
    accountList.sort();
    _userCloudData.doc(name).set({
      "data": "{}",
      "dateUpdated": DateTime.now().toString(),
      "quickTitleIncome":
          "[\"💵 Salary\",\"💰 Interest\", \"💸 Other income\"]",
      "quickTitleCost": "[\"🍔 Food\", \"🍧 Snacks/Drinks\", \"🛍️ Shopping\"]",
    }).then((value) => selectAccount(accountList.length - 1));
  }

  Future<void> doLogin() async {
    user = await _googleSignIn.signIn();
    final GoogleSignInAuthentication googleAuth = await user!.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    FirebaseAuth.instance.signInWithCredential(credential).then((value) {
      firebaseUserCredential = value;
      initData();
    });
  }

  Future<void> doLoginSilent() async {
    try {
      user = await _googleSignIn.signInSilently();
    } catch (e) {
      print(";;;;;;;;;;;;;;;;;;GOT ERROR $e");
      return;
    }
    if (user == null) return;
    final GoogleSignInAuthentication googleAuth = await user!.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    FirebaseAuth.instance.signInWithCredential(credential).then((value) {
      firebaseUserCredential = value;
      initData();
    });
  }

  Future<void> doLogout() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut().then((value) {
      user = null;
      accountsData = AccountsData({}, onUpdateData: onUpdateData);
      notifyListeners();
    });
  }

  Future<void> initData() async {
    email = user!.email;

    print(">>>>>>>>>>>>>>>${user!.email}");

    _userCloudData = FirebaseFirestore.instance.collection(user!.email);
    accountList = (await _userCloudData.get()).docs.map((e) => e.id).toList();
    accountIndex = 0;

    print(">>>>>>>>>>>>>>>${accountList.toString()}");
    print(">>>>>>>>>>>>>>>${accountList.isEmpty}");

    if (accountList.isEmpty) {
      accountList.add("Untitled");
      accountList.sort();
      await _userCloudData.doc("Untitled").set({
        "data": "{}",
        "dateUpdated": DateTime.now().toString(),
        "quickTitleIncome":
            "[\"💵 Salary\",\"💰 Interest\", \"💸 Other income\"]",
        "quickTitleCost":
            "[\"🍔 Food\", \"🍧 Snacks/Drinks\", \"🛍️ Shopping\"]",
      });
    }
    selectAccount(0);
    print(">>>>>>>>>>>>>>>> DONE");
  }
}

//? from https://betterprogramming.pub/the-minimum-guide-for-using-google-drive-api-with-flutter-9207e4cb05ba
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;

  final http.Client _client = new http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
