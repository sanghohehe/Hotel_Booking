import 'package:booking_app/src/core/module/hotel/domain/entities/hotel_entity.dart';

abstract class HotelState {}

class HotelInitial extends HotelState {}

class HotelLoading extends HotelState {}

class HotelLoaded extends HotelState {
  final List<HotelEntity> hotels;
  HotelLoaded(this.hotels);
}

class HotelError extends HotelState {
  final String message;
  HotelError(this.message);
}
