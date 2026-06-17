import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'app_strings.dart';

extension L10nX on BuildContext {
  AppStrings get s => watch<AppState>().strings;
}

extension L10nRead on BuildContext {
  AppStrings get sRead => read<AppState>().strings;
}
