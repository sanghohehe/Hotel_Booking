import 'package:booking_app/src/core/module/hotel/domain/repositories/hotel_repository.dart';
import 'package:booking_app/src/core/module/hotel/presentation/cubit/HotelState.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HotelCubit extends Cubit<HotelState> {
  final HotelRepository _repository;

  HotelCubit(this._repository) : super(HotelInitial());

  Future<void> fetchHotels({double? minRating, String? city, String? keyword}) async {
    emit(HotelLoading());
    try {
      final hotels = await _repository.getHotels(
        minRating: minRating,
        city: city,
        keyword: keyword,
      );
      emit(HotelLoaded(hotels));
    } catch (e) {
      emit(HotelError(e.toString()));
    }
  }
}
