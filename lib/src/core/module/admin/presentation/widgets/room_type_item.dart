import 'package:flutter/material.dart';
import '../../../hotel/data/models/hotel_model.dart';

class RoomTypeItem extends StatelessWidget {
  final RoomTypeModel room;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RoomTypeItem({
    super.key,
    required this.room,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 70,
            height: 70,
            color: Colors.grey[200],
            child:
                (room.imageUrl != null && room.imageUrl!.isNotEmpty)
                    ? Image.network(room.imageUrl!.first, fit: BoxFit.cover)
                    : const Icon(Icons.king_bed, color: Color(0xFF0D47A1)),
          ),
        ),
        title: Text(
          room.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\$${room.pricePerNight.toStringAsFixed(0)} / đêm'),
            if (room.amenities != null && room.amenities!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 4,
                  children:
                      room.amenities!
                          .take(3)
                          .map(
                            (a) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                a,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize:
              MainAxisSize.min, 
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 20,
                color: Colors.blueGrey,
              ),
              onPressed: onEdit,
              constraints:
                  const BoxConstraints(), 
              padding: const EdgeInsets.all(8),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.redAccent,
              ),
              onPressed: onDelete, 
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ],
        ),
      ),
    );
  }
}
