import 'package:flutter_bloc/flutter_bloc.dart';

part 'change_nav_bar_status_state.dart';

class ChangeNavBarStatusCubit extends Cubit<ChangeNavBarStatusState> {
  ChangeNavBarStatusCubit() : super(ChangeNavBarStatusInitial());

  static ChangeNavBarStatusCubit get(context) => BlocProvider.of(context);

  int currentIndex = 0;

  void changeNavBarIndex(int index) {
    currentIndex = index;
    emit(ChangeNavBarStatusSuccessState());
  }

  void changeHomeHeaderState() {
    emit(ChangeNavBarStatusSuccessState());
  }
}
