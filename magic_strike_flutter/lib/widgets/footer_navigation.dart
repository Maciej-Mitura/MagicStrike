import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';

class FooterNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FooterNav({required this.currentIndex, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.ringPrimary,
        selectedItemColor: AppColors.whiteFillingText,
        unselectedItemColor: AppColors.ringBackground3rd,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'IstokWeb',
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'IstokWeb',
          fontWeight: FontWeight.bold,
        ),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.house), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.chartBar), label: 'Stats'),
          BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.bowlingBall), label: 'Play'),
          BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.clockRotateLeft), label: 'Games'),
          BottomNavigationBarItem(
              icon: Icon(FontAwesomeIcons.bars), label: 'More'),
        ],
      ),
    );
  }
}
