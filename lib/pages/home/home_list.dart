import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rai_rub_rai_jai/data_model/date.dart';

import '../../data_model/account_data.dart';
import '../../data_model/edit_pass_argu.dart';
import '../../provider/account_provider.dart';
import '../../util.dart';

class TodayDataList extends StatefulWidget {
  const TodayDataList({Key? key}) : super(key: key);

  @override
  State<TodayDataList> createState() => _TodayDataListState();
}

class _TodayDataListState extends State<TodayDataList> {
  int maxSize = 10;

  Widget rowDate(
      BuildContext context, Date date, bool isFirst, User userValue) {
    final IncomeAndCost icAtDate = userValue.accountsData.getICAtDay(date);
    final int deltaMoney = icAtDate.income + icAtDate.cost;
    final bool isToday = date == Date.today();
    String todayStr =
        " ${getMonthName(date.month)} ${date.year}${isToday ? " (Today)" : ""} [${deltaMoney}\$]";
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 30),
      child: Row(
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 36.0,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          Text(
            todayStr,
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget rowAccount(
      BuildContext context, Account account, Date date, int index) {
    return GestureDetector(
      child: Card(
        color: account.isPositive
            ? Colors.greenAccent[100]
            : Colors.redAccent[100],
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AutoSizeText(
                    "${account.icon} ${account.title} : ${account.amount}",
                    style: const TextStyle(fontSize: 24.0),
                    maxLines: 1),
              ),
            ),
          ],
        ),
      ),
      onTap: () {
        //? show info via dialog

        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor:
                    account.isPositive ? Colors.green[50] : Colors.red[50],
                title: Text("${account.amount}\$",
                    style: TextStyle(fontSize: 24.0)),
                content: Text(
                    '${account.fullTitle}\n${(account.description == "") ? "\nNo description" : account.description}'),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          "/editData",
                          arguments: EditPassArgu(date: date, index: index),
                        );
                      },
                      child: Text("edit")),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("OK")),
                ],
              );
            });
      },
    );
  }

  Widget genContainerAtDay(
      BuildContext context, Date date, bool isFirst, User value) {
    var widgets = <Widget>[];
    var accountOnDay = value.accountsData.getAccountsOnDate(date);
    widgets.add(rowDate(context, date, true, value));

    if (accountOnDay.isEmpty) {
      widgets.add(const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Center(child: Text("No data :|\n"))));
    } else {
      for (int i = 0; i < accountOnDay.length; i++) {
        var account = accountOnDay[i];
        widgets.add(rowAccount(context, account, date, i));
      }
    }

    late final colorBackground;
    final expectedMoney = value.accountsData.getExpectedMoneyAtDay(date);
    final IncomeAndCost icAtDate = value.accountsData.getICAtDay(date);
    final int deltaMoney = -(icAtDate.income + icAtDate.cost);

    if (expectedMoney < 0) {
      colorBackground = const Color.fromARGB(255, 100, 0, 0);
    } else {
      if (deltaMoney > expectedMoney * 2) {
        colorBackground = const Color.fromARGB(255, 150, 0, 50);
      } else if (deltaMoney > expectedMoney) {
        colorBackground = Colors.red[100];
      } else if (deltaMoney > expectedMoney * 0.75) {
        colorBackground = Colors.yellow[100];
      } else {
        colorBackground = Colors.green[50];
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 15),
      child: Container(
        padding: const EdgeInsets.all(10),
        color: colorBackground,
        child: Column(
          children: widgets,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<User>(
      builder: (context, value, child) {
        var dates = value.accountsData.getAllDate();
        if (dates.isEmpty) {
          return const Center(child: Text("No data\n"));
        }

        dates.sort((a, b) => b.compareTo(a));

        List<Widget> widgets = [
          genContainerAtDay(context, Date.today(), false, value),
          Divider(
            color: Theme.of(context).primaryColor,
            thickness: 1,
          )
        ];

        bool isFirst = true;
        for (var date in dates) {
          var accountOnDate = value.accountsData.getAccountsOnDate(date);
          if (accountOnDate.isEmpty || date.compareTo(Date.today()) == 0) {
            continue;
          }
          widgets.add(genContainerAtDay(context, date, isFirst, value));
          isFirst = false;

          if (widgets.length > maxSize) {
            widgets.add(
              Padding(
                padding: EdgeInsets.all(30.0),
                child: Center(
                  child: ElevatedButton(
                    onPressed: () => setState(() {
                      maxSize += maxSize ~/ 3 + 10;
                    }),
                    child: const Text(
                      "Load more...",
                      style: TextStyle(fontSize: 24.0),
                    ),
                  ),
                ),
              ),
            );
            break;
          }
        }

        if (widgets.length <= maxSize) {
          widgets.add(const Center(
              child: Text("EOF\n", style: TextStyle(fontSize: 20))));
        }

        return ListView(
          children: widgets,
        );
      },
    );
  }
}
