import 'package:booking_app/src/core/module/bookings/presentation/widgets/booking_section_card.dart';
import 'package:flutter/material.dart';

class BookingInfoCard extends StatelessWidget {
  final String hotelName;
  final String roomTypeName;
  final String? imageUrl;
  final int maxCapacity;

  const BookingInfoCard({
    super.key,
    required this.hotelName,
    required this.roomTypeName,
    this.imageUrl,
    required this.maxCapacity,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl ?? '',
              width: 85,
              height: 85,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hotelName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  roomTypeName,
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
                Text('Sức chứa: $maxCapacity'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
