import 'package:flutter/material.dart';

import '../../widget/bottom_bar.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Setting\nApp Ver 0.0.5 :D'),
      ),
      bottomNavigationBar: BottomAppBar(
        child: BottomNavigation(focused: BottomPages.setting),
      ),
    );
  }
}
