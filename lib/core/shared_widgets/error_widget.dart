import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../utils/constants.dart';

class CustomErrorWidget extends StatelessWidget {
  const CustomErrorWidget({
    super.key, required this.onTap,
  });
  final Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset("assets/images/error.svg", width: MediaQuery.of(context).size.width * .7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Some Thing Went Error",style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: MediaQuery.of(context).size.height*.016,
                  color: const Color(0xffA5A5A5)
              )),
              SizedBox(width: AppConstants.width5(context)),
              GestureDetector(
                  onTap: onTap,
                  child: const Icon(Icons.refresh_outlined, color:  Color(0xffA5A5A5))),
            ],
          ),
        ],
      ),
    );
  }
}
